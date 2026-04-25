# shellcheck shell=sh
# state-guard.sh — Block direct writes to state.json (D3 migrated shim).
#
# Hook: PreToolUse (matcher: Write|Edit)
# Backend: internal/cli/guard.go::handlePreWriteStateJSON
# Returns: 0 (allow) | 2 (block)
#
# Canonical 4-step shape per shared-contracts §C5: stdin → normalize →
# guard → emit. No domain logic in this shim.

# shellcheck source=../lib/blocker_emit.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"

hook_state_guard() {
  claude_tool_input_to_event pre_write_state_json \
    | furrow_guard pre_write_state_json \
    | emit_canonical_blocker
}
