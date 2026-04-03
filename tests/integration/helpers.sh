#!/bin/bash
# helpers.sh — Shared test utilities for integration tests
#
# Source this file; do not execute directly.
# Provides: setup_fixture, teardown_fixture, assert_exit_code,
#           assert_file_exists, assert_file_contains, assert_json_field,
#           run_test

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_RUN=0

# Resolve Furrow root (two levels up from tests/integration/)
FURROW_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FURROW_ROOT

# --- Fixture management ---

# setup_fixture <name>
#   Creates a temp dir with .work/<name>/ structure.
#   Sets FIXTURE_DIR, WORK_DIR. Registers cleanup trap.
setup_fixture() {
  _name="$1"
  FIXTURE_DIR="$(mktemp -d)"
  WORK_DIR="${FIXTURE_DIR}/.work/${_name}"
  mkdir -p "${WORK_DIR}"
  mkdir -p "${FIXTURE_DIR}/skills"
  # Ensure cleanup on signal interruption
  trap 'rm -rf "${FIXTURE_DIR:-}"' EXIT INT TERM
  export FIXTURE_DIR WORK_DIR
}

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
