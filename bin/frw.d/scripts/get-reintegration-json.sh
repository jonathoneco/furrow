#!/bin/sh
# get-reintegration-json.sh — Read, validate, and emit reintegration.json.
#
# Usage: get-reintegration-json.sh <row_name> <furrow_root>
#
# Reads:  .furrow/rows/<row>/reintegration.json
# Writes: nothing (stdout only)
# Emits:  the schema-valid JSON on stdout
#
# Exit codes:
#   0  success
#   1  usage
#   2  reintegration.json not found for row
#   3  schema validation failed
#
# Validation uses the shared Draft 2020-12 helper at
# bin/frw.d/lib/validate-json.sh — the single source of schema truth for
# reintegration artifacts (inline jq subsets are forbidden per the
# row's constraint "Schemas are authoritative").
#
# POSIX sh — no bash-isms.
set -eu

if [ "$#" -lt 2 ]; then
  printf 'usage: get-reintegration-json.sh <row_name> <furrow_root>\n' >&2
  exit 1
fi

ROW_NAME="$1"
FURROW_ROOT="$2"

# Row data lives under FURROW_ROOT (the caller's project). Schema + validator
# ship with the harness — resolve them relative to this script so sandbox
# fixtures that don't carry the harness layout still work.
_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
_HARNESS_ROOT="$(cd "$_SCRIPT_DIR/../../.." && pwd)"

REINT_JSON="${FURROW_ROOT}/.furrow/rows/${ROW_NAME}/reintegration.json"
SCHEMA_FILE="${_HARNESS_ROOT}/schemas/reintegration.schema.json"

if [ ! -f "$REINT_JSON" ]; then
  printf 'get-reintegration-json: reintegration.json not found for row %s: %s\n' \
    "$ROW_NAME" "$REINT_JSON" >&2
  exit 2
fi

if [ ! -f "$SCHEMA_FILE" ]; then
  printf 'get-reintegration-json: schema not found: %s\n' "$SCHEMA_FILE" >&2
  exit 3
fi

# Pre-check: parseable JSON.
if ! jq -e . "$REINT_JSON" >/dev/null 2>&1; then
  printf 'get-reintegration-json: not valid JSON: %s\n' "$REINT_JSON" >&2
  exit 3
fi

# shellcheck source=../lib/validate-json.sh
. "${_HARNESS_ROOT}/bin/frw.d/lib/validate-json.sh"

if ! validate_json "$SCHEMA_FILE" "$REINT_JSON"; then
  printf 'get-reintegration-json: schema validation failed\n' >&2
  exit 3
fi

cat "$REINT_JSON"
