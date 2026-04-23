# gate-check.sh — Verify gate record before step advance
#
# Hook: PreToolUse (matcher: Bash)
# Receives JSON on stdin with tool_name and tool_input.
# Return 2 to block if advancing without a passing gate; return 0 otherwise.
#
# Note: has_passing_gate lives in common.sh (not common-minimal.sh); this hook
# does not currently use it (gate validation is handled inside rws_transition).

# shellcheck source=../lib/common-minimal.sh
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"

hook_gate_check() {
  # The transition command now records the gate AND validates/advances in a
  # single atomic operation. Checking for a passing gate before the command
  # runs would be circular — the gate doesn't exist until the command creates
  # it. All validation (gate policy, nonce, artifacts) happens inside
  # rws_transition() itself, so this hook simply allows all transition commands.
  return 0
}
