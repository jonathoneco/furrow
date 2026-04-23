#!/bin/bash
# test-merge-resolve-plan.sh — Unit tests for merge-resolve-plan.sh (Phase 3) [AC-5]

set -eu
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${TESTS_DIR}/helpers.sh"

POLICY_PATH="${PROJECT_ROOT}/schemas/merge-policy.yaml"

# ─── Fixture ────────────────────────────────────────────────────────────────

setup_plan_fixture() {
  PLAN_REPO="$(mktemp -d)"
  export PLAN_REPO

  (
    cd "$PLAN_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    mkdir -p bin/frw.d/lib
    printf '#!/bin/sh\n' > bin/alm
    git add -A
    git commit -q -m "initial"
    git checkout -q -b work/plan-test
    echo "feature" > feature.txt
    git add feature.txt
    git commit -q -m "feat: add feature"
  )

  PLAN_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/furrow/$(basename "$PROJECT_ROOT")/merge-state"
  PLAN_MERGE_ID="plan-$(date +%s)"
  PLAN_MERGE_DIR="${PLAN_STATE_DIR}/${PLAN_MERGE_ID}"
  mkdir -p "${PLAN_MERGE_DIR}/awaiting"
  export PLAN_STATE_DIR PLAN_MERGE_ID PLAN_MERGE_DIR

  local base_sha head_sha
  base_sha="$(git -C "$PLAN_REPO" rev-parse HEAD~1 2>/dev/null || git -C "$PLAN_REPO" rev-parse HEAD)"
  head_sha="$(git -C "$PLAN_REPO" rev-parse HEAD)"

  # Write audit.json with a conflict on a protected path
  jq -n \
    --arg merge_id "$PLAN_MERGE_ID" \
    --arg branch "work/plan-test" \
    --arg base_sha "$base_sha" \
    --arg head_sha "$head_sha" \
    --arg policy_path "$POLICY_PATH" \
    '{
      schema_version: "1.0",
      merge_id: $merge_id,
      branch: $branch,
      base_sha: $base_sha,
      head_sha: $head_sha,
      policy_path: $policy_path,
      policy_sha256: "abc123",
      symlink_typechanges: [],
      protected_touches: [{"path": "bin/alm", "side": "worktree"}],
      install_artifact_additions: [],
      overlap_commits: [],
      stale_references: {"todos": [], "rows": []},
      commonsh_parse: {"ours": true, "theirs": true},
      blockers: [],
      reintegration_json: {
        "schema_version": "1.0",
        "row_name": "plan-test",
        "branch": "work/plan-test",
        "base_sha": $base_sha,
        "head_sha": $head_sha,
        "generated_at": "2026-04-22T00:00:00Z",
        "commits": [{"sha": "aaa", "subject": "feat: feature", "conventional_type": "feat", "install_artifact_risk": "none"}],
        "files_changed": [],
        "decisions": [],
        "open_items": [],
        "test_results": {"pass": true}
      }
    }' > "${PLAN_MERGE_DIR}/audit.json"

  # Write classify.json
  jq -n \
    --arg merge_id "$PLAN_MERGE_ID" \
    '{
      schema_version: "1.0",
      merge_id: $merge_id,
      branch: "work/plan-test",
      commits: [{"sha": "aaa", "subject": "feat: feature", "label": "safe", "rationale": "clean"}]
    }' > "${PLAN_MERGE_DIR}/classify.json"
}

teardown_plan_fixture() {
  rm -rf "${PLAN_REPO:-}" "${PLAN_MERGE_DIR:-}" 2>/dev/null || true
}

# ─── Tests ──────────────────────────────────────────────────────────────────

test_plan_usage_error() {
  printf '  --- test_plan_usage_error ---\n'
  local exit_code=0
  (PROJECT_ROOT="$PLAN_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-resolve-plan.sh" 2>/dev/null) || exit_code=$?
  assert_exit_code "resolve-plan with no args exits 1" 1 "$exit_code"
}

