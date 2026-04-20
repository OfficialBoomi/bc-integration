#!/usr/bin/env bash
# Search Boomi components by folder, name, type, or reference relationship.
# Results are written to active-development/inventories/component_search_<timestamp>.json.
# Default filters include currentVersion=true and deleted=false.
# Folder scoping is flat (no recursion into subfolders).
#
# Usage:
#   bash scripts/boomi-component-search.sh --folder <id|name>
#   bash scripts/boomi-component-search.sh --name '%Invoice%' [--type process]
#   bash scripts/boomi-component-search.sh --type connector-settings,connector-action
#   bash scripts/boomi-component-search.sh --related-to <componentId>
#
# --type takes the API-level component type, not the Boomi UI label. A Boomi
# "connection" is type=connector-settings with a subType identifying the
# connector (e.g. salesforce); an "operation" is type=connector-action.

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

# --- Parse args ---
FOLDER=""
NAME=""
TYPES=""
RELATED_TO=""

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/boomi-component-search.sh <filter> [<filter>...]

Filters (at least one required):
  --folder <id|name>      Components in the given folder (flat — no recursion).
                          Accepts a folder id, an exact folder name, or a LIKE
                          pattern (with % wildcards). Multiple matches are
                          unioned via OR on folderId.
  --name <pattern>        LIKE match on name (case-insensitive); use % wildcards (e.g. '%Invoice%')
  --type <csv>            Component types (OR). Use the API-level type, not the UI label:
                          process, connector-settings (connections), connector-action (operations),
                          transform.map, profile.xml, profile.json, profile.db,
                          profile.edi, profile.flatfile, script.processing, ...
                          e.g. process,connector-settings,connector-action
  --related-to <id>       Components the given id references OR is referenced-by
                          (each output record carries a "relation" field:
                           "references" or "referenced-by")
                          (cannot combine with other filters)

Output: active-development/inventories/component_search_<timestamp>.json
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --folder)      FOLDER="$2"; shift 2 ;;
    --name)        NAME="$2"; shift 2 ;;
    --type)        TYPES="$2"; shift 2 ;;
    --related-to)  RELATED_TO="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    -*)            echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)             echo "Unexpected argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$FOLDER" && -z "$NAME" && -z "$TYPES" && -z "$RELATED_TO" ]]; then
  echo "ERROR: at least one filter is required." >&2
  usage
  exit 1
fi

if [[ -n "$RELATED_TO" && ( -n "$FOLDER" || -n "$NAME" || -n "$TYPES" ) ]]; then
  echo "ERROR: --related-to cannot be combined with other filters." >&2
  exit 1
fi

mkdir -p active-development/inventories
timestamp="$(date -u +%Y%m%d_%H%M%S)"
out_file="active-development/inventories/component_search_${timestamp}.json"

# --- Tempfile management (trap-based cleanup on any exit path) ---
TMPFILES=()
cleanup_tmpfiles() {
  local f
  for f in "${TMPFILES[@]}"; do
    [[ -n "$f" ]] && rm -f "$f"
  done
}
trap cleanup_tmpfiles EXIT

mktempfile() {
  local f
  f=$(mktemp)
  TMPFILES+=("$f")
  echo "$f"
}

# --- Paginate helper ---
# Accumulates `.result` arrays from an `/query` + `/queryMore` loop into the
# caller-provided `pages_file` (one JSON array per line). Sets TOTAL_COUNT.
# Caller consumes the file with `jq --slurpfile`, which avoids ARG_MAX on
# large accumulations.
paginate_query() {
  local endpoint="$1"
  local body="$2"
  local pages_file="$3"

  local url; url="$(build_api_url "${endpoint}/query" false)"
  boomi_api -X POST "$url" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$body"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: ${endpoint}/query failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    return 1
  fi

  echo "$RESPONSE_BODY" | jq -c '.result // []' > "$pages_file"
  TOTAL_COUNT=$(echo "$RESPONSE_BODY" | jq -r '.numberOfResults // 0')
  local token; token=$(echo "$RESPONSE_BODY" | jq -r '.queryToken // empty')

  while [[ -n "$token" ]]; do
    local more_url; more_url="$(build_api_url "${endpoint}/queryMore" false)"
    boomi_api -X POST "$more_url" \
      -H "Accept: application/json" \
      -H "Content-Type: text/plain" \
      -d "$token"

    if [[ "$RESPONSE_CODE" != "200" ]]; then
      echo "WARN: ${endpoint}/queryMore failed (HTTP ${RESPONSE_CODE}); returning partial results." >&2
      break
    fi
    echo "$RESPONSE_BODY" | jq -c '.result // []' >> "$pages_file"
    token=$(echo "$RESPONSE_BODY" | jq -r '.queryToken // empty')
  done
}

