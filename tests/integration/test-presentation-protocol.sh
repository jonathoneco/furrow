#!/bin/sh
# tests/integration/test-presentation-protocol.sh
#
# Integration test for D6 artifact-presentation-protocol.
# Replays fixture transcripts through `furrow hook presentation-check` and
# asserts the correct blocker-emission behaviour.
#
# Exit codes (harness convention):
#   0 — all assertions passed
#   1 — assertion failure
#   2 — setup/environment failure
#
# Requires: furrow binary on PATH (or built at project root).

set -eu

PASS=0
FAIL=0
BINARY="${FURROW_BIN:-furrow}"
TMPDIR_ROOT=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
    printf 'SETUP ERROR: %s\n' "$*" >&2
    exit 2
}

assert_pass() {
    PASS=$((PASS + 1))
    printf 'PASS  %s\n' "$1"
}

assert_fail() {
    FAIL=$((FAIL + 1))
    printf 'FAIL  %s\n' "$1" >&2
}

# make_transcript <agent_type> <content>  → writes JSONL to a temp file, echoes path
make_transcript() {
    _agent_type="$1"
    _content="$2"
    _dir="${TMPDIR_ROOT}/$(printf '%s' "$_agent_type" | tr ':/' '_')"
    mkdir -p "$_dir"
    _path="$_dir/transcript.jsonl"
    # One assistant message line in Claude JSONL transcript shape.
    printf '{"type":"message","message":{"role":"assistant","content":%s}}\n' \
        "$(printf '%s' "$_content" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')" \
        > "$_path"
    printf '%s' "$_path"
}

# build_stop_input <transcript_path> <agent_type>  → echoes JSON payload
build_stop_input() {
    _transcript_path="$1"
    _agent_type="$2"
    python3 -c "
import json, sys
payload = {
    'session_id': 'integration-test',
    'stop_hook_active': True,
    'transcript_path': sys.argv[1],
    'hook_event_name': 'Stop',
    'agent_type': sys.argv[2],
}
print(json.dumps(payload))
" "$_transcript_path" "$_agent_type"
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

command -v "$BINARY" > /dev/null 2>&1 || die "furrow binary not found on PATH (set FURROW_BIN)"
command -v python3 > /dev/null 2>&1 || die "python3 not found on PATH (needed for JSON fixture generation)"

TMPDIR_ROOT="$(mktemp -d)"
# Cleanup on exit.
# shellcheck disable=SC2064
trap "rm -rf '${TMPDIR_ROOT}'" EXIT

# ---------------------------------------------------------------------------
# Fixture A: artifact-shaped content WITHOUT markers → expect violation
# ---------------------------------------------------------------------------

FIXTURE_A_CONTENT="Here is the spec for review:

## Goals
Define the artifact presentation protocol.

## Non-Goals
Invent new marker syntax.

## Acceptance
- The protocol doc exists.
- The hook is advisory-only.

.furrow/rows/orchestration-delegation-contract/spec.md"

transcript_a="$(make_transcript "operator" "$FIXTURE_A_CONTENT")"
stop_input_a="$(build_stop_input "$transcript_a" "operator")"

output_a="$(printf '%s' "$stop_input_a" | "$BINARY" hook presentation-check)"
exit_a=$?

if [ "$exit_a" -eq 0 ]; then
    assert_pass "fixture-A: exit code is 0 (advisory hook never blocks)"
else
    assert_fail "fixture-A: expected exit 0, got ${exit_a}"
fi

if printf '%s' "$output_a" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('code')=='presentation_protocol_violation' else 1)" 2>/dev/null; then
    assert_pass "fixture-A: blocker code is presentation_protocol_violation"
else
    assert_fail "fixture-A: expected blocker code presentation_protocol_violation, output was: ${output_a}"
fi

if printf '%s' "$output_a" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('severity')=='warn' else 1)" 2>/dev/null; then
    assert_pass "fixture-A: severity is warn"
else
    assert_fail "fixture-A: expected severity warn"
fi

if printf '%s' "$output_a" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('confirmation_path')=='silent' else 1)" 2>/dev/null; then
    assert_pass "fixture-A: confirmation_path is silent"
else
    assert_fail "fixture-A: expected confirmation_path silent"
fi

# ---------------------------------------------------------------------------
# Fixture B: same content WITH proper markers → expect no emission
# ---------------------------------------------------------------------------

FIXTURE_B_CONTENT="Here is the spec for review:

<!-- presentation:section:goals -->

## Goals
Define the artifact presentation protocol.

<!-- presentation:section:non-goals -->

## Non-Goals
Invent new marker syntax.

<!-- presentation:section:acceptance -->

## Acceptance
- The protocol doc exists.
- The hook is advisory-only.

<!-- presentation:section:artifact-path -->

.furrow/rows/orchestration-delegation-contract/spec.md"

transcript_b="$(make_transcript "operator" "$FIXTURE_B_CONTENT")"
stop_input_b="$(build_stop_input "$transcript_b" "operator")"

output_b="$(printf '%s' "$stop_input_b" | "$BINARY" hook presentation-check)"
exit_b=$?

if [ "$exit_b" -eq 0 ]; then
    assert_pass "fixture-B: exit code is 0"
else
    assert_fail "fixture-B: expected exit 0, got ${exit_b}"
fi

trimmed_b="$(printf '%s' "$output_b" | tr -d '[:space:]')"
if [ -z "$trimmed_b" ]; then
    assert_pass "fixture-B: no emission when markers are present"
else
    assert_fail "fixture-B: expected empty output with markers, got: ${output_b}"
fi

# ---------------------------------------------------------------------------
# Fixture C: engine-layer turn with unmarked artifact content → no emission
# ---------------------------------------------------------------------------

FIXTURE_C_CONTENT="Analysis complete. The artifact at .furrow/rows/orchestration-delegation-contract/definition.yaml shows the following structure:

objective: add artifact presentation protocol
deliverables:
  - name: artifact-presentation-protocol"

transcript_c="$(make_transcript "engine:specialist:go-specialist" "$FIXTURE_C_CONTENT")"
stop_input_c="$(build_stop_input "$transcript_c" "engine:specialist:go-specialist")"

output_c="$(printf '%s' "$stop_input_c" | "$BINARY" hook presentation-check)"
exit_c=$?

if [ "$exit_c" -eq 0 ]; then
    assert_pass "fixture-C: exit code is 0 for engine turn"
else
    assert_fail "fixture-C: expected exit 0, got ${exit_c}"
fi

trimmed_c="$(printf '%s' "$output_c" | tr -d '[:space:]')"
if [ -z "$trimmed_c" ]; then
    assert_pass "fixture-C: engine turns skipped (no emission)"
else
    assert_fail "fixture-C: engine turns should not emit violations, got: ${output_c}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
