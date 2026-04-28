#!/bin/sh
# test-layered-dispatch-e2e.sh — End-to-end smoke test for D3 layered dispatch.
#
# Validates that the 3-layer boundary (operator → driver → engine) is correctly
# enforced by furrow hook layer-guard for all three layers. Each layer's expected
# tool set is verified against the canonical layer policy.
#
# This test operates without a live Claude or Pi session. It exercises the
# layer-guard Go binary directly to simulate what would happen during a real
# operator→driver→engine round-trip, and checks:
#   1. Operator can do everything (Write, Edit, Bash).
#   2. Driver cannot Write/Edit; can Bash with allowed prefixes.
#   3. Engine cannot touch .furrow/ paths or run furrow/rws/alm commands.
#   4. `furrow validate layer-policy` exits 0.
#   5. `furrow validate skill-layers` exits 0 (skills have layer: front-matter).
#   6. `furrow validate driver-definitions` exits 0.
#   7. Boundary leakage corpus check on simulated engine output: 0 matches.
#
# Exit codes: 0=pass, 1=fail

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
POLICY_PATH="$PROJECT_ROOT/.furrow/layer-policy.yaml"
CORPUS_FILE="$SCRIPT_DIR/fixtures/leakage-corpus.regex"

TESTS_PASSED=0
TESTS_FAILED=0

# Build furrow binary.
FURROW_BIN="$PROJECT_ROOT/_e2e_test_furrow_$$"
trap 'rm -f "$FURROW_BIN"' EXIT

printf "Building furrow binary...\n"
if ! go build -o "$FURROW_BIN" "$PROJECT_ROOT/cmd/furrow" 2>&1; then
  printf "FAIL: could not build furrow binary\n"
  exit 1
fi

export FURROW_LAYER_POLICY_PATH="$POLICY_PATH"

