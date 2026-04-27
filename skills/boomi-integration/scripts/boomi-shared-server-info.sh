#!/usr/bin/env bash
# Fetch Shared Web Server info for an atom: apiType, URL, minAuth.
# Run this before authoring any listener: apiType=basic|intermediate means
# bare WSS listener; apiType=advanced means API Service Component wrapper.
# Usage: bash scripts/boomi-shared-server-info.sh [<atom-id>]
#   Defaults to $BOOMI_TEST_ATOM_ID when <atom-id> is omitted.

source "$(dirname "$0")/boomi-common.sh"
load_env
require_env BOOMI_API_URL BOOMI_USERNAME BOOMI_API_TOKEN BOOMI_ACCOUNT_ID
require_tools curl jq

ATOM_ID="${1:-${BOOMI_TEST_ATOM_ID:-}}"
if [[ -z "$ATOM_ID" ]]; then
  echo "Usage: bash scripts/boomi-shared-server-info.sh [<atom-id>]" >&2
  echo "No atom id provided and BOOMI_TEST_ATOM_ID is unset in .env." >&2
  exit 1
fi

url="$(build_api_url "SharedServerInformation/${ATOM_ID}" false)"
boomi_api -X GET "$url" -H "Accept: application/json"

if [[ "$RESPONSE_CODE" != "200" ]]; then
  echo "ERROR: SharedServerInformation lookup failed (HTTP ${RESPONSE_CODE})" >&2
  echo "$RESPONSE_BODY" >&2
  exit 1
fi

echo "$RESPONSE_BODY" | jq -r '
  "atomId:  " + (.atomId // "-"),
  "apiType: " + (.apiType // "-"),
  "url:     " + (.url // "-"),
  "minAuth: " + (.minAuth // "-")
'
