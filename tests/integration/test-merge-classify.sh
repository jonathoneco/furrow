#!/bin/bash
# test-merge-classify.sh — Unit tests for merge-classify.sh (Phase 2) [AC-3]

set -eu
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${TESTS_DIR}/helpers.sh"

POLICY_PATH="${PROJECT_ROOT}/schemas/merge-policy.yaml"

# ─── Fixture: synthetic audit.json ──────────────────────────────────────────

setup_classify_fixture() {
  CLASSIFY_REPO="$(mktemp -d)"
  export CLASSIFY_REPO

  (
    cd "$CLASSIFY_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    mkdir -p bin/frw.d/lib
    printf '#!/bin/sh\n# common.sh\n' > bin/frw.d/lib/common.sh
    printf '#!/bin/sh\n# alm\n' > bin/alm
    echo 'main content' > README.md
    git add -A
    git commit -q -m "initial"

    git checkout -q -b work/test-classify

    # Safe commit
    echo "# feature" > feature.txt
    git add feature.txt
    git commit -q -m "feat: add feature"

    # Destructive commit (install artifact)
    cp bin/alm bin/alm.bak
    git add bin/alm.bak
    git commit -q -m "chore: install artifact"
  )

  # Build a synthetic merge-state with audit.json
  # State dir uses FURROW_ROOT's basename (scripts compute FURROW_ROOT from script location)
  CLASSIFY_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/furrow/$(basename "$PROJECT_ROOT")/merge-state"
  CLASSIFY_MERGE_ID="test-$(date +%s)"
  CLASSIFY_MERGE_DIR="${CLASSIFY_STATE_DIR}/${CLASSIFY_MERGE_ID}"
  mkdir -p "${CLASSIFY_MERGE_DIR}/awaiting"
  export CLASSIFY_STATE_DIR CLASSIFY_MERGE_ID CLASSIFY_MERGE_DIR

  # Get SHAs
  local base_sha head_sha
  base_sha="$(git -C "$CLASSIFY_REPO" rev-parse main 2>/dev/null || git -C "$CLASSIFY_REPO" rev-parse HEAD~2)"
  head_sha="$(git -C "$CLASSIFY_REPO" rev-parse HEAD)"

  # Write minimal audit.json
  jq -n \
    --arg merge_id "$CLASSIFY_MERGE_ID" \
    --arg branch "work/test-classify" \
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
      protected_touches: [],
      install_artifact_additions: ["bin/alm.bak"],
      overlap_commits: [],
      stale_references: {"todos": [], "rows": []},
      commonsh_parse: {"ours": true, "theirs": true},
      blockers: [],
      reintegration_json: {
        "schema_version": "1.0",
        "row_name": "test-classify",
        "branch": "work/test-classify",
        "base_sha": $base_sha,
        "head_sha": $head_sha,
        "generated_at": "2026-04-22T00:00:00Z",
        "commits": [
          {"sha": "aaa", "subject": "feat: add feature", "conventional_type": "feat", "install_artifact_risk": "none"},
          {"sha": "bbb", "subject": "chore: install artifact", "conventional_type": "chore", "install_artifact_risk": "high"}
        ],
        "files_changed": [],
        "decisions": [],
        "open_items": [],
        "test_results": {"pass": true}
      }
    }' > "${CLASSIFY_MERGE_DIR}/audit.json"
}

teardown_classify_fixture() {
  rm -rf "${CLASSIFY_REPO:-}" "${CLASSIFY_MERGE_DIR:-}" 2>/dev/null || true
}

# ─── Tests ──────────────────────────────────────────────────────────────────

test_classify_usage_error() {
  printf '  --- test_classify_usage_error ---\n'
  local exit_code=0
  (PROJECT_ROOT="$CLASSIFY_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-classify.sh" 2>/dev/null) || exit_code=$?
  assert_exit_code "classify with no args exits 1" 1 "$exit_code"
}

test_classify_missing_audit() {
  printf '  --- test_classify_missing_audit ---\n'
  local exit_code=0
  (PROJECT_ROOT="$CLASSIFY_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-classify.sh" "nonexistent-id" 2>/dev/null) || exit_code=$?
  assert_exit_code "classify with missing audit.json exits 2" 2 "$exit_code"
}

test_classify_produces_artifacts() {
  printf '  --- test_classify_produces_artifacts ---\n'
  local exit_code=0
  (PROJECT_ROOT="$CLASSIFY_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-classify.sh" "$CLASSIFY_MERGE_ID" 2>/dev/null) || exit_code=$?

  # Should exit 4 because we have destructive commits (install artifact)
  assert_exit_code "classify with destructive commits exits 4" 4 "$exit_code"

  local classify_json="${CLASSIFY_MERGE_DIR}/classify.json"
  local classify_md="${CLASSIFY_MERGE_DIR}/classify.md"

  assert_file_exists "classify.json produced" "$classify_json"
  assert_file_exists "classify.md produced" "$classify_md"

  if [ -f "$classify_json" ]; then
    assert_json_field "classify.json schema_version" "$classify_json" ".schema_version" "1.0"
    assert_json_field "classify.json merge_id" "$classify_json" ".merge_id" "$CLASSIFY_MERGE_ID"

    local n_commits
    n_commits="$(jq '.commits | length' "$classify_json")"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$n_commits" -gt 0 ]; then
      printf '  PASS: classify.json has %s commit(s)\n' "$n_commits"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: classify.json has no commits\n' >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # All commits should have a valid label
    local invalid_labels
    invalid_labels="$(jq '[.commits[] | select(.label | IN("safe","redundant-with-main","destructive","mixed") | not)] | length' "$classify_json")"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$invalid_labels" -eq 0 ]; then
      printf '  PASS: all commits have valid labels\n'
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: %s commits have invalid labels\n' "$invalid_labels" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  fi

  if [ -f "$classify_md" ]; then
    # Check markdown has table columns
    TESTS_RUN=$((TESTS_RUN + 1))
    if grep -q '| SHA' "$classify_md" || grep -q '| sha' "$classify_md" || grep -q '|---' "$classify_md"; then
      printf '  PASS: classify.md has table structure\n'
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: classify.md missing table structure\n' >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  fi
}

test_classify_no_summary_md_parsing() {
  printf '  --- test_classify_no_summary_md_parsing ---\n'
  TESTS_RUN=$((TESTS_RUN + 1))
  local count=0
  count=$(grep -c 'summary\.md' "${PROJECT_ROOT}/bin/frw.d/scripts/merge-classify.sh" 2>/dev/null) || count=0
  count=$((count + 0))
  if [ "$count" -eq 0 ]; then
    printf '  PASS: no summary.md references in merge-classify.sh\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: %s summary.md reference(s) found\n' "$count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
  printf 'test-merge-classify.sh\n'
  printf '==============================\n'

  setup_classify_fixture
  trap 'teardown_classify_fixture' EXIT INT TERM

  run_test test_classify_usage_error
  run_test test_classify_missing_audit
  run_test test_classify_produces_artifacts
  run_test test_classify_no_summary_md_parsing

  print_summary
}

main "$@"
