#!/bin/bash
# test-merge-audit.sh — Unit tests for merge-audit.sh (Phase 1) [AC-2, AC-9]

set -eu
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${TESTS_DIR}/helpers.sh"

POLICY_PATH="${PROJECT_ROOT}/schemas/merge-policy.yaml"

# ─── Fixture setup ──────────────────────────────────────────────────────────

# Create a minimal git repo fixture with a contaminated worktree branch
setup_audit_fixture() {
  AUDIT_REPO="$(mktemp -d)"
  export AUDIT_REPO

  (
    cd "$AUDIT_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    # Create main branch with common.sh
    mkdir -p bin/frw.d/lib bin/frw.d/hooks schemas .furrow/seeds .furrow/almanac .claude/rules
    printf '#!/bin/sh\n# common.sh\nlog_info() { printf "[info] %s\n" "$1"; }\n' > bin/frw.d/lib/common.sh
    printf '#!/bin/sh\n# common-minimal.sh\nlog_error() { printf "[error] %s\n" "$1"; }\n' > bin/frw.d/lib/common-minimal.sh
    printf '#!/bin/sh\n# alm\n' > bin/alm
    printf '#!/bin/sh\n# rws\n' > bin/rws
    printf '#!/bin/sh\n# sds\n' > bin/sds
    chmod +x bin/alm bin/rws bin/sds
    echo '[]' > .furrow/seeds/seeds.jsonl
    printf '%s\n' '---' '[]...' > .furrow/almanac/todos.yaml
    git add -A
    git commit -q -m "initial: main branch setup"

    # Create a contaminated feature branch
    git checkout -q -b work/test-row

    # Add install artifact (contamination)
    cp bin/alm bin/alm.bak
    git add bin/alm.bak
    git commit -q -m "chore: add alm backup"

    # Add a feature commit (clean)
    echo "# new feature" > some-feature.txt
    git add some-feature.txt
    git commit -q -m "feat: add feature"
  )
}

teardown_audit_fixture() {
  rm -rf "${AUDIT_REPO:-}"
}

# ─── Tests ──────────────────────────────────────────────────────────────────

test_audit_usage_error() {
  printf '  --- test_audit_usage_error ---\n'
  local exit_code=0
  (PROJECT_ROOT="$AUDIT_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" 2>/dev/null) || exit_code=$?
  assert_exit_code "audit with no args exits 1" 1 "$exit_code"
}

test_audit_missing_policy() {
  printf '  --- test_audit_missing_policy ---\n'
  local exit_code=0
  (PROJECT_ROOT="$AUDIT_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" "work/test-row" "/nonexistent/policy.yaml" 2>/dev/null) || exit_code=$?
  assert_exit_code "audit with missing policy exits 2" 2 "$exit_code"
}

test_audit_missing_branch() {
  printf '  --- test_audit_missing_branch ---\n'
  local exit_code=0
  (PROJECT_ROOT="$AUDIT_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" "nonexistent-branch" "$POLICY_PATH" 2>/dev/null) || exit_code=$?
  assert_exit_code "audit with missing branch exits 2" 2 "$exit_code"
}

