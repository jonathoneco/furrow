#!/bin/sh
# migrate-reintegration-evidence-path.sh — Insurance migration for pre-schema
# reintegration.json files that lack test_results.evidence_path.
#
# Usage: migrate-reintegration-evidence-path.sh <reintegration.json>
#
# Contract:
#   - Reads the JSON; if test_results.evidence_path is absent, sets it to
#     the conventional default "reviews/pre-migration-unknown.md".
#   - Validates the result against schemas/reintegration.schema.json
#     (resolved via FURROW_ROOT).
#   - Writes atomically (temp + mv). No-op write when already migrated.
#   - Idempotent: running twice on the same file is a no-op; second run
#     prints "already migrated" to stderr and exits 0.
#
# Exit codes:
#   0  success (including no-op)
#   1  schema validation failed after migration (unfixable)
#   2  I/O error or usage error
#
# POSIX sh — no bash-isms.
#
# Rationale: at authoring time `find .furrow/rows -name 'reintegration*.json'`
# returned empty — no live rows need migration. The script exists as insurance
# for in-flight rows that may land pre-migration JSON before this deliverable
# merges. See row post-install-hygiene spec AC-6.
set -eu

if [ "$#" -lt 1 ]; then
  printf 'usage: migrate-reintegration-evidence-path.sh <reintegration.json>\n' >&2
  exit 2
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
  printf 'migrate: file not found: %s\n' "$FILE" >&2
  exit 2
fi

# Resolve FURROW_ROOT: honor the env var if set, else walk up from the file
# to find a sibling schemas/ dir. This keeps the script usable outside of
# the harness dispatcher.
if [ -z "${FURROW_ROOT:-}" ]; then
  _mr_dir="$(cd "$(dirname "$FILE")" && pwd)"
  while [ "$_mr_dir" != "/" ]; do
    if [ -f "$_mr_dir/schemas/reintegration.schema.json" ]; then
      FURROW_ROOT="$_mr_dir"
      break
    fi
    _mr_dir="$(dirname "$_mr_dir")"
  done
fi

if [ -z "${FURROW_ROOT:-}" ] || [ ! -f "$FURROW_ROOT/schemas/reintegration.schema.json" ]; then
  printf 'migrate: cannot locate FURROW_ROOT (schemas/reintegration.schema.json not found)\n' >&2
  exit 2
fi

SCHEMA_FILE="$FURROW_ROOT/schemas/reintegration.schema.json"
VALIDATOR_LIB="$FURROW_ROOT/bin/frw.d/lib/validate-json.sh"

if [ ! -f "$VALIDATOR_LIB" ]; then
  printf 'migrate: shared validator missing: %s\n' "$VALIDATOR_LIB" >&2
  exit 2
fi

command -v jq >/dev/null 2>&1 || { printf 'migrate: jq is required\n' >&2; exit 2; }

# Check current state.
if ! jq -e . "$FILE" >/dev/null 2>&1; then
  printf 'migrate: not valid JSON: %s\n' "$FILE" >&2
  exit 2
fi

_has_field="$(jq -r '.test_results.evidence_path // empty' "$FILE")"

if [ -n "$_has_field" ]; then
  printf 'migrate: already migrated: %s\n' "$FILE" >&2
  # Still validate to ensure a no-op today doesn't mask an unfixable file.
  # shellcheck source=../lib/validate-json.sh
  . "$VALIDATOR_LIB"
  if ! validate_json "$SCHEMA_FILE" "$FILE"; then
    printf 'migrate: already-migrated file does not validate\n' >&2
    exit 1
  fi
  exit 0
fi

# Perform migration: add evidence_path with the sentinel default.
_DEFAULT_EVIDENCE="reviews/pre-migration-unknown.md"
_TMP="${FILE}.migrate.$$"
# shellcheck disable=SC2064
trap "rm -f '$_TMP'" EXIT INT TERM

if ! jq --arg ev "$_DEFAULT_EVIDENCE" \
     '.test_results.evidence_path = (.test_results.evidence_path // $ev)' \
     "$FILE" > "$_TMP"; then
  printf 'migrate: jq transform failed\n' >&2
  exit 2
fi

# Validate the migrated content before committing to the filesystem.
# shellcheck source=../lib/validate-json.sh
. "$VALIDATOR_LIB"
if ! validate_json "$SCHEMA_FILE" "$_TMP"; then
  printf 'migrate: migrated file still fails schema validation: %s\n' "$FILE" >&2
  exit 1
fi

mv "$_TMP" "$FILE"
trap - EXIT INT TERM
printf 'migrate: added test_results.evidence_path=%s to %s\n' \
  "$_DEFAULT_EVIDENCE" "$FILE" >&2
exit 0
