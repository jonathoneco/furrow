# shellcheck shell=sh
# verdict-guard.sh — Block direct writes to gate-verdicts/ (D3 migrated shim).
#
# Hook: PreToolUse (matcher: Write|Edit)
# Backend: internal/cli/guard.go::handlePreWriteVerdict
# Returns: 0 (allow) | 2 (block)
#
# Verdicts must be written by the evaluator subagent via shell, not the
# in-context agent via Write/Edit tools. Canonical shim — translation only.

# shellcheck source=../lib/blocker_emit.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"

hook_verdict_guard() {
  claude_tool_input_to_event pre_write_verdict \
    | furrow_guard pre_write_verdict \
    | emit_canonical_blocker
}
