# shellcheck shell=sh
# validate-summary.sh — Validate summary.md at step boundaries
# (D3 migrated shim).
#
# Hook: Stop (matcher: empty); also reusable from rws_transition for
#       step-aware validation when called with a step argument.
# Backend: internal/cli/validate_summary.go::handleStopSummaryValidation
# Returns: 0 (allow / skip) | 2 (block — sections missing or empty)
#
# Section parsing, step-aware filtering, and content-line counting live in
# Go. The shim assembles { row, step, summary_path, last_decided_by } via
# lib/stop_payloads.sh and dispatches.

# shellcheck source=../lib/blocker_emit.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"
# shellcheck source=../lib/stop_payloads.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/stop_payloads.sh"

hook_validate_summary() {
  _ev="$(stop_event_summary)"
  [ -n "$_ev" ] || return 0
  printf '%s' "$_ev" | furrow_guard stop_summary_validation | emit_canonical_blocker
}
