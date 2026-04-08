#!/bin/bash
# helpers.sh — Shared test utilities for integration tests
#
# Source this file; do not execute directly.
# Provides: setup_test_env, teardown_test_env, setup_fixture,
#           teardown_fixture, assert_exit_code, assert_file_exists,
#           assert_file_not_exists, assert_file_contains,
#           assert_file_not_contains, assert_json_field,
#           assert_not_empty, assert_output_contains,
#           assert_ge, run_test, print_summary

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_RUN=0

# Resolve project root (two levels up from tests/integration/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PROJECT_ROOT

# --- Test environment setup ---

# setup_test_env
#   Creates an isolated temp directory with .furrow/ structure,
#   initializes a git repo, sets up PATH to include bin/.
#   Sets TEST_DIR as the working directory for all test operations.
setup_test_env() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR

  # Add project bin/ to PATH so sds/rws/alm are available
  export PATH="${PROJECT_ROOT}/bin:${PATH}"

  # Initialize minimal git repo
  (
    cd "$TEST_DIR" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    echo "init" > .gitkeep &&
    git add -A &&
    git commit -q -m "initial"
  )

  # Create .furrow/ skeleton (do NOT create seeds/ — let sds init do that)
  mkdir -p "${TEST_DIR}/.furrow/rows"
  mkdir -p "${TEST_DIR}/.furrow/almanac"
  mkdir -p "${TEST_DIR}/.claude"
  mkdir -p "${TEST_DIR}/skills"

  # Create minimal furrow.yaml
  cat > "${TEST_DIR}/.furrow/furrow.yaml" << 'YAML'
defaults:
  mode: code
  gate_policy: supervised
seeds:
  prefix: test-proj
YAML

  # Create minimal skill files so load-step works
  for step in ideate research plan spec decompose implement review; do
    echo "# ${step} step instructions" > "${TEST_DIR}/skills/${step}.md"
  done

  # Ensure cleanup on signal
  trap 'rm -rf "${TEST_DIR:-}"' EXIT INT TERM
}

# teardown_test_env
#   Removes TEST_DIR if set.
teardown_test_env() {
  if [ -n "${TEST_DIR:-}" ] && [ -d "${TEST_DIR}" ]; then
    rm -rf "${TEST_DIR}"
  fi
  unset TEST_DIR
}

# --- Legacy fixture management (for test-generate-plan.sh compatibility) ---

# setup_fixture <name>
#   Creates a temp dir with .furrow/rows/<name>/ structure.
#   Sets FIXTURE_DIR, WORK_DIR. Registers cleanup trap.
setup_fixture() {
  _name="$1"
  FIXTURE_DIR="$(mktemp -d)"
  WORK_DIR="${FIXTURE_DIR}/.furrow/rows/${_name}"
  mkdir -p "${WORK_DIR}"
  mkdir -p "${FIXTURE_DIR}/skills"
  # Ensure cleanup on signal interruption
  trap 'rm -rf "${FIXTURE_DIR:-}"' EXIT INT TERM
  export FIXTURE_DIR WORK_DIR
}

# Resolve roots for tests — install root and project root are the same in tests
FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT
export PROJECT_ROOT

# teardown_fixture
#   Removes FIXTURE_DIR if set.
teardown_fixture() {
  if [ -n "${FIXTURE_DIR:-}" ] && [ -d "${FIXTURE_DIR}" ]; then
    rm -rf "${FIXTURE_DIR}"
  fi
  unset FIXTURE_DIR WORK_DIR
}

# --- Assertion functions ---

# assert_exit_code <description> <expected> <actual>
assert_exit_code() {
  _desc="$1"; _expected="$2"; _actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_expected" = "$_actual" ]; then
    printf "  PASS: %s (exit %s)\n" "$_desc" "$_actual"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s (expected exit %s, got %s)\n" "$_desc" "$_expected" "$_actual" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# assert_file_exists <description> <path>
assert_file_exists() {
  _desc="$1"; _path="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -f "$_path" ]; then
    printf "  PASS: %s\n" "$_desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s (file not found: %s)\n" "$_desc" "$_path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# assert_file_not_exists <description> <path>
assert_file_not_exists() {
  _desc="$1"; _path="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ ! -f "$_path" ]; then
    printf "  PASS: %s\n" "$_desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s (file unexpectedly exists: %s)\n" "$_desc" "$_path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# assert_file_contains <description> <path> <pattern>
assert_file_contains() {
  _desc="$1"; _path="$2"; _pattern="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "$_pattern" "$_path" 2>/dev/null; then
    printf "  PASS: %s\n" "$_desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s (pattern '%s' not found in %s)\n" "$_desc" "$_pattern" "$_path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# assert_file_not_contains <description> <path> <pattern>
assert_file_not_contains() {
  _desc="$1"; _path="$2"; _pattern="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! grep -q "$_pattern" "$_path" 2>/dev/null; then
    printf "  PASS: %s\n" "$_desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s (pattern '%s' unexpectedly found in %s)\n" "$_desc" "$_pattern" "$_path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# assert_json_field <description> <file> <jq_expr> <expected>
assert_json_field() {
  _desc="$1"; _file="$2"; _expr="$3"; _expected="$4"
  TESTS_RUN=$((TESTS_RUN + 1))
  _actual="$(jq -r "$_expr" "$_file" 2>/dev/null)" || _actual="__JQ_ERROR__"
  if [ "$_actual" = "$_expected" ]; then
    printf "  PASS: %s\n" "$_desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s (expected '%s', got '%s')\n" "$_desc" "$_expected" "$_actual" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# assert_not_empty <description> <value>
assert_not_empty() {
  _desc="$1"; _value="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -n "$_value" ]; then
    printf "  PASS: %s\n" "$_desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s (value is empty)\n" "$_desc" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# assert_output_contains <description> <output> <pattern>
assert_output_contains() {
  _desc="$1"; _output="$2"; _pattern="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s\n' "$_output" | grep -q "$_pattern" 2>/dev/null; then
    printf "  PASS: %s\n" "$_desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s (pattern '%s' not found in output)\n" "$_desc" "$_pattern" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# assert_ge <description> <actual> <minimum>
assert_ge() {
  _desc="$1"; _actual="$2"; _minimum="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_actual" -ge "$_minimum" ] 2>/dev/null; then
    printf "  PASS: %s (%s >= %s)\n" "$_desc" "$_actual" "$_minimum"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s (expected >= %s, got %s)\n" "$_desc" "$_minimum" "$_actual" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# --- Test runner ---

# run_test <function_name>
#   Calls the function, catches failures, updates counters.
run_test() {
  _func="$1"
  printf "  --- %s ---\n" "$_func"
  if "$_func"; then
    : # assertions inside already counted
  else
    : # assertions inside already counted failures
  fi
}

# print_summary
#   Prints test summary and exits with appropriate code.
print_summary() {
  echo ""
  echo "=========================================="
  printf "  Results: %s passed, %s failed, %s total\n" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_RUN"
  echo "=========================================="
  if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
  fi
  exit 0
}
