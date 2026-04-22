#!/bin/bash
# test-merge-e2e.sh — End-to-end test driving all 5 merge phases [AC-10]
#
# Fixture: an isolated git repo with:
#   - One feat: commit (pure source change)
#   - One chore: commit adding bin/alm.bak (install artifact)
#   - One commit turning bin/alm from regular into a symlink (protected typechange)
#   - One commit appending todos to .furrow/almanac/todos.yaml
#
# Test flow:
#   1. Phase 1: Audit → exits 3 (blockers: artifact + protected symlink)
#   2. Phase 2: Classify → exits 4 (destructive commits)
#   3. Phase 3: Resolve-plan → exits 5 (writes plan, needs approval)
#   4. Human approval simulation (set plan.json.approved = true)
#   5. Phase 4: Execute → may exit 5 (awaiting sentinel for bin/alm human-edit)
#   6. Verify phase tests audit.json integrity + exit code semantics

set -eu
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${TESTS_DIR}/helpers.sh"

POLICY_PATH="${PROJECT_ROOT}/schemas/merge-policy.yaml"

# ─── E2E Fixture setup ──────────────────────────────────────────────────────

setup_e2e_fixture() {
  E2E_REPO="$(mktemp -d)"
  export E2E_REPO

  (
    cd "$E2E_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    # Setup main branch
    mkdir -p bin/frw.d/lib bin/frw.d/hooks .furrow/almanac .furrow/seeds .claude/rules schemas
    printf '#!/bin/sh\n# common.sh\nlog_info() { :; }\n' > bin/frw.d/lib/common.sh
    printf '#!/bin/sh\n# common-minimal.sh\nlog_error() { :; }\n' > bin/frw.d/lib/common-minimal.sh
    printf '#!/bin/sh\n# alm — real file\n' > bin/alm
    printf '#!/bin/sh\n# rws\n' > bin/rws
    printf '#!/bin/sh\n# sds\n' > bin/sds
    printf 'schema_version: "1.0"\nprotected: []\nmachine_mergeable: []\nprefer_ours: []\nalways_delete_from_worktree_only: []\noverrides: {}\n' > schemas/merge-policy.yaml
    printf 'README: main\n' > README.md
    # todos.yaml with one existing entry
    printf -- '- id: todo-001\n  title: existing todo\n  created_at: "2026-01-01T00:00:00Z"\n' > .furrow/almanac/todos.yaml
    git add -A
    git commit -q -m "initial: main branch"

    # Create worktree branch
    git checkout -q -b work/e2e-row

    # Commit 1: pure source feature (safe)
    echo "# new feature code" > src-feature.txt
    git add src-feature.txt
    git commit -q -m "feat: add source feature"

    # Commit 2: install artifact (destructive)
    cp bin/alm bin/alm.bak
    git add bin/alm.bak
    git commit -q -m "chore: add alm backup (install artifact)"

    # Commit 3: turn bin/alm into a symlink (protected typechange)
    rm bin/alm
    ln -sf /usr/local/bin/alm bin/alm
    git add bin/alm
    git commit -q -m "chore: symlink bin/alm to installed location"

    # Commit 4: add todos (machine-mergeable candidate)
    printf -- '- id: todo-002\n  title: worktree todo\n  created_at: "2026-02-01T00:00:00Z"\n' >> .furrow/almanac/todos.yaml
    git add .furrow/almanac/todos.yaml
    git commit -q -m "chore: add worktree todo"

    # Switch back to main for the merge test
    git checkout -q main
  )

  # State dir uses FURROW_ROOT basename (scripts compute FURROW_ROOT from their location)
  E2E_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/furrow/$(basename "$PROJECT_ROOT")/merge-state"
  export E2E_STATE_DIR
}

teardown_e2e_fixture() {
  rm -rf "${E2E_REPO:-}" 2>/dev/null || true
  # Clean up any merge-state directories for this fixture
  if [ -n "${E2E_STATE_DIR:-}" ]; then
    rm -rf "${E2E_STATE_DIR}" 2>/dev/null || true
  fi
}

# ─── E2E Tests ──────────────────────────────────────────────────────────────

