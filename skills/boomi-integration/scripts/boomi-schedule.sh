#!/usr/bin/env bash
# Get, set, and enable/disable run schedules for a deployed process (ProcessSchedules API).

set -euo pipefail

source "$(dirname "$0")/boomi-common.sh"

usage() {
  cat <<'EOF'
Read and write run schedules for a deployed process on a runtime.

Commands:
  get    --process-id <ID> [--atom-id <ID>]
      Print the process's schedules, retry schedule, and enabled status as JSON.

  set    --process-id <ID> [--atom-id <ID>] <spec> [--max-retry <1-5>]
      REPLACE all schedules (and the retry schedule) with <spec>. Exactly one of:
        --every-minutes <N>        every N minutes (1-59)
        --daily <HH:MM>            once a day
        --file <path>              raw JSON: {"Schedule":[...], "Retry":{...}}
        --clear                    remove all schedules
      --max-retry adds a retry schedule mirroring <spec> (simple specs only).
      To edit rather than replace: save `get` output, change it, pass it to --file.
      Snapshots the prior state to active-development/schedule-snapshots/ first.

  status --process-id <ID> [--atom-id <ID>] [--enable | --disable]
      With no flag, print whether schedules are enabled. --enable / --disable
      resumes or stops the schedules without changing them.

  -h, --help, help
      Print this message.

--atom-id defaults to $BOOMI_TEST_ATOM_ID. Listener processes cannot be
scheduled. Times are in the RUNTIME's time zone.

Examples:
  bash scripts/boomi-schedule.sh set --process-id <guid> --every-minutes 1
  bash scripts/boomi-schedule.sh set --process-id <guid> --daily 02:00 --max-retry 3
  bash scripts/boomi-schedule.sh status --process-id <guid> --disable
EOF
}

# --- Arg parsing (shared) ---

cmd="${1:-}"
shift || true
case "$cmd" in
  -h|--help|help|"") usage; exit 0 ;;
  get|set|status) ;;
  *) echo "Unknown command: $cmd" >&2; usage >&2; exit 1 ;;
esac

if wants_help "--process-id --atom-id --every-minutes --daily --file --max-retry" "$@"; then
  usage; exit 0
fi

PROCESS_ID=""
ATOM_ID=""
SPEC_KIND=""
SPEC_VALUE=""
MAX_RETRY=""
STATUS_ACTION=""

set_spec() {
  if [[ -n "$SPEC_KIND" ]]; then
    echo "ERROR: give exactly one schedule spec (got --${SPEC_KIND} and --$1)." >&2
    exit 1
  fi
  SPEC_KIND="$1"; SPEC_VALUE="${2:-}"
}

need_value() {
  [[ $# -ge 2 && -n "$2" ]] || { echo "ERROR: $1 requires a value." >&2; exit 1; }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --process-id)    need_value "$@"; PROCESS_ID="$2"; shift 2 ;;
    --atom-id)       need_value "$@"; ATOM_ID="$2"; shift 2 ;;
    --every-minutes) need_value "$@"; set_spec every-minutes "$2"; shift 2 ;;
    --daily)         need_value "$@"; set_spec daily "$2"; shift 2 ;;
    --file)          need_value "$@"; set_spec file "$2"; shift 2 ;;
    --clear)         set_spec clear; shift ;;
    --max-retry)     need_value "$@"; MAX_RETRY="$2"; shift 2 ;;
    --enable)        STATUS_ACTION="true"; shift ;;
    --disable)       STATUS_ACTION="false"; shift ;;
    *)               echo "ERROR: unknown argument for '$cmd': $1" >&2; exit 1 ;;
  esac
done

[[ -n "$PROCESS_ID" ]] || { echo "ERROR: --process-id is required." >&2; exit 1; }

if [[ "$cmd" != "set" && ( -n "$SPEC_KIND" || -n "$MAX_RETRY" ) ]]; then
  echo "ERROR: schedule specs and --max-retry only apply to 'set'." >&2; exit 1
fi
if [[ "$cmd" != "status" && -n "$STATUS_ACTION" ]]; then
  echo "ERROR: --enable / --disable only apply to 'status'." >&2; exit 1
fi

load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

ATOM_ID="${ATOM_ID:-${BOOMI_TEST_ATOM_ID:-}}"
[[ -n "$ATOM_ID" ]] || { echo "ERROR: no atom ID. Pass --atom-id or set BOOMI_TEST_ATOM_ID in .env." >&2; exit 1; }

log_details() {
  jq -cn --arg p "$PROCESS_ID" --arg a "$ATOM_ID" '{processId:$p, atomId:$a}'
}

