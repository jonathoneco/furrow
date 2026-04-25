# shellcheck shell=sh
# stop-ideation.sh — Validate definition.yaml completeness during ideation
# (D3 migrated shim).
#
# Hook: Stop (matcher: empty)
# Backend: internal/cli/stop_ideation.go::handleStopIdeationCompleteness
# Returns: 0 (allow / skip) | 2 (block — required fields missing)
#
# All domain logic — row resolution, step gating, gate-policy resolution,
# definition-field reading — lives in lib/stop_payloads.sh (file reads)
# and Go (field-presence verdict). The shim is translation only.

# shellcheck source=../lib/blocker_emit.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"
# shellcheck source=../lib/stop_payloads.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/stop_payloads.sh"

hook_stop_ideation() {
  _ev="$(stop_event_ideation)"
  [ -n "$_ev" ] || return 0
  printf '%s' "$_ev" | furrow_guard stop_ideation_completeness | emit_canonical_blocker
}
