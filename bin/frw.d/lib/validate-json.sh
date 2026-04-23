#!/bin/sh
# validate-json.sh — Shared JSON Schema Draft 2020-12 validator.
#
# Source this file; do not execute directly. Exposes one function:
#
#   validate_json <schema_path> <doc_path>
#
# Contract:
#   - Returns 0 on valid, non-zero on invalid.
#   - Validation errors printed to stderr in the form:
#       Schema error at <path>: <message>
#   - If jsonschema>=4.0 is not installed, prints
#       SKIP: jsonschema not installed (need >=4.0)
#     to stderr and returns 0 (graceful degradation matches the pattern
#     extracted verbatim from bin/frw.d/scripts/validate-definition.sh:36-55).
#   - If python3 is missing, prints an error to stderr and returns 2
#     (hard failure: callers that need validation cannot silently pass).
#   - If either input file is unreadable, returns 2.
#
# POSIX sh — no bash-isms. Designed to be source-able from hooks and scripts.

# Guard against double-sourcing.
if [ -n "${_FRW_VALIDATE_JSON_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
_FRW_VALIDATE_JSON_SOURCED=1

# validate_json <schema_path> <doc_path>
validate_json() {
  _vj_schema="${1:-}"
  _vj_doc="${2:-}"

  if [ -z "$_vj_schema" ] || [ -z "$_vj_doc" ]; then
    printf 'validate_json: usage: validate_json <schema_path> <doc_path>\n' >&2
    return 2
  fi

  if [ ! -f "$_vj_schema" ]; then
    printf 'validate_json: schema not found: %s\n' "$_vj_schema" >&2
    return 2
  fi
  if [ ! -f "$_vj_doc" ]; then
    printf 'validate_json: document not found: %s\n' "$_vj_doc" >&2
    return 2
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    printf 'validate_json: python3 is required\n' >&2
    return 2
  fi

  # Run the validator as a subprocess. Errors and the SKIP sentinel are
  # both routed to stderr. Python exit code: 0 if the script ran (errors,
  # if any, have been printed); 2 if jsonschema is missing (we treat that
  # as a skip — matches validate-definition.sh behavior).
  _vj_stderr="$(python3 - "$_vj_schema" "$_vj_doc" <<'PY' 2>&1 1>/dev/null
import json, sys
try:
    from jsonschema import Draft202012Validator
except ImportError:
    print('SKIP: jsonschema not installed (need >=4.0)', file=sys.stderr)
    sys.exit(2)
with open(sys.argv[1]) as f:
    schema = json.load(f)
with open(sys.argv[2]) as f:
    instance = json.load(f)
# Use Draft202012Validator to match schema's $schema declaration
# (https://json-schema.org/draft/2020-12/schema). The older Draft 7 class
# silently ignores 2020-12 keywords like unevaluatedProperties.
validator = Draft202012Validator(schema)
errs = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
had_err = False
for e in errs:
    path = '.'.join(str(p) for p in e.absolute_path) or '(root)'
    print(f'Schema error at {path}: {e.message}', file=sys.stderr)
    had_err = True
sys.exit(1 if had_err else 0)
PY
)"
  _vj_exit=$?

  # Always surface whatever the validator emitted on stderr.
  if [ -n "$_vj_stderr" ]; then
    printf '%s\n' "$_vj_stderr" >&2
  fi

  case "$_vj_exit" in
    0) return 0 ;;   # valid
    2) return 0 ;;   # jsonschema missing — SKIP (matches validate-definition.sh)
    *) return 1 ;;   # invalid or unexpected failure
  esac
}