# --- API helpers ---

# Query <endpoint> by atomId + processId; prints the single result object.
query_one() {
  local endpoint="$1"
  local body
  body=$(jq -cn --arg a "$ATOM_ID" --arg p "$PROCESS_ID" '{
    QueryFilter: {expression: {operator: "and", nestedExpression: [
      {argument: [$a], operator: "EQUALS", property: "atomId"},
      {argument: [$p], operator: "EQUALS", property: "processId"}
    ]}}}')

  boomi_api -X POST "$(build_api_url "${endpoint}/query" false)" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$body"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: ${endpoint}/query failed (HTTP ${RESPONSE_CODE})" >&2
    echo "$RESPONSE_BODY" >&2
    return 1
  fi

  local result
  result=$(echo "$RESPONSE_BODY" | jq -c '.result[0] // empty')
  if [[ -z "$result" ]]; then
    echo "ERROR: no ${endpoint} found for process ${PROCESS_ID} on atom ${ATOM_ID}." >&2
    echo "Is the process deployed to an environment this runtime is attached to?" >&2
    return 1
  fi
  echo "$result"
}

# Combined view: schedules + retry + enabled.
current_state() {
  local sched stat
  sched=$(query_one ProcessSchedules) || return 1
  stat=$(query_one ProcessScheduleStatus) || return 1
  jq -n --argjson s "$sched" --argjson st "$stat" '{
    processId: $s.processId,
    atomId: $s.atomId,
    id: $s.id,
    enabled: $st.enabled,
    Schedule: ($s.Schedule // []),
    Retry: ($s.Retry // null)
  }'
}

# --- Spec -> Schedule entries ---

die_spec() { echo "ERROR: $1" >&2; exit 1; }

int_in_range() {  # value min max
  [[ "$1" =~ ^[0-9]+$ ]] && (( 10#$1 >= $2 && 10#$1 <= $3 ))
}

parse_hhmm() {  # sets HH MM
  [[ "$1" =~ ^([0-9]{1,2}):([0-9]{2})$ ]] || die_spec "time must be HH:MM (24-hour), got '$1'."
  HH=$((10#${BASH_REMATCH[1]})); MM=$((10#${BASH_REMATCH[2]}))
  (( HH <= 23 && MM <= 59 )) || die_spec "time out of range: '$1'."
}

schedule_entry() {  # minutes hours
  jq -cn --arg m "$1" --arg h "$2" '{
    "@type": "Schedule", years: "*", months: "*", daysOfMonth: "*",
    daysOfWeek: "*", hours: $h, minutes: $m }'
}

spec_schedule() {
  local HH MM
  case "$SPEC_KIND" in
    every-minutes)
      int_in_range "$SPEC_VALUE" 1 59 || die_spec "--every-minutes must be 1-59."
      schedule_entry "0-59/$((10#$SPEC_VALUE))" "*" ;;
    daily)
      parse_hhmm "$SPEC_VALUE"
      schedule_entry "$MM" "$HH" ;;
  esac
}

# Prints {"Schedule":[...], "Retry":{...}?} for the requested spec.
build_payload() {
  case "$SPEC_KIND" in
    "")
      die_spec "'set' needs a schedule spec. See --help." ;;
    clear)
      [[ -z "$MAX_RETRY" ]] || die_spec "--max-retry cannot be combined with --clear."
      echo '{"Schedule":[]}' ;;
    file)
      [[ -z "$MAX_RETRY" ]] || die_spec "--max-retry cannot be combined with raw JSON; put \"Retry\" in the payload."
      [[ -f "$SPEC_VALUE" ]] || die_spec "file not found: $SPEC_VALUE"
      local raw; raw=$(cat "$SPEC_VALUE")
      echo "$raw" | jq -e 'type == "object"' >/dev/null 2>&1 \
        || die_spec "payload is not a JSON object."
      echo "$raw" | jq -e '(.Schedule // []) | type == "array"' >/dev/null 2>&1 \
        || die_spec "\"Schedule\" must be an array."
      if echo "$raw" | jq -e '(.Schedule // []) | length == 0' >/dev/null 2>&1; then
        die_spec "payload has no \"Schedule\" entries. Use --clear to remove all schedules."
      fi
      echo "$raw" | jq -c '{Schedule, Retry} | with_entries(select(.value != null))' ;;
    *)
      local entry; entry=$(spec_schedule) || exit 1
      if [[ -n "$MAX_RETRY" ]]; then
        int_in_range "$MAX_RETRY" 1 5 || die_spec "--max-retry must be 1-5."
        jq -cn --argjson e "$entry" --arg r "$((10#$MAX_RETRY))" \
          '{Schedule: [$e], Retry: {"@type": "ScheduleRetry", maxRetry: ($r|tonumber), Schedule: [$e]}}'
      else
        jq -cn --argjson e "$entry" '{Schedule: [$e]}'
      fi ;;
  esac
}

