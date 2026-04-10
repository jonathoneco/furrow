#!/bin/bash
# test-script-guard.sh — Integration tests for the script-guard hook
#
# Tests that direct execution of bin/frw.d/ scripts is blocked (exit 2)
# while read-only operations and CLI commands are allowed (exit 0).

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/helpers.sh"

# Use project-local frw (not global install)
FRW="${PROJECT_ROOT}/bin/frw"

# --- Helper: run hook with a simulated command ---

run_hook() {
  _command="$1"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$_command" \
    | "$FRW" hook script-guard 2>/dev/null
}

capture_hook() {
  _command="$1"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$_command" \
    | "$FRW" hook script-guard 2>&1
}

# --- Tests: blocked commands (exit 2) ---

echo "=== script-guard: blocked commands ==="

_ec=0
run_hook "bash bin/frw.d/scripts/update-state.sh" || _ec=$?
assert_exit_code "blocks: bash bin/frw.d/scripts/update-state.sh" 2 "$_ec"

_ec=0
run_hook "sh bin/frw.d/scripts/run-gate.sh" || _ec=$?
assert_exit_code "blocks: sh bin/frw.d/scripts/run-gate.sh" 2 "$_ec"

_ec=0
run_hook "source bin/frw.d/lib/common.sh" || _ec=$?
assert_exit_code "blocks: source bin/frw.d/lib/common.sh" 2 "$_ec"

_ec=0
run_hook ". bin/frw.d/hooks/state-guard.sh" || _ec=$?
assert_exit_code "blocks: . bin/frw.d/hooks/state-guard.sh" 2 "$_ec"

_ec=0
run_hook "echo foo && bash bin/frw.d/scripts/update-state.sh" || _ec=$?
assert_exit_code "blocks: chained && bash frw.d/" 2 "$_ec"

_ec=0
run_hook "echo foo ; bash bin/frw.d/scripts/update-state.sh" || _ec=$?
assert_exit_code "blocks: chained ; bash frw.d/" 2 "$_ec"

_ec=0
run_hook "echo foo || sh bin/frw.d/scripts/run-gate.sh" || _ec=$?
assert_exit_code "blocks: chained || sh frw.d/" 2 "$_ec"

# --- Tests: allowed commands (exit 0) ---

echo ""
echo "=== script-guard: allowed commands ==="

_ec=0
run_hook "cat bin/frw.d/scripts/update-state.sh" || _ec=$?
assert_exit_code "allows: cat bin/frw.d/scripts/update-state.sh" 0 "$_ec"

_ec=0
run_hook "grep pattern bin/frw.d/lib/common.sh" || _ec=$?
assert_exit_code "allows: grep bin/frw.d/lib/common.sh" 0 "$_ec"

_ec=0
run_hook "head -20 bin/frw.d/hooks/state-guard.sh" || _ec=$?
assert_exit_code "allows: head bin/frw.d/hooks/state-guard.sh" 0 "$_ec"

_ec=0
run_hook "ls bin/frw.d/scripts/" || _ec=$?
assert_exit_code "allows: ls bin/frw.d/scripts/" 0 "$_ec"

_ec=0
run_hook "frw update-state row-name step in_progress" || _ec=$?
assert_exit_code "allows: frw update-state (no frw.d/ in command)" 0 "$_ec"

_ec=0
run_hook "bin/rws status" || _ec=$?
assert_exit_code "allows: bin/rws status (no frw.d/ in command)" 0 "$_ec"

_ec=0
run_hook "echo hello world" || _ec=$?
assert_exit_code "allows: unrelated command" 0 "$_ec"

# --- Test: error message content ---

echo ""
echo "=== script-guard: error message ==="

_output="$(capture_hook "bash bin/frw.d/scripts/update-state.sh")" || true
assert_output_contains "error message mentions frw.d/" "$_output" "frw.d/"
assert_output_contains "error message mentions CLI entry points" "$_output" "frw, rws, alm, or sds"

# --- Summary ---

echo ""
print_summary