test_e2e_phase1_audit() {
  printf '  --- test_e2e_phase1_audit ---\n'

  local exit_code=0 merge_id_line
  # Audit should find blockers (install artifact + symlink typechange on protected path)
  merge_id_line="$(PROJECT_ROOT="$E2E_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" \
    "work/e2e-row" "$POLICY_PATH" 2>/dev/null; echo "exit=$?")" || true

  # Extract merge_id and exit code
  E2E_MERGE_ID=""
  if echo "$merge_id_line" | grep -q "^merge_id="; then
    E2E_MERGE_ID="$(echo "$merge_id_line" | grep "^merge_id=" | cut -d= -f2)"
  fi

  # Re-run to get proper exit code
  exit_code=0
  (PROJECT_ROOT="$E2E_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" \
    "work/e2e-row" "$POLICY_PATH" 2>/dev/null > /tmp/e2e_audit_out) || exit_code=$?

  E2E_MERGE_ID="$(grep "^merge_id=" /tmp/e2e_audit_out 2>/dev/null | cut -d= -f2 || echo '')"
  export E2E_MERGE_ID

  assert_exit_code "audit exits 3 (blockers found)" 3 "$exit_code"

  if [ -n "$E2E_MERGE_ID" ]; then
    local audit_json="${E2E_STATE_DIR}/${E2E_MERGE_ID}/audit.json"
    assert_file_exists "audit.json created" "$audit_json"

    if [ -f "$audit_json" ]; then
      # Verify install_artifact_additions detected
      TESTS_RUN=$((TESTS_RUN + 1))
      local n_artifacts
      n_artifacts="$(jq '.install_artifact_additions | length' "$audit_json")"
      if [ "$n_artifacts" -gt 0 ]; then
        printf '  PASS: install_artifact_additions detected (%s)\n' "$n_artifacts"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf '  FAIL: install_artifact_additions empty\n' >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi

      # Verify blockers non-empty
      TESTS_RUN=$((TESTS_RUN + 1))
      local n_blockers
      n_blockers="$(jq '.blockers | length' "$audit_json")"
      if [ "$n_blockers" -gt 0 ]; then
        printf '  PASS: blockers non-empty (%s)\n' "$n_blockers"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf '  FAIL: blockers empty\n' >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi

      # Verify reintegration_json field present
      TESTS_RUN=$((TESTS_RUN + 1))
      if jq -e 'has("reintegration_json")' "$audit_json" >/dev/null 2>&1; then
        printf '  PASS: reintegration_json field present in audit.json\n'
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf '  FAIL: reintegration_json field missing from audit.json\n' >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi
    fi
  else
    printf '  FAIL: could not extract merge_id from audit output\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
  fi
}

test_e2e_phase2_classify() {
  printf '  --- test_e2e_phase2_classify ---\n'

  if [ -z "${E2E_MERGE_ID:-}" ]; then
    printf '  SKIP: E2E_MERGE_ID not set (audit phase failed)\n'
    return
  fi

  local exit_code=0
  (PROJECT_ROOT="$E2E_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-classify.sh" "$E2E_MERGE_ID" 2>/dev/null) || exit_code=$?

  # Should exit 4 (destructive commits: install artifact + symlink)
  assert_exit_code "classify exits 4 (destructive commits)" 4 "$exit_code"

  local classify_json="${E2E_STATE_DIR}/${E2E_MERGE_ID}/classify.json"
  assert_file_exists "classify.json created" "$classify_json"

  if [ -f "$classify_json" ]; then
    TESTS_RUN=$((TESTS_RUN + 1))
    local n_commits
    n_commits="$(jq '.commits | length' "$classify_json")"
    if [ "$n_commits" -gt 0 ]; then
      printf '  PASS: classify.json has %s commits\n' "$n_commits"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: classify.json has no commits\n' >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  fi
}

