#!/bin/sh
# append-learning.sh — Validate appends to .furrow/rows/<name>/learnings.jsonl.
#
# Two invocation modes:
#
#   (1) Standalone (recommended for scripts/tests):
#
#         echo '<json-line>' | bin/frw.d/hooks/append-learning.sh <row-name>
#
#       Reads one JSON line on stdin, validates it against
#       schemas/learning.schema.json (via the shared validate-json.sh helper
#       produced by the reintegration-schema-consolidation deliverable), and
#       on success appends it to .furrow/rows/<row-name>/learnings.jsonl.
#
#   (2) Claude Code PreToolUse hook (Write|Edit):
#
#       Receives the tool input JSON on stdin, inspects file_path; if it
#       targets a learnings.jsonl under .furrow/rows/, extracts the proposed
#       write content and validates each line. Non-zero exit blocks the write.
#
# Exit codes:
#   0 — valid (or not a learnings.jsonl write — hook passes through)
#   1 — usage error
#   2 — validate-json.sh helper unavailable (schema-consolidation deliverable
#       not yet merged)
#   3 — schema validation failed (append refused)

set -eu

# Resolve FURROW_ROOT — prefer the exported value (Claude hook context),
# otherwise derive from this script's location.
if [ -z "${FURROW_ROOT:-}" ]; then
  _self_dir="$(cd "$(dirname "$0")" && pwd)"
  FURROW_ROOT="$(cd "${_self_dir}/../../.." && pwd)"
fi

SCHEMA_FILE="${FURROW_ROOT}/schemas/learning.schema.json"
VALIDATOR_LIB="${FURROW_ROOT}/bin/frw.d/lib/validate-json.sh"

# --- helper: fail with a diagnostic ---
_ae_fail() {
  printf 'append-learning: %s\n' "$1" >&2
  exit "${2:-3}"
}

# --- load the shared validator ---
_load_validator() {
  if [ ! -f "${VALIDATOR_LIB}" ]; then
    printf 'append-learning: shared validator %s not found\n' "${VALIDATOR_LIB}" >&2
    printf 'append-learning: depends on bin/frw.d/lib/validate-json.sh::validate_json (reintegration-schema-consolidation deliverable).\n' >&2
    exit 2
  fi
  # shellcheck source=../lib/validate-json.sh
  . "${VALIDATOR_LIB}"
  if ! command -v validate_json >/dev/null 2>&1; then
    printf 'append-learning: validate-json.sh loaded but validate_json function missing\n' >&2
    exit 2
  fi
}

# --- validate a single JSON line against the learning schema ---
# Returns 0 on valid; 3 on failure. Emits validator error path on stderr.
_validate_line() {
  _line="$1"
  _tmp_doc="$(mktemp)"
  printf '%s' "${_line}" > "${_tmp_doc}"
  _rc=0
  validate_json "${SCHEMA_FILE}" "${_tmp_doc}" || _rc=$?
  rm -f "${_tmp_doc}"
  return "${_rc}"
}

# --- standalone mode: args + stdin -> append ---
_standalone_mode() {
  [ "$#" -ge 1 ] || {
    printf 'Usage: append-learning.sh <row-name>   # json line on stdin\n' >&2
    exit 1
  }
  _row="$1"
  _target=".furrow/rows/${_row}/learnings.jsonl"

  # Read one JSON line from stdin.
  _line="$(cat)"
  [ -n "${_line}" ] || _ae_fail "empty stdin; expected a JSON learning record" 1

  _load_validator

  if ! _validate_line "${_line}"; then
    exit 3
  fi

  mkdir -p "$(dirname "${_target}")"
  printf '%s\n' "${_line}" >> "${_target}"
}

# --- Claude PreToolUse mode: JSON on stdin describes the tool call ---
# If the write targets a learnings.jsonl path, validate the payload.
hook_append_learning() {
  _input="$(cat)"

  _path="$(printf '%s' "${_input}" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" \
    || _path=""

  case "${_path}" in
    */learnings.jsonl|*.furrow/rows/*/learnings.jsonl) ;;
    *) return 0 ;;
  esac

  # Determine the proposed new content. Write: .content. Edit: new_string.
  _content="$(printf '%s' "${_input}" | jq -r '.tool_input.content // .tool_input.new_string // ""' 2>/dev/null)" \
    || _content=""

  [ -n "${_content}" ] || return 0

  _load_validator

  # Validate each non-empty line.
  printf '%s\n' "${_content}" | while IFS= read -r _ln; do
    [ -n "${_ln}" ] || continue
    if ! _validate_line "${_ln}"; then
      exit 3
    fi
  done
}

# --- dispatch ---
# If first arg starts with an argument (row name), enter standalone mode.
# If no args and stdin is a tool-input JSON object, enter hook mode.
if [ "$#" -ge 1 ]; then
  _standalone_mode "$@"
else
  hook_append_learning
fi
