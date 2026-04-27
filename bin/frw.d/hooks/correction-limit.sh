# shellcheck shell=sh
# correction-limit.sh — Block writes to deliverables at correction limit
# (D3 migrated shim).
#
# Hook: PreToolUse (matcher: Write|Edit)
# Backend: internal/cli/correction_limit.go::handlePreWriteCorrectionLimit
# Returns: 0 (allow) | 2 (block)
#
# Domain logic (row resolution, state/plan/furrow.yaml reads, glob match)
# lives in Go. The shim just normalizes the Claude tool input and dispatches.

# shellcheck source=../lib/blocker_emit.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"

hook_correction_limit() {
  claude_tool_input_to_event pre_write_correction_limit \
    | furrow_guard pre_write_correction_limit \
    | emit_canonical_blocker
}