test_audit_detects_install_artifacts() {
  printf '  --- test_audit_detects_install_artifacts ---\n'

  local merge_id exit_code=0 state_dir
  # State dir uses basename of FURROW_ROOT (the script's install location)
  # Since merge-audit.sh computes FURROW_ROOT from its own location, it will be PROJECT_ROOT
  state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/furrow/$(basename "$PROJECT_ROOT")/merge-state"

  # Run audit against contaminated branch
  local output
  output="$(PROJECT_ROOT="$AUDIT_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" "work/test-row" "$POLICY_PATH" 2>/dev/null)" || exit_code=$?

  # Should exit 3 (blockers found)
  assert_exit_code "audit of contaminated branch exits 3" 3 "$exit_code"

  # Extract merge_id from output
  if echo "$output" | grep -q "^merge_id="; then
    merge_id="$(echo "$output" | grep "^merge_id=" | cut -d= -f2)"
    local audit_json="${state_dir}/${merge_id}/audit.json"

    assert_file_exists "audit.json created" "$audit_json"

    if [ -f "$audit_json" ]; then
      # Check install_artifact_additions is non-empty
      local n_artifacts
      n_artifacts="$(jq '.install_artifact_additions | length' "$audit_json")"
      TESTS_RUN=$((TESTS_RUN + 1))
      if [ "$n_artifacts" -gt 0 ]; then
        printf '  PASS: install_artifact_additions is non-empty (%s)\n' "$n_artifacts"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf '  FAIL: install_artifact_additions is empty\n' >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi

      # Check blockers is non-empty
      local n_blockers
      n_blockers="$(jq '.blockers | length' "$audit_json")"
      TESTS_RUN=$((TESTS_RUN + 1))
      if [ "$n_blockers" -gt 0 ]; then
        printf '  PASS: blockers is non-empty (%s)\n' "$n_blockers"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf '  FAIL: blockers is empty\n' >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi

      # Check reintegration_json field exists
      local has_reint
      has_reint="$(jq 'has("reintegration_json")' "$audit_json")"
      TESTS_RUN=$((TESTS_RUN + 1))
      if [ "$has_reint" = "true" ]; then
        printf '  PASS: reintegration_json field present\n'
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf '  FAIL: reintegration_json field missing\n' >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi

      # Verify schema_version
      assert_json_field "audit.json schema_version is 1.0" "$audit_json" ".schema_version" "1.0"
    fi

    # Cleanup
    rm -rf "${state_dir}/${merge_id}" 2>/dev/null || true
  else
    printf '  FAIL: audit output missing merge_id=\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
  fi
}

test_audit_no_summary_md_parsing() {
  printf '  --- test_audit_no_summary_md_parsing ---\n'
  # AC-9: grep for any summary.md references in merge-audit.sh
  TESTS_RUN=$((TESTS_RUN + 1))
  local count=0
  count=$(grep -c 'summary\.md' "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" 2>/dev/null) || count=0
  count=$(( count + 0 ))
  if [ "$count" -eq 0 ]; then
    printf '  PASS: no summary.md references in merge-audit.sh\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: %s summary.md reference(s) found in merge-audit.sh\n' "$count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_audit_policy_validation() {
  printf '  --- test_audit_policy_validation ---\n'
  local tmp_bad_policy
  tmp_bad_policy="$(mktemp)"
  # Write a policy missing schema_version
  printf 'protected: []\nmachine_mergeable: []\nprefer_ours: []\nalways_delete_from_worktree_only: []\n' > "$tmp_bad_policy"

  local exit_code=0
  (PROJECT_ROOT="$AUDIT_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" "work/test-row" "$tmp_bad_policy" 2>/dev/null) || exit_code=$?
  rm -f "$tmp_bad_policy"
  assert_exit_code "audit with missing schema_version exits 2" 2 "$exit_code"
}

# ─── Stale-row detection tests (AC-2) ───────────────────────────────────────

setup_stale_row_fixture() {
  STALE_REPO="$(mktemp -d)"
  export STALE_REPO

  (
    cd "$STALE_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    mkdir -p bin/frw.d/lib bin/frw.d/hooks schemas .furrow/seeds .furrow/almanac .furrow/rows .claude/rules
    printf '#!/bin/sh\n# common.sh\nlog_info() { printf "[info] %s\n" "$1"; }\n' > bin/frw.d/lib/common.sh
    printf '#!/bin/sh\n# common-minimal.sh\nlog_error() { printf "[error] %s\n" "$1"; }\n' > bin/frw.d/lib/common-minimal.sh
    printf '#!/bin/sh\n# alm\n' > bin/alm
    printf '#!/bin/sh\n# rws\n' > bin/rws
    printf '#!/bin/sh\n# sds\n' > bin/sds
    chmod +x bin/alm bin/rws bin/sds
    printf '[]' > .furrow/seeds/seeds.jsonl
    printf '%s\n' '---' '[]...' > .furrow/almanac/todos.yaml

    # Create a live row (not archived)
    mkdir -p .furrow/rows/live-row
    printf '{"schema_version":"1.0","row_name":"live-row","step":"implement","archived_at":null}\n' > .furrow/rows/live-row/state.json

    git add -A
    git commit -q -m "initial: main branch setup"

    # Create a worktree branch that references a NON-EXISTENT row
    git checkout -q -b work/stale-test-row

    # Commit that touches a path under a nonexistent row
    mkdir -p .furrow/rows/nonexistent-row
    printf '{"schema_version":"1.0","row_name":"nonexistent-row","step":"review","archived_at":null}\n' > .furrow/rows/nonexistent-row/state.json
    git add .furrow/rows/nonexistent-row/state.json
    git commit -q -m "chore: update nonexistent-row state"

    # Now delete the row directory so it no longer exists on main (simulate a removed row)
    rm -rf .furrow/rows/nonexistent-row
    git add -A
    git commit -q -m "chore: remove nonexistent-row directory"

    # Switch back to main so the row is missing from the HEAD
    git checkout -q main
    # Ensure nonexistent-row is absent on main
    rm -rf .furrow/rows/nonexistent-row 2>/dev/null || true
  )
}