# --- Commands ---

cmd_get() {
  local state
  if ! state=$(current_state); then
    log_activity "schedule-get" "fail" "" "$(log_details)"
    exit 1
  fi
  echo "$state"
  log_activity "schedule-get" "success" "200" "$(log_details)"
}

cmd_set() {
  local payload; payload=$(build_payload) || exit 1

  local state
  state=$(current_state) || { echo "Aborting before write." >&2; exit 1; }

  local dir="active-development/schedule-snapshots"
  mkdir -p "$dir"
  local base="${dir}/schedules_${ATOM_ID}_${PROCESS_ID}_$(date -u +%Y%m%d_%H%M%S)"
  local snap="${base}.json" n=1
  while [[ -e "$snap" ]]; do snap="${base}_${n}.json"; n=$((n + 1)); done
  echo "$state" > "$snap"
  echo "Snapshot: $snap" >&2

  local obj_id; obj_id=$(echo "$state" | jq -r '.id')
  local body
  body=$(echo "$payload" | jq -c --arg id "$obj_id" --arg a "$ATOM_ID" --arg p "$PROCESS_ID" \
    '{"@type": "ProcessSchedules", id: $id, atomId: $a, processId: $p} + .')

  boomi_api -X POST "$(build_api_url "ProcessSchedules/${obj_id}" false)" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$body"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: ProcessSchedules update failed (HTTP ${RESPONSE_CODE})" >&2
    echo "$RESPONSE_BODY" >&2
    [[ "$RESPONSE_CODE" == "400" ]] && echo "Listener processes cannot be scheduled; also check the cron field syntax." >&2
    [[ "$RESPONSE_CODE" == "403" ]] && echo "Writing schedules needs the Runtime Management and Scheduling privileges." >&2
    log_activity "schedule-set" "fail" "$RESPONSE_CODE" "$(log_details)"
    exit 1
  fi

  local enabled; enabled=$(echo "$state" | jq -r '.enabled')
  echo "$RESPONSE_BODY" | jq --argjson en "$enabled" '{processId, atomId, id, enabled: $en, Schedule: (.Schedule // []), Retry: (.Retry // null)}'
  if [[ "$enabled" != "true" && "$SPEC_KIND" != "clear" ]]; then
    echo "WARN: schedules are saved but DISABLED, so they will not run. Enable with: status --process-id ${PROCESS_ID} --enable" >&2
  fi
  echo "Times are in the runtime's time zone." >&2
  log_activity "schedule-set" "success" "$RESPONSE_CODE" "$(log_details)"
}

cmd_status() {
  local stat
  if ! stat=$(query_one ProcessScheduleStatus); then
    log_activity "schedule-status" "fail" "" "$(log_details)"
    exit 1
  fi

  if [[ -z "$STATUS_ACTION" ]]; then
    echo "$stat" | jq '{processId, atomId, id, enabled}'
    log_activity "schedule-status" "success" "200" "$(log_details)"
    return
  fi

  local obj_id; obj_id=$(echo "$stat" | jq -r '.id')
  local body
  body=$(jq -cn --arg id "$obj_id" --arg a "$ATOM_ID" --arg p "$PROCESS_ID" --argjson e "$STATUS_ACTION" \
    '{"@type": "ProcessScheduleStatus", id: $id, atomId: $a, processId: $p, enabled: $e}')

  boomi_api -X POST "$(build_api_url "ProcessScheduleStatus/${obj_id}" false)" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$body"

  if [[ "$RESPONSE_CODE" != "200" ]]; then
    echo "ERROR: ProcessScheduleStatus update failed (HTTP ${RESPONSE_CODE})" >&2
    echo "$RESPONSE_BODY" >&2
    [[ "$RESPONSE_CODE" == "403" ]] && echo "Changing schedule status needs the Runtime Management and Scheduling privileges." >&2
    log_activity "schedule-status" "fail" "$RESPONSE_CODE" "$(log_details)"
    exit 1
  fi

  echo "$RESPONSE_BODY" | jq '{processId, atomId, id, enabled}'
  log_activity "schedule-status" "success" "$RESPONSE_CODE" "$(log_details)"
}

case "$cmd" in
  get)    cmd_get ;;
  set)    cmd_set ;;
  status) cmd_status ;;
esac
