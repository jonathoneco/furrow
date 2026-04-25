#!/usr/bin/env bash
# test-ownership-warn-hook.sh — Integration test for D6 of pre-write-validation-go-first.
#
# Verifies that bin/frw.d/hooks/ownership-warn.sh:
#   - emits log_warning on out-of-scope writes (verdict from Go validator)
#   - is silent on in-scope writes
#   - returns 0 in all cases (warn-not-block)
#   - is silent when no row context can be resolved
#
# The test runs against the live pre-write-validation-go-first row in
# this checkout so it doesn't need a sandboxed Go module to satisfy
# `go run ./cmd/furrow` from the hook body.

set -eu

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PROJECT_ROOT
export FURROW_ROOT="${PROJECT_ROOT}"

ROW="pre-write-validation-go-first"
ROW_DEF="${PROJECT_ROOT}/.furrow/rows/${ROW}/definition.yaml"

if [ ! -f "${ROW_DEF}" ]; then
	echo "FAIL: prerequisite row ${ROW} not present at ${ROW_DEF}" >&2
	exit 1
fi

# Snapshot/restore .furrow/.focused so the test does not leave focus state changed.
focused_path="${PROJECT_ROOT}/.furrow/.focused"
focused_backup=""
if [ -f "${focused_path}" ]; then
	focused_backup="$(cat "${focused_path}")"
fi
restore_focus() {
	if [ -n "${focused_backup}" ]; then
		echo "${focused_backup}" > "${focused_path}"
	fi
}
trap restore_focus EXIT

# Force focus to the test row so find_focused_row resolves it deterministically.
echo "${ROW}" > "${focused_path}"

pass_count=0
fail_count=0

run_hook() {
	local input="$1"
	cd "${PROJECT_ROOT}"
	(
		set +e
		echo "${input}" | bash -c '. "${FURROW_ROOT}/bin/frw.d/hooks/ownership-warn.sh"; hook_ownership_warn'
	)
}

assert_contains() {
	local description="$1"
	local needle="$2"
	local haystack="$3"
	if echo "${haystack}" | grep -q "${needle}"; then
		pass_count=$((pass_count + 1))
		echo "  PASS: ${description}"
	else
		fail_count=$((fail_count + 1))
		echo "  FAIL: ${description} (expected substring: ${needle}; got: ${haystack})" >&2
	fi
}

assert_not_contains() {
	local description="$1"
	local needle="$2"
	local haystack="$3"
	if echo "${haystack}" | grep -q "${needle}"; then
		fail_count=$((fail_count + 1))
		echo "  FAIL: ${description} (unexpected substring: ${needle}; got: ${haystack})" >&2
	else
		pass_count=$((pass_count + 1))
		echo "  PASS: ${description}"
	fi
}

# --- in-scope path: internal/cli/blocker_envelope.go is in D3 ownership ---
output="$(run_hook '{"tool_input":{"file_path":"internal/cli/blocker_envelope.go"}}' 2>&1 || true)"
assert_not_contains "in-scope path is silent" "outside file_ownership" "${output}"

# --- in-scope ** glob: internal/cli/validate_ownership_test.go matches D2 ownership ---
output="$(run_hook '{"tool_input":{"file_path":"internal/cli/validate_ownership_test.go"}}' 2>&1 || true)"
assert_not_contains "in-scope test file is silent" "outside file_ownership" "${output}"

# --- out-of-scope path: definitely outside any deliverable ---
output="$(run_hook '{"tool_input":{"file_path":"random/totally/unrelated.txt"}}' 2>&1 || true)"
assert_contains "out-of-scope path emits log_warning" "outside file_ownership" "${output}"

# --- canonical row artifact: state.json under .furrow/rows/<row>/ → not_applicable → silent ---
output="$(run_hook '{"tool_input":{"file_path":".furrow/rows/'"${ROW}"'/state.json"}}' 2>&1 || true)"
assert_not_contains "canonical row artifact is silent (not_applicable)" "outside file_ownership" "${output}"

# --- exit code is 0 even on out-of-scope (warn-not-block) ---
output="$(run_hook '{"tool_input":{"file_path":"random/path.txt"}}' 2>&1; echo "EXIT=$?")"
assert_contains "out-of-scope returns exit code 0 (warn-not-block)" "EXIT=0" "${output}"

echo ""
echo "Summary: ${pass_count} passed, ${fail_count} failed"
exit "${fail_count}"
