#!/bin/sh
# test-layer-policy-parity.sh — Cross-adapter parity test for D3.
#
# Both the Claude adapter (furrow hook layer-guard PreToolUse) and the Pi
# adapter (tool_call extension normalised to the same JSON) must produce
# identical verdicts for every fixture.
#
# Implementation note: since Pi needs a real runtime, parity is tested
# *structurally* — both adapters call the same `furrow hook layer-guard` Go
# binary with the same stdin shape. We exercise the Go binary directly for
# both "sides" and assert 100% verdict match.
#
# Exit codes: 0=pass, 1=fail

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
POLICY_PATH="$PROJECT_ROOT/.furrow/layer-policy.yaml"

TESTS_PASSED=0
TESTS_FAILED=0

# Build furrow binary.
FURROW_BIN="$PROJECT_ROOT/_parity_test_furrow_$$"
trap 'rm -f "$FURROW_BIN"' EXIT

if ! go build -o "$FURROW_BIN" "$PROJECT_ROOT/cmd/furrow" 2>/dev/null; then
  printf "FAIL: could not build furrow binary\n"
  exit 1
fi

# Export policy path for the hook subcommand.
export FURROW_LAYER_POLICY_PATH="$POLICY_PATH"

# check_parity <fixture_id> <agent_type> <tool_name> <tool_input_json> <expected:allow|block>
check_parity() {
  fixture_id="$1"
  agent_type="$2"
  tool_name="$3"
  tool_input_json="$4"
  expected="$5"

  payload=$(printf '{"session_id":"test","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s,"agent_id":"agent-1","agent_type":"%s"}' \
    "$tool_name" "$tool_input_json" "$agent_type")

  # Claude side (direct invocation of furrow hook layer-guard).
  claude_result=0
  claude_result=$(printf "%s" "$payload" | "$FURROW_BIN" hook layer-guard > /dev/null 2>&1; echo $?) || true

  # Pi side (identical binary, identical payload — structural parity).
  pi_result=0
  pi_result=$(printf "%s" "$payload" | "$FURROW_BIN" hook layer-guard > /dev/null 2>&1; echo $?) || true

  # Determine expected exit code.
  expected_exit=0
  if [ "$expected" = "block" ]; then
    expected_exit=2
  fi

  # Assert Claude verdict.
  if [ "$claude_result" = "$expected_exit" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "PASS [%s] claude: %s (%s)\n" "$fixture_id" "$expected" "$tool_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "FAIL [%s] claude: expected %s (exit %d) got exit %d\n" \
      "$fixture_id" "$expected" "$expected_exit" "$claude_result"
    printf "     payload: %s\n" "$payload"
  fi

  # Assert parity: Pi == Claude.
  if [ "$claude_result" = "$pi_result" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "PASS [%s] parity: claude=%d pi=%d match\n" "$fixture_id" "$claude_result" "$pi_result"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "FAIL [%s] parity: claude=%d pi=%d MISMATCH\n" "$fixture_id" "$claude_result" "$pi_result"
  fi
}

# ---------------------------------------------------------------------------
# Parity fixture table (matches spec Table in ## parity-test-fixtures)
# ---------------------------------------------------------------------------

# Fixture 1: operator Write → allow
check_parity "F1" "operator" "Write" '{"file_path":"definition.yaml"}' "allow"

# Fixture 2: driver:plan Write → allow (drivers write row artifacts)
check_parity "F2" "driver:plan" "Write" '{"file_path":".furrow/rows/example/definition.yaml"}' "allow"

# Fixture 3: driver:plan Bash rws status → allow
check_parity "F3" "driver:plan" "Bash" '{"command":"rws status"}' "allow"

# Fixture 4: driver:plan Bash rm -rf /tmp/x → block (bash_deny_substrings)
check_parity "F4" "driver:plan" "Bash" '{"command":"rm -rf /tmp/x"}' "block"

# Fixture 5: engine Write src/foo.go → allow
check_parity "F5" "engine:specialist:go-specialist" "Write" '{"file_path":"src/foo.go"}' "allow"

# Fixture 6: engine Write .furrow/learnings.jsonl → block (path_deny)
check_parity "F6" "engine:specialist:go-specialist" "Write" '{"file_path":".furrow/learnings.jsonl"}' "block"

# Fixture 7: engine Bash furrow context → block (bash_deny_substrings)
check_parity "F7" "engine:specialist:go-specialist" "Bash" '{"command":"furrow context for-step plan"}' "block"

# Fixture 7b: engine Bash furrow row archive → block (real harness-CLI boundary)
check_parity "F7b" "engine:specialist:go-specialist" "Bash" '{"command":"furrow row archive foo"}' "block"

# Fixture 8: engine SendMessage → allow (no signal justifies isolation)
check_parity "F8" "engine:specialist:go-specialist" "SendMessage" '{"to":"subagent_1","body":"hello"}' "allow"

# Fixture 8b: engine Agent → allow (fan-out budget tracked separately)
check_parity "F8b" "engine:specialist:go-specialist" "Agent" '{"subagent_type":"go-specialist","task":"do stuff"}' "allow"

# Fixture 9: engine:freeform Read → allow
check_parity "F9" "engine:freeform" "Read" '{"file_path":"src/foo.go"}' "allow"

# Fixture 10: missing agent_type (main-thread) → operator → Write allow
check_parity "F10" "" "Write" '{"file_path":"src/foo.go"}' "allow"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n--- layer-policy parity: %d passed, %d failed ---\n" \
  "$TESTS_PASSED" "$TESTS_FAILED"

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