# --- Resolve folder input → one or more folderIds ---
# Resolution order:
#   - Input contains '%' → LIKE-on-name only (ids never contain '%').
#   - Otherwise → EQUALS-on-id, then fall back to EQUALS-on-name.
# Emits one id per line on stdout (may be multiple for LIKE matches).
# Errors on 0 matches.
resolve_folder_ids() {
  local input="$1"
  local url; url="$(build_api_url "Folder/query" false)"

  if [[ "$input" == *"%"* ]]; then
    # Paginate via queryMore — Boomi's default page size is 100 and broad
    # patterns (%test%, etc.) routinely exceed that.
    local body pages
    body=$(jq -cn --arg v "$input" '{QueryFilter:{expression:{operator:"LIKE",property:"name",argument:[$v]}}}')
    pages=$(mktempfile)
    if ! paginate_query "Folder" "$body" "$pages"; then
      return 1
    fi
    if [[ "$TOTAL_COUNT" == "0" ]]; then
      echo "ERROR: No folders matched pattern '${input}'." >&2
      return 1
    fi
    jq -r '.[].id' "$pages"
    return 0
  fi

  # Non-wildcard: try as id
  boomi_api -X POST "$url" \
    -H "Accept: application/json" -H "Content-Type: application/json" \
    -d "$(jq -cn --arg v "$input" '{QueryFilter:{expression:{operator:"EQUALS",property:"id",argument:[$v]}}}')"

  if [[ "$RESPONSE_CODE" == "200" ]]; then
    local id; id=$(echo "$RESPONSE_BODY" | jq -r '.result[0].id // empty')
    if [[ -n "$id" ]]; then
      echo "$id"
      return 0
    fi
  fi

  # Fall back to exact name
  boomi_api -X POST "$url" \
    -H "Accept: application/json" -H "Content-Type: application/json" \
    -d "$(jq -cn --arg v "$input" '{QueryFilter:{expression:{operator:"EQUALS",property:"name",argument:[$v]}}}')"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: Folder query failed (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    return 1
  fi

  local count; count=$(echo "$RESPONSE_BODY" | jq -r '.numberOfResults // 0')
  if [[ "$count" == "0" ]]; then
    echo "ERROR: Folder '${input}' not found (by id or exact name). Use % wildcards for LIKE matching." >&2
    return 1
  fi
  if [[ "$count" -gt 1 ]]; then
    echo "ERROR: Folder name '${input}' matches ${count} folders. Pass a folder id or use % wildcards to accept multiple matches." >&2
    return 1
  fi
  echo "$RESPONSE_BODY" | jq -r '.result[0].id'
}

# --- Build ComponentMetadata/query expression ---
# Always adds currentVersion=true and deleted=false.
build_component_expr() {
  # $1: newline-separated list of folderIds (empty = no folder filter)
  local folder_ids_nl="$1"
  local name="$2"
  local types_csv="$3"

  local exprs=()
  exprs+=("$(jq -cn '{operator:"EQUALS",property:"currentVersion",argument:["true"]}')")
  exprs+=("$(jq -cn '{operator:"EQUALS",property:"deleted",argument:["false"]}')")

  if [[ -n "$folder_ids_nl" ]]; then
    local folder_exprs=() fid
    while IFS= read -r fid; do
      [[ -z "$fid" ]] && continue
      folder_exprs+=("$(jq -cn --arg v "$fid" '{operator:"EQUALS",property:"folderId",argument:[$v]}')")
    done <<< "$folder_ids_nl"
    if [[ ${#folder_exprs[@]} -eq 1 ]]; then
      exprs+=("${folder_exprs[0]}")
    elif [[ ${#folder_exprs[@]} -gt 1 ]]; then
      local nested="[$(IFS=,; echo "${folder_exprs[*]}")]"
      exprs+=("$(jq -cn --argjson n "$nested" '{operator:"or",nestedExpression:$n}')")
    fi
  fi

  if [[ -n "$name" ]]; then
    exprs+=("$(jq -cn --arg v "$name" '{operator:"LIKE",property:"name",argument:[$v]}')")
  fi

  if [[ -n "$types_csv" ]]; then
    local type_exprs=()
    IFS=',' read -ra parts <<< "$types_csv"
    for t in "${parts[@]}"; do
      t="${t// /}"
      [[ -z "$t" ]] && continue
      type_exprs+=("$(jq -cn --arg v "$t" '{operator:"EQUALS",property:"type",argument:[$v]}')")
    done
    if [[ ${#type_exprs[@]} -eq 1 ]]; then
      exprs+=("${type_exprs[0]}")
    elif [[ ${#type_exprs[@]} -gt 1 ]]; then
      local nested="[$(IFS=,; echo "${type_exprs[*]}")]"
      exprs+=("$(jq -cn --argjson n "$nested" '{operator:"or",nestedExpression:$n}')")
    fi
  fi

  local nested="[$(IFS=,; echo "${exprs[*]}")]"
  jq -cn --argjson n "$nested" '{operator:"and",nestedExpression:$n}'
}

# --- Reference-relationship query path ---
# ComponentReference/query rejects any filter that pins parentComponentId without
# a companion parentVersion — so resolve the target's current version first.
# Writes final output atomically via .tmp + mv so a mid-write failure can't
# leave a 0-byte file in active-development/inventories/.
run_related_to() {
  local related_to="$1"

  echo "Resolving current version of ${related_to}..."
  local meta_expr meta_body meta_url current_version
  meta_expr=$(jq -cn --arg v "$related_to" '{
    operator:"and",
    nestedExpression:[
      {operator:"EQUALS",property:"componentId",argument:[$v]},
      {operator:"EQUALS",property:"currentVersion",argument:["true"]}
    ]
  }')
  meta_body=$(jq -cn --argjson e "$meta_expr" '{QueryFilter:{expression:$e}}')
  meta_url="$(build_api_url "ComponentMetadata/query" false)"
  boomi_api -X POST "$meta_url" \
    -H "Accept: application/json" -H "Content-Type: application/json" \
    -d "$meta_body"
  if [[ "$RESPONSE_CODE" != "200" ]]; then
    log_activity "component-search" "fail" "$RESPONSE_CODE" \
      "$(jq -cn --arg id "$related_to" --arg err "${RESPONSE_BODY:0:500}" \
         '{mode:"related-to", related_to:$id, stage:"resolve-version", error:$err}')"
    echo "ERROR: could not resolve ${related_to} (HTTP ${RESPONSE_CODE}): ${RESPONSE_BODY}" >&2
    return 1
  fi
  current_version=$(echo "$RESPONSE_BODY" | jq -r '.result[0].version // empty')
  if [[ -z "$current_version" ]]; then
    log_activity "component-search" "fail" "no-current-version" \
      "$(jq -cn --arg id "$related_to" \
         '{mode:"related-to", related_to:$id, stage:"resolve-version", error:"component not found or has no current version"}')"
    echo "ERROR: component ${related_to} not found or has no current version." >&2
    return 1
  fi

  echo "Querying references for ${related_to} (current version ${current_version})..."

  # "references" direction: rows where the target (as parent) references something else.
  # parentComponentId=target AND parentVersion=target-current-version
  local expr_ref body_ref refs_pages refs_total
  expr_ref=$(jq -cn --arg v "$related_to" --arg ver "$current_version" '{
    operator:"and",
    nestedExpression:[
      {operator:"EQUALS",property:"parentComponentId",argument:[$v]},
      {operator:"EQUALS",property:"parentVersion",argument:[$ver]}
    ]
  }')
  body_ref=$(jq -cn --argjson e "$expr_ref" '{QueryFilter:{expression:$e}}')
  refs_pages=$(mktempfile)
  if ! paginate_query "ComponentReference" "$body_ref" "$refs_pages"; then
    log_activity "component-search" "fail" "$RESPONSE_CODE" \
      "$(jq -cn --arg id "$related_to" --arg err "${RESPONSE_BODY:0:500}" \
         '{mode:"related-to", related_to:$id, stage:"references-query", error:$err}')"
    return 1
  fi
  refs_total=$TOTAL_COUNT

  # "referenced-by" direction: rows where something else references the target.
  # componentId=target (no version constraint — match all referrers regardless of their version)
  local expr_by body_by by_pages by_total
  expr_by=$(jq -cn --arg v "$related_to" '{operator:"EQUALS",property:"componentId",argument:[$v]}')
  body_by=$(jq -cn --argjson e "$expr_by" '{QueryFilter:{expression:$e}}')
  by_pages=$(mktempfile)
  if ! paginate_query "ComponentReference" "$body_by" "$by_pages"; then
    log_activity "component-search" "fail" "$RESPONSE_CODE" \
      "$(jq -cn --arg id "$related_to" --arg err "${RESPONSE_BODY:0:500}" \
         '{mode:"related-to", related_to:$id, stage:"referenced-by-query", error:$err}')"
    return 1
  fi
  by_total=$TOTAL_COUNT

  local out_tmp="${out_file}.tmp"
  TMPFILES+=("$out_tmp")
  jq -n \
    --arg ts "$timestamp" \
    --arg related_to "$related_to" \
    --arg ver "$current_version" \
    --slurpfile refs "$refs_pages" \
    --slurpfile by "$by_pages" \
    '{
      metadata: {
        timestamp: $ts,
        query: "related-to",
        filters: { relatedTo: $related_to, resolvedVersion: ($ver | tonumber) }
      },
      records: (
        ((($refs | add) // []) | map(. + {relation:"references"})) +
        ((($by | add) // []) | map(. + {relation:"referenced-by"}))
      )
    }' > "$out_tmp"
  mv "$out_tmp" "$out_file"

  local count
  count=$(jq '.records | length' "$out_file")

  log_activity "component-search" "success" "$RESPONSE_CODE" \
    "$(jq -cn --arg id "$related_to" --arg ver "$current_version" --argjson c "$count" \
       '{mode:"related-to", related_to:$id, resolved_version:($ver | tonumber), records:$c}')"

  echo "Found ${count} reference(s) (references: ${refs_total}, referenced-by: ${by_total}) → ${out_file}"
}

# --- Dispatch ---

if [[ -n "$RELATED_TO" ]]; then
  run_related_to "$RELATED_TO"
  exit $?
fi

# --- Component-metadata path ---
folder_ids_nl=""
if [[ -n "$FOLDER" ]]; then
  if ! folder_ids_nl=$(resolve_folder_ids "$FOLDER"); then
    log_activity "component-search" "fail" "folder-resolve" \
      "$(jq -cn --arg f "$FOLDER" \
         '{mode:"component-metadata", folder:$f, stage:"resolve-folder", error:"folder resolution failed"}')"
    exit 1
  fi
  folder_count=$(printf '%s\n' "$folder_ids_nl" | grep -c . || true)
  if [[ "$folder_count" -eq 1 ]]; then
    echo "Resolved folder '${FOLDER}' → ${folder_ids_nl}"
  else
    echo "Resolved folder '${FOLDER}' → ${folder_count} folders (union)"
  fi
fi

expr=$(build_component_expr "$folder_ids_nl" "$NAME" "$TYPES")
body=$(jq -cn --argjson e "$expr" '{QueryFilter:{expression:$e}}')

pages=$(mktempfile)
echo "Searching components..."
if ! paginate_query "ComponentMetadata" "$body" "$pages"; then
  log_activity "component-search" "fail" "$RESPONSE_CODE" \
    "$(jq -cn --arg folder "$FOLDER" --arg name "$NAME" --arg types "$TYPES" \
       --arg err "${RESPONSE_BODY:0:500}" \
       '{mode:"component-metadata", folder:$folder, name:$name, types:$types, stage:"query", error:$err}')"
  exit 1
fi

out_tmp="${out_file}.tmp"
TMPFILES+=("$out_tmp")
jq -n \
  --arg ts "$timestamp" \
  --arg folder "$FOLDER" \
  --arg folder_ids "$folder_ids_nl" \
  --arg name "$NAME" \
  --arg types "$TYPES" \
  --slurpfile pages "$pages" \
  '{
    metadata: {
      timestamp: $ts,
      query: "component-metadata",
      filters: {
        folder: (if $folder == "" then null else $folder end),
        resolvedFolders: (if $folder_ids == "" then null else ($folder_ids | split("\n") | map(select(length > 0))) end),
        name: (if $name == "" then null else $name end),
        type: (if $types == "" then null else ($types | split(",") | map(gsub("^\\s+|\\s+$"; ""))) end)
      },
      implicitFilters: { currentVersion: true, deleted: false }
    },
    records: (($pages | add) // [])
  }' > "$out_tmp"
mv "$out_tmp" "$out_file"

count=$(jq '.records | length' "$out_file")

log_activity "component-search" "success" "$RESPONSE_CODE" \
  "$(jq -cn --arg folder "$FOLDER" --arg name "$NAME" --arg types "$TYPES" \
     --argjson c "$count" --argjson total "$TOTAL_COUNT" \
     '{mode:"component-metadata", folder:$folder, name:$name, types:$types, records:$c, total:$total}')"

echo "Found ${count} component(s) (total reported: ${TOTAL_COUNT}) → ${out_file}"
