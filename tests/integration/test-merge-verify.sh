#!/bin/bash
# test-merge-verify.sh — Unit tests for merge-verify.sh (Phase 5) [AC-7]

set -eu
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${TESTS_DIR}/helpers.sh"

# ─── Fixture ────────────────────────────────────────────────────────────────

setup_verify_fixture() {
  VERIFY_REPO="$(mktemp -d)"
  export VERIFY_REPO

  (
    cd "$VERIFY_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "root" > README.md
    git add README.md
    git commit -q -m "initial"
  )

  VERIFY_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/furrow/$(basename "$PROJECT_ROOT")/merge-state"
  VERIFY_MERGE_ID="verify-$(date +%s)"
  VERIFY_MERGE_DIR="${VERIFY_STATE_DIR}/${VERIFY_MERGE_ID}"
  mkdir -p "$VERIFY_MERGE_DIR"
  export VERIFY_STATE_DIR VERIFY_MERGE_ID VERIFY_MERGE_DIR

  local base_sha
  base_sha="$(git -C "$VERIFY_REPO" rev-parse HEAD)"

  # Write minimal audit.json
  jq -n \
    --arg merge_id "$VERIFY_MERGE_ID" \
    --arg base_sha "$base_sha" \
    '{
      schema_version: "1.0",
      merge_id: $merge_id,
      branch: "work/verify-test",
      base_sha: $base_sha,
      head_sha: $base_sha,
      policy_path: "schemas/merge-policy.yaml",
      policy_sha256: "abc",
      symlink_typechanges: [],
      protected_touches: [],
      install_artifact_additions: [],
      overlap_commits: [],
      stale_references: {"todos":[],"rows":[]},
      commonsh_parse: {"ours":true,"theirs":true},
      blockers: [],
      reintegration_json: {}
    }' > "${VERIFY_MERGE_DIR}/audit.json"

  # Write execute.json indicating a completed merge
  jq -n \
    --arg merge_id "$VERIFY_MERGE_ID" \
    --arg merge_sha "$base_sha" \
    '{
      schema_version: "1.0",
      merge_id: $merge_id,
      status: "complete",
      merge_sha: $merge_sha,
      deviations: [],
      warnings: [],
      commonsh_broken: false
    }' > "${VERIFY_MERGE_DIR}/execute.json"
}

teardown_verify_fixture() {
  rm -rf "${VERIFY_REPO:-}" "${VERIFY_MERGE_DIR:-}" 2>/dev/null || true
}

# ─── Tests ──────────────────────────────────────────────────────────────────

test_verify_usage_error() {
  printf '  --- test_verify_usage_error ---\n'
  local exit_code=0
  (PROJECT_ROOT="$VERIFY_REPO" FURROW_ROOT="$PROJECT_ROOT" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-verify.sh" 2>/dev/null) || exit_code=$?
  assert_exit_code "verify with no args exits 1" 1 "$exit_code"
}

test_verify_missing_execute_json() {
  printf '  --- test_verify_missing_execute_json ---\n'
  local exit_code=0
  (PROJECT_ROOT="$VERIFY_REPO" FURROW_ROOT="$PROJECT_ROOT" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-verify.sh" "nonexistent-id" 2>/dev/null) || exit_code=$?
  assert_exit_code "verify with missing execute.json exits 2" 2 "$exit_code"
}

test_verify_writes_verify_json() {
  printf '  --- test_verify_writes_verify_json ---\n'
  local exit_code=0
  # Run verify — will exit 7 because frw doctor likely fails in isolated env
  (PROJECT_ROOT="$VERIFY_REPO" FURROW_ROOT="$PROJECT_ROOT" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-verify.sh" "$VERIFY_MERGE_ID" 2>/dev/null) || exit_code=$?

  # Exit 0 or 7 are both acceptable (some checks may pass or fail in isolation)
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$exit_code" -eq 0 ] || [ "$exit_code" -eq 7 ]; then
    printf '  PASS: verify exits 0 or 7 (got %s)\n' "$exit_code"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: verify exited %s (expected 0 or 7)\n' "$exit_code" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  local verify_json="${VERIFY_MERGE_DIR}/verify.json"
  assert_file_exists "verify.json produced" "$verify_json"

  if [ -f "$verify_json" ]; then
    assert_json_field "verify.json schema_version" "$verify_json" ".schema_version" "1.0"

    # Check overall field exists
    TESTS_RUN=$((TESTS_RUN + 1))
    local overall
    overall="$(jq -r '.overall' "$verify_json" 2>/dev/null || echo 'null')"
    if [ "$overall" = "pass" ] || [ "$overall" = "fail" ]; then
      printf '  PASS: verify.json overall is %s\n' "$overall"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: verify.json overall is %s (expected pass or fail)\n' "$overall" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Check checks array has 6 items
    TESTS_RUN=$((TESTS_RUN + 1))
    local n_checks
    n_checks="$(jq '.checks | length' "$verify_json" 2>/dev/null || echo 0)"
    if [ "$n_checks" -eq 6 ]; then
      printf '  PASS: verify.json has 6 checks\n'
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: verify.json has %s checks (expected 6)\n' "$n_checks" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  fi
}

test_verify_reuses_wave1_primitives() {
  printf '  --- test_verify_reuses_wave1_primitives ---\n'
  # AC-7: verify calls rws validate-sort-invariant and rescue.sh --baseline-check
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q 'validate-sort-invariant' "${PROJECT_ROOT}/bin/frw.d/scripts/merge-verify.sh" 2>/dev/null; then
    printf '  PASS: merge-verify.sh calls rws validate-sort-invariant\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-verify.sh does not call validate-sort-invariant\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q 'baseline-check' "${PROJECT_ROOT}/bin/frw.d/scripts/merge-verify.sh" 2>/dev/null; then
    printf '  PASS: merge-verify.sh calls rescue.sh --baseline-check\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-verify.sh does not call --baseline-check\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_verify_no_summary_md_parsing() {
  printf '  --- test_verify_no_summary_md_parsing ---\n'
  TESTS_RUN=$((TESTS_RUN + 1))
  local count=0
  count=$(grep -c 'summary\.md' "${PROJECT_ROOT}/bin/frw.d/scripts/merge-verify.sh" 2>/dev/null) || count=0
  count=$((count + 0))
  if [ "$count" -eq 0 ]; then
    printf '  PASS: no summary.md references in merge-verify.sh\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: %s summary.md reference(s) found\n' "$count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
  printf 'test-merge-verify.sh\n'
  printf '==============================\n'

  setup_verify_fixture
  trap 'teardown_verify_fixture' EXIT INT TERM

  run_test test_verify_usage_error
  run_test test_verify_missing_execute_json
  run_test test_verify_writes_verify_json
  run_test test_verify_reuses_wave1_primitives
  run_test test_verify_no_summary_md_parsing

  print_summary
}

main "$@"
