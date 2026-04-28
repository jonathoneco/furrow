#!/bin/sh
# test-layer-policy-parity.sh — Cross-adapter layer policy test for D3.
#
# Claude compatibility is exercised through `furrow hook layer-guard`.
# Pi parity is exercised through the auto-discovered `.pi/extensions/furrow.ts`
# entrypoint, which registers the loaded adapter path and calls the normalized
# `furrow layer decide` backend command. This test must not pass by invoking the
# same backend command twice and calling that adapter parity.
#
# Exit codes: 0=pass, 1=fail

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Build furrow binary.
FURROW_BIN="${TMPDIR:-/tmp}/furrow_layer_policy_parity_$$"
trap 'rm -f "$FURROW_BIN"' EXIT

if ! go build -o "$FURROW_BIN" "$PROJECT_ROOT/cmd/furrow" 2>/dev/null; then
  printf "FAIL: could not build furrow binary\n"
  exit 1
fi

export FURROW_BIN

claude_payload='{"session_id":"test","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":".furrow/rows/x/state.json"},"agent_id":"engine-1","agent_type":"engine:specialist:go-specialist"}'
stderr_file="${TMPDIR:-/tmp}/furrow_layer_policy_parity_stderr_$$"
trap 'rm -f "$FURROW_BIN" "$stderr_file"' EXIT
if printf '%s' "$claude_payload" | "$FURROW_BIN" hook layer-guard >/dev/null 2>"$stderr_file"; then
  printf "FAIL: Claude hook allowed engine .furrow write\n" >&2
  exit 1
fi
printf "PASS: Claude hook blocks engine .furrow write\n"
if grep -q "layer_tool_violation" "$stderr_file"; then
  printf "PASS: Claude hook exposes layer rejection reason on stderr\n"
else
  printf "FAIL: Claude hook did not expose layer rejection reason on stderr\n" >&2
  exit 1
fi

if (cd "$PROJECT_ROOT/adapters/pi" && bun test furrow.test.ts -t "loaded Pi entrypoint layer guard"); then
  printf "PASS: loaded Pi entrypoint layer guard test passed\n"
else
  printf "FAIL: loaded Pi entrypoint layer guard test failed\n" >&2
  exit 1
fi
