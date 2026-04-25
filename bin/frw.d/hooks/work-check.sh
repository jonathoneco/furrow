# shellcheck shell=sh
# work-check.sh — Verify work state consistency at session end
# (D3 migrated shim).
#
# Hook: Stop (matcher: empty)
# Backend: internal/cli/work_check.go::handleStopWorkCheck (warn-only;
#          envelopes have severity=warn / confirmation_path=silent)
# Returns: 0 always (warnings flow through stderr, never block)
#
# The pre-D3 hook also performed an `updated_at` timestamp side-effect
# (research/hook-audit.md §2.11 finding #1). That side-effect is OUT of
# scope for the migrated shim — it does not belong inside a blocker hook.
# The split is captured by TODO `work-check-side-effect-split` (see
# .furrow/almanac/todos.yaml) and the audit report.

# shellcheck source=../lib/blocker_emit.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"
# shellcheck source=../lib/stop_payloads.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/stop_payloads.sh"

hook_work_check() {
  run_stop_work_check | emit_canonical_blocker
}
