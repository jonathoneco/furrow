# verdict-guard.sh — Block direct writes to gate-verdicts/
#
# Hook: PreToolUse (matcher: Write|Edit)
# Verdicts must be written by the evaluator subagent via shell,
# not directly by the in-context agent via Write/Edit tools.
#
# Return codes:
#   0 — allowed
#   2 — blocked

# shellcheck source=../lib/common-minimal.sh
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"

hook_verdict_guard() {
  input="$(cat)"
  target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" || target_path=""

  case "$target_path" in
    */gate-verdicts/*|gate-verdicts/*)
      log_error "gate-verdicts/ is write-protected — verdicts written by evaluator subagent only"
      return 2
      ;;
  esac

  return 0
}