teardown_stale_row_fixture() {
  rm -rf "${STALE_REPO:-}"
}

test_audit_stale_rows_detects_missing_row() {
  printf '  --- test_audit_stale_rows_detects_missing_row ---\n'

  local stale_repo
  stale_repo="$(mktemp -d)"

  (
    cd "$stale_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    mkdir -p bin/frw.d/lib bin/frw.d/hooks schemas .furrow/seeds .furrow/almanac .furrow/rows .claude/rules
    printf '#!/bin/sh\nlog_info() { :; }\n' > bin/frw.d/lib/common.sh
    printf '#!/bin/sh\nlog_error() { :; }\n' > bin/frw.d/lib/common-minimal.sh
    printf '#!/bin/sh\n' > bin/alm
    printf '#!/bin/sh\n' > bin/rws
    printf '#!/bin/sh\n' > bin/sds
    printf '[]' > .furrow/seeds/seeds.jsonl
    printf '%s\n' '---' '[]...' > .furrow/almanac/todos.yaml
    git add -A
    git commit -q -m "initial: main"

    git checkout -q -b work/stale-row-probe

    # Commit touches .furrow/rows/removed-row/state.json
    mkdir -p .furrow/rows/removed-row
    printf '{"schema_version":"1.0","row_name":"removed-row","step":"implement","archived_at":null}\n' > .furrow/rows/removed-row/state.json
    git add .furrow/rows/removed-row/state.json
    git commit -q -m "feat: update removed-row state"

    git checkout -q main
    # removed-row does NOT exist on main (simulating a row that was deleted)
  )

  local state_dir merge_id exit_code=0
  state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/furrow/$(basename "$PROJECT_ROOT")/merge-state"

  local output
  output="$(PROJECT_ROOT="$stale_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" \
    "work/stale-row-probe" "$POLICY_PATH" 2>/dev/null)" || exit_code=$?

  merge_id="$(printf '%s\n' "$output" | grep "^merge_id=" | cut -d= -f2 || echo '')"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -n "$merge_id" ]; then
    printf '  PASS: audit ran and produced merge_id=%s\n' "$merge_id"
    TESTS_PASSED=$((TESTS_PASSED + 1))

    local audit_json="${state_dir}/${merge_id}/audit.json"
    if [ -f "$audit_json" ]; then
      local n_stale_rows
      n_stale_rows="$(jq '.stale_references.rows | length' "$audit_json" 2>/dev/null || echo 0)"
      TESTS_RUN=$((TESTS_RUN + 1))
      if [ "$n_stale_rows" -gt 0 ]; then
        printf '  PASS: stale_references.rows is non-empty (%s entry)\n' "$n_stale_rows"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf '  FAIL: stale_references.rows is empty (expected removed-row to be flagged)\n' >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi

      # Check the row_name field is "removed-row"
      local flagged_row
      flagged_row="$(jq -r '.stale_references.rows[0].row_name // ""' "$audit_json" 2>/dev/null || echo '')"
      TESTS_RUN=$((TESTS_RUN + 1))
      if [ "$flagged_row" = "removed-row" ]; then
        printf '  PASS: flagged row_name is "removed-row"\n'
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf '  FAIL: expected row_name="removed-row", got "%s"\n' "$flagged_row" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi

      rm -rf "${state_dir}/${merge_id}" 2>/dev/null || true
    fi
  else
    printf '  FAIL: audit did not produce merge_id (output: %s)\n' "$output" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  rm -rf "$stale_repo"
}

