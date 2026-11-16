#!/usr/bin/env bash
# Test a WSS listener endpoint via the shared web server. See usage() / --help.

# Not safely traceable: auth resolution expands SERVER_TOKEN and SERVER_BEARER_TOKEN.
set +x

source "$(dirname "$0")/boomi-common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/boomi-wss-test.sh --path /ws/simple/createOrder [--method POST] [--data '{"key":"val"}' | --data file.json] [--content-type application/xml] [--max-time 60]

Tests a WSS listener endpoint via the shared web server.

Required:
  --path <path>           Listener path, e.g. /ws/simple/createOrder

Options:
  --method <METHOD>       HTTP method (default: POST)
  --data <string|file>    Request body, inline or a path to a file
  --content-type <type>   Request Content-Type (default: application/json)
  --max-time <seconds>    Client timeout in seconds (default: 60)
  -h, --help              Show this help and exit.

Auth selection from .env:
  SERVER_AUTH_TYPE=basic   -> requires SERVER_USERNAME + SERVER_TOKEN
  SERVER_AUTH_TYPE=bearer  -> requires SERVER_BEARER_TOKEN
  SERVER_AUTH_TYPE=none    -> no auth; any creds set in .env are ignored
  SERVER_AUTH_TYPE unset   -> inferred from which creds are populated; ambiguity
                              (e.g. Basic vars + Bearer both set, or only one of
                              SERVER_USERNAME/SERVER_TOKEN) is a hard error.

Client Certificate / mTLS and other non-Bearer custom auth schemes are out of
scope — fall back to manual curl for those cases. See
references/platform_entities/shared_web_server.md.
EOF
}

# Answer --help and a bare invocation before load_env, which needs a workspace .env.
[[ $# -eq 0 ]] && { usage; exit 1; }
if wants_help "--path --data --method --content-type --max-time" "$@"; then usage; exit 0; fi

load_env
require_tools curl

# --- Parse args ---
WSS_PATH=""
DATA=""
METHOD="POST"
CONTENT_TYPE="application/json"
MAX_TIME=60

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)         WSS_PATH="$2"; shift 2 ;;
    --data)         DATA="$2"; shift 2 ;;
    --method)       METHOD="$2"; shift 2 ;;
    --content-type) CONTENT_TYPE="$2"; shift 2 ;;
    --max-time)     MAX_TIME="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*)       echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)        echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$WSS_PATH" ]]; then
  usage
  exit 1
fi

if [[ ! "$MAX_TIME" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: --max-time must be a positive whole number of seconds (got '${MAX_TIME}')" >&2
  exit 1
fi

if [[ -z "${SERVER_BASE_URL:-}" ]]; then
  echo "ERROR: SERVER_BASE_URL must be set in .env" >&2
  exit 1
fi

# --- Resolve auth mode ---
auth_type="${SERVER_AUTH_TYPE:-}"
auth_inferred=false
basic_set=false
bearer_set=false
[[ -n "${SERVER_USERNAME:-}" || -n "${SERVER_TOKEN:-}" ]] && basic_set=true
[[ -n "${SERVER_BEARER_TOKEN:-}" ]] && bearer_set=true

if [[ -z "$auth_type" ]]; then
  # Back-compat inference. Hard-fail on any ambiguity so the user fixes .env.
  if $basic_set && $bearer_set; then
    echo "ERROR: SERVER_USERNAME/SERVER_TOKEN and SERVER_BEARER_TOKEN are both set." >&2
    echo "       Set SERVER_AUTH_TYPE=basic or SERVER_AUTH_TYPE=bearer to disambiguate," >&2
    echo "       or clear the credentials for the scheme you don't want." >&2
    exit 1
  fi
  if $basic_set; then
    if [[ -z "${SERVER_USERNAME:-}" || -z "${SERVER_TOKEN:-}" ]]; then
      echo "ERROR: Incomplete Basic credentials. Set both SERVER_USERNAME and SERVER_TOKEN, or neither." >&2
      exit 1
    fi
    auth_type="basic"
  elif $bearer_set; then
    auth_type="bearer"
  else
    auth_type="none"
  fi
  auth_inferred=true
fi

case "$auth_type" in
  basic)
    if [[ -z "${SERVER_USERNAME:-}" || -z "${SERVER_TOKEN:-}" ]]; then
      echo "ERROR: SERVER_AUTH_TYPE=basic requires SERVER_USERNAME and SERVER_TOKEN in .env" >&2
      exit 1
    fi
    ;;
  bearer)
    if [[ -z "${SERVER_BEARER_TOKEN:-}" ]]; then
      echo "ERROR: SERVER_AUTH_TYPE=bearer requires SERVER_BEARER_TOKEN in .env" >&2
      exit 1
    fi
    ;;
  none)
    ;;
  *)
    echo "ERROR: SERVER_AUTH_TYPE='${auth_type}' is invalid. Expected: basic, bearer, or none." >&2
    exit 1
    ;;
esac

ssl_flag=""
[[ "${SERVER_VERIFY_SSL:-true}" == "false" ]] && ssl_flag="-k"

# --- Build curl args ---
curl_args=($ssl_flag -s -w "\n--- HTTP %{http_code} (%{time_total}s) ---" \
  --max-time "$MAX_TIME" -A "$BOOMI_USER_AGENT" -X "$METHOD")

auth_cfg=""
case "$auth_type" in
  basic)  auth_cfg="$(curl_cfg user "${SERVER_USERNAME}:${SERVER_TOKEN}")" ;;
  bearer) auth_cfg="$(curl_cfg header "Authorization: Bearer ${SERVER_BEARER_TOKEN}")" ;;
esac
[[ -n "$auth_cfg" ]] && curl_args+=(-K -)

if [[ -n "$DATA" ]]; then
  if [[ -f "$DATA" ]]; then
    curl_args+=(-H "Content-Type: ${CONTENT_TYPE}" -d "@${DATA}")
  else
    curl_args+=(-H "Content-Type: ${CONTENT_TYPE}" -d "$DATA")
  fi
fi

url="${SERVER_BASE_URL}${WSS_PATH}"
banner="auth=${auth_type}"
$auth_inferred && banner="${banner} (inferred — set SERVER_AUTH_TYPE in .env to declare explicitly)"
echo "Testing: ${METHOD} ${url}  (${banner})"
printf '%s' "$auth_cfg" | curl "${curl_args[@]}" "$url" 2>/dev/null && curl_rc=0 || curl_rc=$?
echo ""
# curl exit 28: client timeout.
if [[ $curl_rc -eq 28 ]]; then
  echo "CLIENT TIMEOUT after ${MAX_TIME}s. The process may still have run; check boomi-execution-query.sh before retrying." >&2
elif [[ $curl_rc -ne 0 ]]; then
  echo "REQUEST FAILED (curl exit ${curl_rc}). No HTTP response." >&2
fi
true