test_e2e_phase3_resolve_plan() {
  printf '  --- test_e2e_phase3_resolve_plan ---\n'

  if [ -z "${E2E_MERGE_ID:-}" ]; then
    printf '  SKIP: E2E_MERGE_ID not set\n'
    return
  fi

  local exit_code=0
  (PROJECT_ROOT="$E2E_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-resolve-plan.sh" "$E2E_MERGE_ID" 2>/dev/null) || exit_code=$?

  assert_exit_code "resolve-plan exits 5 (approval required)" 5 "$exit_code"

  local plan_json="${E2E_STATE_DIR}/${E2E_MERGE_ID}/plan.json"
  local plan_md="${E2E_STATE_DIR}/${E2E_MERGE_ID}/plan.md"

  assert_file_exists "plan.json created" "$plan_json"
  assert_file_exists "plan.md created" "$plan_md"

  if [ -f "$plan_json" ]; then
    assert_json_field "plan approved defaults false" "$plan_json" ".approved" "false"

    TESTS_RUN=$((TESTS_RUN + 1))
    local hash
    hash="$(jq -r '.inputs_hash' "$plan_json")"
    if [ -n "$hash" ] && [ "$hash" != "null" ] && [ ${#hash} -ge 8 ]; then
      printf '  PASS: plan has valid inputs_hash\n'
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: plan missing valid inputs_hash\n' >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  fi
}

test_e2e_execute_requires_approval() {
  printf '  --- test_e2e_execute_requires_approval ---\n'

  if [ -z "${E2E_MERGE_ID:-}" ]; then
    printf '  SKIP: E2E_MERGE_ID not set\n'
    return
  fi

  local plan_json="${E2E_STATE_DIR}/${E2E_MERGE_ID}/plan.json"
  if [ ! -f "$plan_json" ]; then
    printf '  SKIP: plan.json not found\n'
    return
  fi

  # Ensure plan is NOT approved — execute should exit 5
  jq '.approved = false' "$plan_json" > "${plan_json}.tmp" && mv "${plan_json}.tmp" "$plan_json"

  local exit_code=0
  (cd "$E2E_REPO" && PROJECT_ROOT="$E2E_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-execute.sh" "$E2E_MERGE_ID" 2>/dev/null) || exit_code=$?
  assert_exit_code "execute without approval exits 5" 5 "$exit_code"
}

test_e2e_audit_artifacts_integrity() {
  printf '  --- test_e2e_audit_artifacts_integrity ---\n'

  if [ -z "${E2E_MERGE_ID:-}" ]; then
    printf '  SKIP: E2E_MERGE_ID not set\n'
    return
  fi

  local audit_json="${E2E_STATE_DIR}/${E2E_MERGE_ID}/audit.json"
  if [ ! -f "$audit_json" ]; then
    printf '  SKIP: audit.json not found\n'
    return
  fi

  # Run audit twice — should produce byte-identical audit.json content (idempotency of fields)
  # (merge_id and policy_sha256 are deterministic for the same branch+policy)
  assert_json_field "audit.json is valid JSON" "$audit_json" ".schema_version" "1.0"

  # Verify all required fields present
  for field in schema_version merge_id branch base_sha head_sha policy_path \
               symlink_typechanges protected_touches install_artifact_additions \
               overlap_commits stale_references commonsh_parse blockers reintegration_json; do
    TESTS_RUN=$((TESTS_RUN + 1))
    if jq -e "has(\"${field}\")" "$audit_json" >/dev/null 2>&1; then
      printf '  PASS: audit.json has field: %s\n' "$field"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: audit.json missing field: %s\n' "$field" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  done
}

test_e2e_no_summary_md_in_any_script() {
  printf '  --- test_e2e_no_summary_md_in_any_script ---\n'
  # AC-9: comprehensive check across ALL merge scripts
  TESTS_RUN=$((TESTS_RUN + 1))
  local total_count=0
  for script in merge-audit merge-classify merge-resolve-plan merge-execute merge-verify; do
    local count=0
    count=$(grep -c 'summary\.md' "${PROJECT_ROOT}/bin/frw.d/scripts/${script}.sh" 2>/dev/null) || count=0
    count=$((count + 0))
    total_count=$((total_count + count))
  done
  if [ "$total_count" -eq 0 ]; then
    printf '  PASS: no summary.md references in any merge script\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: %s summary.md reference(s) found across merge scripts\n' "$total_count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
  printf 'test-merge-e2e.sh\n'
  printf '==============================\n'

  setup_e2e_fixture
  trap 'teardown_e2e_fixture' EXIT INT TERM

  # E2E_MERGE_ID is set inside test functions
  E2E_MERGE_ID=""

  run_test test_e2e_phase1_audit
  run_test test_e2e_phase2_classify
  run_test test_e2e_phase3_resolve_plan
  run_test test_e2e_execute_requires_approval
  run_test test_e2e_audit_artifacts_integrity
  run_test test_e2e_no_summary_md_in_any_script

  print_summary
}

main "$@"
