#!/bin/sh
# run-ci-checks.sh — Run CI tests and produce structured gate evidence
#
# Usage: run-ci-checks.sh <name>
#   name — work unit name
#
# Reads CI commands from .claude/harness.yaml ci section.
# Produces gate evidence at .work/{name}/gates/implement-to-review-ci.json.
#
# Exit codes:
#   0 — all checks pass
#   1 — checks failed
#   2 — missing configuration

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: run-ci-checks.sh <name>" >&2
  exit 1
fi

name="$1"

work_dir=".work/${name}"
gates_dir="${work_dir}/gates"

# --- read CI config ---

harness_config=".claude/harness.yaml"
test_cmd=""
lint_cmd=""
build_cmd=""

if [ -f "${harness_config}" ] && command -v yq > /dev/null 2>&1; then
  test_cmd="$(yq -r '.ci.test_command // ""' "${harness_config}" 2>/dev/null)" || test_cmd=""
  lint_cmd="$(yq -r '.ci.lint_command // ""' "${harness_config}" 2>/dev/null)" || lint_cmd=""
  build_cmd="$(yq -r '.ci.build_command // ""' "${harness_config}" 2>/dev/null)" || build_cmd=""
fi

if [ -z "${test_cmd}" ] && [ -z "${lint_cmd}" ] && [ -z "${build_cmd}" ]; then
  echo "No CI commands configured in ${harness_config} under 'ci' key." >&2
  echo "Configure ci.test_command, ci.lint_command, or ci.build_command." >&2
  exit 2
fi

# --- run checks ---

mkdir -p "${gates_dir}"

overall="pass"
tests_total=0
tests_passed=0
tests_failed=0
duration_start="$(date +%s)"
ci_command="${test_cmd}"

# Run build
if [ -n "${build_cmd}" ]; then
  echo "Running build: ${build_cmd}"
  if eval "${build_cmd}" > /dev/null 2>&1; then
    echo "Build: PASS"
  else
    echo "Build: FAIL"
    overall="fail"
  fi
fi

# Run lint
if [ -n "${lint_cmd}" ]; then
  echo "Running lint: ${lint_cmd}"
  if eval "${lint_cmd}" > /dev/null 2>&1; then
    echo "Lint: PASS"
  else
    echo "Lint: FAIL"
    overall="fail"
  fi
fi

# Run tests
if [ -n "${test_cmd}" ]; then
  echo "Running tests: ${test_cmd}"
  test_output_file="${gates_dir}/ci-test-output.txt"
  if eval "${test_cmd}" > "${test_output_file}" 2>&1; then
    echo "Tests: PASS"
    # Try to extract test counts from output
    tests_total="$(grep -cE '(^ok|^PASS|PASSED|--- PASS)' "${test_output_file}" 2>/dev/null || echo "0")"
    tests_passed="${tests_total}"
  else
    echo "Tests: FAIL"
    overall="fail"
    tests_total="$(grep -cE '(^ok|^FAIL|PASSED|FAILED|--- )' "${test_output_file}" 2>/dev/null || echo "0")"
    tests_failed="$(grep -cE '(^FAIL|FAILED|--- FAIL)' "${test_output_file}" 2>/dev/null || echo "0")"
    tests_passed=$((tests_total - tests_failed))
  fi
  rm -f "${test_output_file}"
fi

duration_end="$(date +%s)"
duration=$((duration_end - duration_start))
now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- write structured gate evidence ---

jq -n \
  --arg overall "${overall}" \
  --arg now "${now}" \
  --arg cmd "${ci_command}" \
  --argjson total "${tests_total}" \
  --argjson passed "${tests_passed}" \
  --argjson failed "${tests_failed}" \
  --argjson duration "${duration}" \
  '{
    boundary: "implement->review",
    ci_run: {
      tests_total: $total,
      tests_passed: $passed,
      tests_failed: $failed,
      tests_skipped: 0,
      duration_seconds: $duration,
      command: $cmd
    },
    overall: $overall,
    timestamp: $now
  }' > "${gates_dir}/implement-to-review-ci.json"

echo "CI evidence written: ${gates_dir}/implement-to-review-ci.json"

if [ "${overall}" = "fail" ]; then
  exit 1
fi

exit 0