pass() { printf "PASS: %s\n" "$1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { printf "FAIL: %s\n" "$1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

# assert_layer_guard <label> <agent_type> <tool_name> <tool_input_json> <expected:0|2>
assert_layer_guard() {
  label="$1"
  agent_type="$2"
  tool_name="$3"
  tool_input_json="$4"
  expected_exit="$5"

  payload=$(printf '{"session_id":"e2e","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s,"agent_id":"a1","agent_type":"%s"}' \
    "$tool_name" "$tool_input_json" "$agent_type")

  actual_exit=0
  printf "%s" "$payload" | "$FURROW_BIN" hook layer-guard > /dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" = "$expected_exit" ]; then
    pass "$label (exit $actual_exit)"
  else
    fail "$label: expected exit $expected_exit got $actual_exit | payload: $payload"
  fi
}

# ---------------------------------------------------------------------------
# Phase 1: Operator layer — should allow all tools
# ---------------------------------------------------------------------------
printf "\n=== Phase 1: Operator layer ===\n"
assert_layer_guard "operator can Write"  "operator" "Write" '{"file_path":"src/foo.go"}' "0"
assert_layer_guard "operator can Edit"   "operator" "Edit"  '{"file_path":"src/foo.go","old_string":"x","new_string":"y"}' "0"
assert_layer_guard "operator can Read"   "operator" "Read"  '{"file_path":".furrow/state.json"}' "0"
assert_layer_guard "operator can Bash"   "operator" "Bash"  '{"command":"go test ./..."}' "0"

# ---------------------------------------------------------------------------
# Phase 2: Driver layer — artifact writes pass; Bash guardrails remain
# ---------------------------------------------------------------------------
printf "\n=== Phase 2: Driver layer (driver:plan) ===\n"
assert_layer_guard "driver Write is allowed"     "driver:plan" "Write" '{"file_path":".furrow/rows/example/definition.yaml"}' "0"
assert_layer_guard "driver Edit is allowed"      "driver:plan" "Edit"  '{"file_path":".furrow/rows/example/definition.yaml","old_string":"x","new_string":"y"}' "0"
assert_layer_guard "driver Bash rws allowed"     "driver:plan" "Bash"  '{"command":"rws status"}' "0"
assert_layer_guard "driver Bash furrow context"  "driver:plan" "Bash"  '{"command":"furrow context for-step plan"}' "0"
assert_layer_guard "driver Bash rm blocked"      "driver:plan" "Bash"  '{"command":"rm -rf /tmp/x"}' "2"
assert_layer_guard "driver Bash redirect blocked" "driver:plan" "Bash" '{"command":"echo hello > out.txt"}' "2"
assert_layer_guard "driver Read allowed"         "driver:plan" "Read"  '{"file_path":"src/foo.go"}' "0"

# ---------------------------------------------------------------------------
# Phase 3: Engine layer — .furrow/ paths and furrow commands blocked
# ---------------------------------------------------------------------------
printf "\n=== Phase 3: Engine layer (engine:specialist:go-specialist) ===\n"
assert_layer_guard "engine Write src allowed"    "engine:specialist:go-specialist" "Write" '{"file_path":"src/foo.go"}' "0"
assert_layer_guard "engine Edit allowed"         "engine:specialist:go-specialist" "Edit"  '{"file_path":"src/add.go","old_string":"x","new_string":"y"}' "0"
assert_layer_guard "engine Write .furrow blocked" "engine:specialist:go-specialist" "Write" '{"file_path":".furrow/state.json"}' "2"
assert_layer_guard "engine Edit .furrow blocked" "engine:specialist:go-specialist" "Edit"  '{"file_path":".furrow/definition.yaml","old_string":"x","new_string":"y"}' "2"
assert_layer_guard "engine Bash furrow blocked"  "engine:specialist:go-specialist" "Bash"  '{"command":"furrow context for-step plan"}' "2"
assert_layer_guard "engine Bash rws blocked"     "engine:specialist:go-specialist" "Bash"  '{"command":"rws transition row plan pass auto {}"}' "2"
assert_layer_guard "engine SendMessage allowed" "engine:specialist:go-specialist" "SendMessage" '{"to":"subagent","body":"help"}' "0"
assert_layer_guard "engine Agent allowed"        "engine:specialist:go-specialist" "Agent"  '{"task":"do stuff"}' "0"
assert_layer_guard "engine Read allowed"         "engine:specialist:go-specialist" "Read"  '{"file_path":"src/foo.go"}' "0"

# Positive boundary cases: exercise the real engine invariants
# (cannot mutate Furrow state, cannot invoke harness CLIs).
assert_layer_guard "engine Bash furrow CLI blocked" "engine:specialist:go-specialist" "Bash" '{"command":"furrow row status foo"}' "2"
assert_layer_guard "engine Bash rws CLI blocked"    "engine:specialist:go-specialist" "Bash" '{"command":"rws transition foo plan pass auto {}"}' "2"
assert_layer_guard "engine Write .furrow/ blocked"  "engine:specialist:go-specialist" "Write" '{"file_path":".furrow/learnings.jsonl"}' "2"
assert_layer_guard "engine Write src/ allowed"      "engine:specialist:go-specialist" "Write" '{"file_path":"src/foo.go"}' "0"

# ---------------------------------------------------------------------------
# Phase 4: validate commands
# ---------------------------------------------------------------------------
printf "\n=== Phase 4: Validate commands ===\n"

if "$FURROW_BIN" validate layer-policy --policy "$POLICY_PATH" > /dev/null 2>&1; then
  pass "furrow validate layer-policy exits 0"
else
  fail "furrow validate layer-policy should exit 0 for canonical policy"
fi

if "$FURROW_BIN" validate skill-layers --skills-dir "$PROJECT_ROOT/skills" > /dev/null 2>&1; then
  pass "furrow validate skill-layers exits 0"
else
  fail "furrow validate skill-layers should exit 0 (all skills have layer: front-matter)"
fi

DRIVERS_DIR="$PROJECT_ROOT/.furrow/drivers"
if "$FURROW_BIN" validate driver-definitions --drivers-dir "$DRIVERS_DIR" > /dev/null 2>&1; then
  pass "furrow validate driver-definitions exits 0"
else
  fail "furrow validate driver-definitions should exit 0"
fi

# ---------------------------------------------------------------------------
# Phase 5: Boundary leakage check on simulated engine output
# ---------------------------------------------------------------------------
printf "\n=== Phase 5: Boundary leakage check ===\n"

ENGINE_OUTPUT_DIR="$(mktemp -d)"
trap 'rm -rf "$ENGINE_OUTPUT_DIR"; rm -f "$FURROW_BIN"' EXIT

cat > "$ENGINE_OUTPUT_DIR/engine-result.md" << 'ENGINEOUT'
# EOS Report: go-specialist

## Objective Completed

Implemented `double(x int) int` function in `add.go`.

## Changes

- `add.go`: Added `func double(x int) int { return x * 2 }`
- `add_test.go`: Added `TestDouble` verifying `double(2) == 4`

## Test Results

```
ok  github.com/example/add   0.001s
```
ENGINEOUT

# shellcheck disable=SC2126
LEAKAGE_COUNT=$(grep -Ef "$CORPUS_FILE" "$ENGINE_OUTPUT_DIR/engine-result.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$LEAKAGE_COUNT" -eq 0 ]; then
  pass "zero Furrow vocabulary in simulated engine output"
else
  fail "engine_furrow_leakage: $LEAKAGE_COUNT matches in engine output"
  grep -nEf "$CORPUS_FILE" "$ENGINE_OUTPUT_DIR/engine-result.md" | head -10
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n--- layered-dispatch-e2e: %d passed, %d failed ---\n" \
  "$TESTS_PASSED" "$TESTS_FAILED"

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