test_audit_stale_rows_live_row_stays_empty() {
  printf '  --- test_audit_stale_rows_live_row_stays_empty ---\n'

  local live_repo
  live_repo="$(mktemp -d)"

  (
    cd "$live_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    mkdir -p bin/frw.d/lib bin/frw.d/hooks schemas .furrow/seeds .furrow/almanac .furrow/rows .claude/rules
    printf '#!/bin/sh\nlog_info() { :; }\n' > bin/frw.d/lib/common.sh
    printf '#!/bin/sh\nlog_error() { :; }\n' > bin/frw.d/lib/common-minimal.sh
    printf '#!/bin/sh\n' > bin/alm
    printf '#!/bin/sh\n' > bin/rws
    printf '#!/bin/sh\n' > bin/sds
    printf '[]' > .furrow/seeds/seeds.jsonl
    printf '%s\n' '---' '[]...' > .furrow/almanac/todos.yaml

    # Create a LIVE row on main (not archived)
    mkdir -p .furrow/rows/live-row
    printf '{"schema_version":"1.0","row_name":"live-row","step":"implement","archived_at":null}\n' > .furrow/rows/live-row/state.json

    git add -A
    git commit -q -m "initial: main with live-row"

    git checkout -q -b work/live-row-probe

    # Commit touches the live row — should NOT be flagged
    printf '{"schema_version":"1.0","row_name":"live-row","step":"review","archived_at":null}\n' > .furrow/rows/live-row/state.json
    git add .furrow/rows/live-row/state.json
    git commit -q -m "chore: advance live-row to review"

    git checkout -q main
  )

  local state_dir merge_id exit_code=0
  state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/furrow/$(basename "$PROJECT_ROOT")/merge-state"

  local output
  output="$(PROJECT_ROOT="$live_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" \
    "work/live-row-probe" "$POLICY_PATH" 2>/dev/null)" || exit_code=$?

  merge_id="$(printf '%s\n' "$output" | grep "^merge_id=" | cut -d= -f2 || echo '')"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -n "$merge_id" ]; then
    printf '  PASS: audit ran and produced merge_id=%s\n' "$merge_id"
    TESTS_PASSED=$((TESTS_PASSED + 1))

    local audit_json="${state_dir}/${merge_id}/audit.json"
    if [ -f "$audit_json" ]; then
      local n_stale_rows
      n_stale_rows="$(jq '.stale_references.rows | length' "$audit_json" 2>/dev/null || echo 0)"
      TESTS_RUN=$((TESTS_RUN + 1))
      if [ "$n_stale_rows" -eq 0 ]; then
        printf '  PASS: stale_references.rows is empty (live row correctly not flagged)\n'
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf '  FAIL: stale_references.rows is non-empty (%s) for a live row\n' "$n_stale_rows" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi

      rm -rf "${state_dir}/${merge_id}" 2>/dev/null || true
    fi
  else
    printf '  FAIL: audit did not produce merge_id\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  rm -rf "$live_repo"
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
  printf 'test-merge-audit.sh\n'
  printf '==============================\n'

  setup_audit_fixture
  trap 'teardown_audit_fixture' EXIT INT TERM

  run_test test_audit_usage_error
  run_test test_audit_missing_policy
  run_test test_audit_missing_branch
  run_test test_audit_detects_install_artifacts
  run_test test_audit_no_summary_md_parsing
  run_test test_audit_policy_validation
  run_test test_audit_stale_rows_detects_missing_row
  run_test test_audit_stale_rows_live_row_stays_empty

  print_summary
}

main "$@"
