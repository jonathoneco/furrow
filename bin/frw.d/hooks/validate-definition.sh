# validate-definition.sh — PreToolUse shim for Go definition validation.
# shellcheck shell=sh
#
# Hook: PreToolUse (matcher: Write|Edit)
# Note: definition validation logic lives in `furrow validate definition`.
# This shell file only adapts the Claude hook JSON envelope and preserves the
# legacy `frw hook validate-definition` entry point.
#
# Return codes:
#   0 — valid
#   1 — usage error
#   2 — file not found
#   3 — validation failure

# shellcheck source=../lib/common-minimal.sh
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"

hook_validate_definition() {
  input="$(cat)"
  tool_name="$(echo "${input}" | jq -r '.tool_name // ""' 2>/dev/null)" || tool_name=""
  file_path="$(echo "${input}" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)" || file_path=""

  # Only validate when writing a definition.yaml file
  case "${file_path}" in
    */definition.yaml) ;;
    *) return 0 ;;
  esac

  # For Write tool, the file may not exist yet — use the path from input
  # For Edit tool, the file should already exist
  def_file="${file_path}"

  # If it's a Write, definition.yaml is being created — skip validation
  # (the content hasn't been written yet when PreToolUse fires)
  if [ "${tool_name}" = "Write" ] && [ ! -f "${def_file}" ]; then
    return 0
  fi

  if [ ! -f "${def_file}" ]; then
    return 0
  fi

  if command -v furrow >/dev/null 2>&1; then
    furrow validate definition --path "${def_file}"
    return $?
  fi
  (cd "${PROJECT_ROOT:-$FURROW_ROOT}" && go run "${FURROW_ROOT}/cmd/furrow" validate definition --path "${def_file}")
}
