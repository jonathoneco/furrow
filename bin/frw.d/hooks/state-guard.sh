# state-guard.sh — Block direct state.json writes
#
# Hook: PreToolUse (matcher: Write|Edit)
# Receives JSON on stdin with tool_name and tool_input.
# Return 2 to block if target is state.json; return 0 otherwise.

# shellcheck source=../lib/common-minimal.sh
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"

hook_state_guard() {
  input="$(cat)"

  target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" || target_path=""

  case "$target_path" in
    */state.json|state.json)
      log_error "state.json is Furrow-exclusive — use frw update-state"
      return 2
      ;;
  esac

  return 0
}
