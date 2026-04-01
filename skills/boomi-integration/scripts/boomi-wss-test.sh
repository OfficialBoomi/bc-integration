#!/usr/bin/env bash
# Test a WSS listener endpoint via the shared web server
# Usage: bash scripts/boomi-wss-test.sh --path /ws/simple/createOrder [--method POST] [--data '{"key":"val"}' | --data file.json] [--content-type application/xml]

source "$(dirname "$0")/boomi-common.sh"
load_env
require_tools curl

# --- Parse args ---
WSS_PATH=""
DATA=""
METHOD="POST"
CONTENT_TYPE="application/json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)         WSS_PATH="$2"; shift 2 ;;
    --data)         DATA="$2"; shift 2 ;;
    --method)       METHOD="$2"; shift 2 ;;
    --content-type) CONTENT_TYPE="$2"; shift 2 ;;
    -*)       echo "Unknown option: $1" >&2; exit 1 ;;
    *)        echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$WSS_PATH" ]]; then
  echo "Usage: bash scripts/boomi-wss-test.sh --path /ws/simple/createOrder [--method POST] [--data '{...}'] [--content-type application/xml]" >&2
  exit 1
fi

if [[ -z "${SERVER_BASE_URL:-}" || -z "${SERVER_USERNAME:-}" || -z "${SERVER_TOKEN:-}" ]]; then
  echo "ERROR: SERVER_BASE_URL, SERVER_USERNAME, and SERVER_TOKEN must be set in .env" >&2
  exit 1
fi

ssl_flag=""
[[ "${SERVER_VERIFY_SSL:-true}" == "false" ]] && ssl_flag="-k"

# --- Build and execute curl ---
curl_args=($ssl_flag -s -w "\n--- HTTP %{http_code} (%{time_total}s) ---" \
  --max-time 30 -X "$METHOD" -u "${SERVER_USERNAME}:${SERVER_TOKEN}")

if [[ -n "$DATA" ]]; then
  if [[ -f "$DATA" ]]; then
    curl_args+=(-H "Content-Type: ${CONTENT_TYPE}" -d "@${DATA}")
  else
    curl_args+=(-H "Content-Type: ${CONTENT_TYPE}" -d "$DATA")
  fi
fi

url="${SERVER_BASE_URL}${WSS_PATH}"
echo "Testing: ${METHOD} ${url}"
curl "${curl_args[@]}" "$url" 2>/dev/null; true
echo ""