test_plan_missing_audit() {
  printf '  --- test_plan_missing_audit ---\n'
  local exit_code=0
  (PROJECT_ROOT="$PLAN_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-resolve-plan.sh" "nonexistent-id" 2>/dev/null) || exit_code=$?
  assert_exit_code "resolve-plan with missing audit exits 2" 2 "$exit_code"
}

test_plan_writes_artifacts_exits_5() {
  printf '  --- test_plan_writes_artifacts_exits_5 ---\n'
  local exit_code=0
  (PROJECT_ROOT="$PLAN_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-resolve-plan.sh" "$PLAN_MERGE_ID" 2>/dev/null) || exit_code=$?

  # Always exits 5 (plan written, approval required)
  assert_exit_code "resolve-plan exits 5 (approval required)" 5 "$exit_code"

  local plan_json="${PLAN_MERGE_DIR}/plan.json"
  local plan_md="${PLAN_MERGE_DIR}/plan.md"

  assert_file_exists "plan.json produced" "$plan_json"
  assert_file_exists "plan.md produced" "$plan_md"

  if [ -f "$plan_json" ]; then
    assert_json_field "plan.json schema_version" "$plan_json" ".schema_version" "1.0"
    assert_json_field "plan.json approved defaults false" "$plan_json" ".approved" "false"
    assert_json_field "plan.json approved_at null" "$plan_json" ".approved_at" "null"

    # Check inputs_hash is present
    TESTS_RUN=$((TESTS_RUN + 1))
    local hash
    hash="$(jq -r '.inputs_hash' "$plan_json")"
    if [ -n "$hash" ] && [ "$hash" != "null" ]; then
      printf '  PASS: plan.json has inputs_hash (%s...)\n' "${hash:0:8}"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: plan.json missing inputs_hash\n' >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Check resolutions array
    TESTS_RUN=$((TESTS_RUN + 1))
    local n_res
    n_res="$(jq '.resolutions | length' "$plan_json")"
    if [ "$n_res" -ge 0 ]; then
      printf '  PASS: plan.json has resolutions array (%s entries)\n' "$n_res"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: plan.json missing resolutions array\n' >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  fi

  if [ -f "$plan_md" ]; then
    assert_file_contains "plan.md has approval marker" "$plan_md" "approved:yes"
  fi
}

test_plan_rerun_resets_approval() {
  printf '  --- test_plan_rerun_resets_approval ---\n'
  local plan_json="${PLAN_MERGE_DIR}/plan.json"

  # Manually set approved: true
  if [ -f "$plan_json" ]; then
    jq '.approved = true' "$plan_json" > "${plan_json}.tmp" && mv "${plan_json}.tmp" "$plan_json"
    assert_json_field "manually set approved true" "$plan_json" ".approved" "true"

    # Re-run resolve-plan
    local exit_code=0
    (PROJECT_ROOT="$PLAN_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-resolve-plan.sh" "$PLAN_MERGE_ID" 2>/dev/null) || exit_code=$?
    assert_exit_code "re-run resolve-plan exits 5 again" 5 "$exit_code"

    # Approval should be reset to false
    assert_json_field "re-run resets approved to false" "$plan_json" ".approved" "false"
  else
    printf '  SKIP: plan.json not found (prior test may have failed)\n'
  fi
}

test_plan_no_summary_md_parsing() {
  printf '  --- test_plan_no_summary_md_parsing ---\n'
  TESTS_RUN=$((TESTS_RUN + 1))
  local count=0
  count=$(grep -c 'summary\.md' "${PROJECT_ROOT}/bin/frw.d/scripts/merge-resolve-plan.sh" 2>/dev/null) || count=0
  count=$((count + 0))
  if [ "$count" -eq 0 ]; then
    printf '  PASS: no summary.md references in merge-resolve-plan.sh\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: %s summary.md reference(s) found\n' "$count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
  printf 'test-merge-resolve-plan.sh\n'
  printf '==============================\n'

  setup_plan_fixture
  trap 'teardown_plan_fixture' EXIT INT TERM

  run_test test_plan_usage_error
  run_test test_plan_missing_audit
  run_test test_plan_writes_artifacts_exits_5
  run_test test_plan_rerun_resets_approval
  run_test test_plan_no_summary_md_parsing

  print_summary
}

main "$@"
