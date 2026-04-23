#!/bin/bash
# run-integration-tests.sh — Discover and run all integration tests
#
# Usage: frw run-integration-tests [test-file-pattern]
#   Runs all tests/integration/test-*.sh files, or a specific one if given.
#
# Return codes:
#   0 — all tests passed
#   1 — one or more tests failed
#   2 — no test files found

frw_run_integration_tests() {
  set -eu

  TEST_DIR="${FURROW_ROOT}/tests/integration"
  HELPERS="${TEST_DIR}/helpers.sh"

  if [ ! -f "${HELPERS}" ]; then
    echo "Error: helpers.sh not found at ${HELPERS}" >&2
    return 2
  fi

  # Check prerequisites
  for cmd in jq yq python3; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
      echo "Error: required command '${cmd}' not found" >&2
      return 2
    fi
  done

  # Discover test files
  if [ $# -ge 1 ]; then
    test_files="${TEST_DIR}/$1"
    if [ ! -f "${test_files}" ]; then
      echo "Error: test file not found: ${test_files}" >&2
      return 2
    fi
    test_files_list="${test_files}"
  else
    test_files_list=""
    for f in "${TEST_DIR}"/test-*.sh; do
      [ -f "$f" ] || continue
      test_files_list="${test_files_list} ${f}"
    done
  fi

  if [ -z "${test_files_list}" ]; then
    echo "Error: no test files found in ${TEST_DIR}" >&2
    return 2
  fi

  TOTAL_PASSED=0
  TOTAL_FAILED=0
  TOTAL_RUN=0
  FILE_COUNT=0

  for test_file in ${test_files_list}; do
    FILE_COUNT=$((FILE_COUNT + 1))
    test_name="$(basename "${test_file}" .sh)"
    printf "\n=== %s ===\n" "${test_name}"

    # Source helpers fresh for each file (resets counters)
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_RUN=0
    # shellcheck source=../tests/integration/helpers.sh
    . "${HELPERS}"

    # Source the test file to load test functions
    # shellcheck disable=SC1090
    . "${test_file}"

    # Discover and run test_ functions
    test_funcs="$(declare -F | awk '{print $3}' | grep '^test_' | sort)"
    for func in ${test_funcs}; do
      run_test "${func}"
    done

    printf "  --- %s: %d/%d passed ---\n" "${test_name}" "${TESTS_PASSED}" "${TESTS_RUN}"
    TOTAL_PASSED=$((TOTAL_PASSED + TESTS_PASSED))
    TOTAL_FAILED=$((TOTAL_FAILED + TESTS_FAILED))
    TOTAL_RUN=$((TOTAL_RUN + TESTS_RUN))

    # Unset test functions to avoid leakage between files
    for func in ${test_funcs}; do
      unset -f "${func}"
    done
  done

  printf "\n=== TOTAL: %d/%d passed (%d files) ===\n" "${TOTAL_PASSED}" "${TOTAL_RUN}" "${FILE_COUNT}"

  if [ "${TOTAL_FAILED}" -gt 0 ]; then
    return 1
  fi
  return 0
}
