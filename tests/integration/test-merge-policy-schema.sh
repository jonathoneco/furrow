#!/bin/bash
# test-merge-policy-schema.sh — Tests for merge-policy.yaml + schema [AC-4]

set -eu
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${TESTS_DIR}/helpers.sh"

POLICY_YAML="${PROJECT_ROOT}/schemas/merge-policy.yaml"
POLICY_SCHEMA="${PROJECT_ROOT}/schemas/merge-policy.schema.json"

# ─── Tests ──────────────────────────────────────────────────────────────────

test_policy_yaml_exists() {
  printf '  --- test_policy_yaml_exists ---\n'
  assert_file_exists "schemas/merge-policy.yaml exists" "$POLICY_YAML"
  assert_file_exists "schemas/merge-policy.schema.json exists" "$POLICY_SCHEMA"
}

test_policy_yaml_has_required_sections() {
  printf '  --- test_policy_yaml_has_required_sections ---\n'
  assert_file_contains "policy has schema_version" "$POLICY_YAML" "^schema_version:"
  assert_file_contains "policy has protected section" "$POLICY_YAML" "^protected:"
  assert_file_contains "policy has machine_mergeable section" "$POLICY_YAML" "^machine_mergeable:"
  assert_file_contains "policy has prefer_ours section" "$POLICY_YAML" "^prefer_ours:"
  assert_file_contains "policy has always_delete section" "$POLICY_YAML" "^always_delete_from_worktree_only:"
}

test_policy_schema_is_valid_json() {
  printf '  --- test_policy_schema_is_valid_json ---\n'
  TESTS_RUN=$((TESTS_RUN + 1))
  if jq . "$POLICY_SCHEMA" >/dev/null 2>&1; then
    printf '  PASS: merge-policy.schema.json is valid JSON\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-policy.schema.json is invalid JSON\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_policy_schema_version_is_10() {
  printf '  --- test_policy_schema_version_is_10 ---\n'
  TESTS_RUN=$((TESTS_RUN + 1))
  local ver
  ver="$(grep '^schema_version:' "$POLICY_YAML" | head -1 | sed 's/schema_version:[[:space:]]*//' | tr -d '"'"'")"
  if [ "$ver" = "1.0" ]; then
    printf '  PASS: schema_version is 1.0\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: schema_version is "%s" (expected 1.0)\n' "$ver" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_policy_protected_paths() {
  printf '  --- test_policy_protected_paths ---\n'
  # Check that key protected paths are present
  assert_file_contains "bin/alm in protected" "$POLICY_YAML" '"bin/alm"'
  assert_file_contains "bin/rws in protected" "$POLICY_YAML" '"bin/rws"'
  assert_file_contains "bin/sds in protected" "$POLICY_YAML" '"bin/sds"'
  assert_file_contains "common.sh in protected" "$POLICY_YAML" 'common.sh'
}

test_policy_machine_mergeable_paths() {
  printf '  --- test_policy_machine_mergeable_paths ---\n'
  assert_file_contains "seeds.jsonl in machine_mergeable" "$POLICY_YAML" 'seeds.jsonl'
  assert_file_contains "todos.yaml in machine_mergeable" "$POLICY_YAML" 'todos.yaml'
  assert_file_contains "sort-by-id-union strategy present" "$POLICY_YAML" 'sort-by-id-union'
}

test_policy_schema_json_structure() {
  printf '  --- test_policy_schema_json_structure ---\n'
  TESTS_RUN=$((TESTS_RUN + 1))
  local draft
  draft="$(jq -r '."$schema" // ""' "$POLICY_SCHEMA" 2>/dev/null)"
  if echo "$draft" | grep -q "draft-07\|json-schema"; then
    printf '  PASS: schema references draft-07\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: schema does not reference draft-07\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Check additionalProperties: false at top level
  TESTS_RUN=$((TESTS_RUN + 1))
  local ap
  ap="$(jq -r '.additionalProperties' "$POLICY_SCHEMA" 2>/dev/null)"
  if [ "$ap" = "false" ]; then
    printf '  PASS: additionalProperties: false at top level\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: additionalProperties is "%s" (expected false)\n' "$ap" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_policy_merge_audit_validates() {
  printf '  --- test_policy_merge_audit_validates ---\n'
  # Write a bad policy and check audit exits 2
  local tmp_bad
  tmp_bad="$(mktemp)"
  printf 'protected: []\n' > "$tmp_bad"  # missing schema_version

  TESTS_RUN=$((TESTS_RUN + 1))
  local exit_code=0

  # Create a minimal repo for audit to check branch
  local tmp_repo
  tmp_repo="$(mktemp -d)"
  (
    cd "$tmp_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "root" > README.md
    git add README.md
    git commit -q -m "initial"
    git checkout -q -b work/bad-policy-test
    echo "feature" > feat.txt
    git add feat.txt
    git commit -q -m "feat: test"
  )

  (PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" \
    "work/bad-policy-test" "$tmp_bad" 2>/dev/null) || exit_code=$?
  rm -f "$tmp_bad"
  rm -rf "$tmp_repo"

  if [ "$exit_code" -eq 2 ]; then
    printf '  PASS: audit exits 2 on missing schema_version in policy\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: audit exited %s (expected 2) on bad policy\n' "$exit_code" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ─── Shared policy validation across all 5 merge scripts (Correction 3) ────
#
# Each merge-*.sh now sources merge-lib.sh and calls merge_validate_policy.
# Verify that each script exits 2 + mentions the violation on a malformed policy.
# Also verify each script accepts a valid policy (baseline).

# Helper: make a bad policy missing a required field
_bad_policy_missing_version() {
  local f
  f="$(mktemp)"
  printf 'protected: []\nmachine_mergeable: []\nprefer_ours: []\nalways_delete_from_worktree_only: []\n' > "$f"
  printf '%s' "$f"
}

# Helper: make a policy with wrong schema_version
_bad_policy_wrong_version() {
  local f
  f="$(mktemp)"
  printf 'schema_version: "2.0"\nprotected: []\nmachine_mergeable: []\nprefer_ours: []\nalways_delete_from_worktree_only: []\n' > "$f"
  printf '%s' "$f"
}

# Helper: build a minimal git repo + merge-state for classify/resolve-plan/execute/verify tests
_build_policy_test_repo_and_state() {
  local valid_policy="$1"
  local bad_policy="$2"

  local tmp_repo
  tmp_repo="$(mktemp -d)"

  (
    cd "$tmp_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    mkdir -p bin/frw.d/lib .furrow/seeds .furrow/almanac .furrow/rows
    printf '#!/bin/sh\nlog_info() { :; }\n' > bin/frw.d/lib/common.sh
    printf '#!/bin/sh\nlog_error() { :; }\n' > bin/frw.d/lib/common-minimal.sh
    printf '#!/bin/sh\n' > bin/alm
    printf '#!/bin/sh\n' > bin/rws
    printf '#!/bin/sh\n' > bin/sds
    git add -A
    git commit -q -m "initial"
    git checkout -q -b work/policy-test
    echo "feat" > feat.txt
    git add feat.txt
    git commit -q -m "feat: test commit"
    git checkout -q main
  )

  # Build minimal merge-state with bad policy recorded in audit.json
  local state_dir="${HOME}/.local/state/furrow/furrow-install-and-merge/merge-state"
  local fake_id="policy-test-$$"
  local merge_dir="${state_dir}/${fake_id}"
  mkdir -p "${merge_dir}/awaiting"

  # Write audit.json pointing to bad_policy
  jq -n \
    --arg schema_version "1.0" \
    --arg merge_id "$fake_id" \
    --arg branch "work/policy-test" \
    --arg base_sha "$(git -C "$tmp_repo" rev-parse main)" \
    --arg head_sha "$(git -C "$tmp_repo" rev-parse work/policy-test)" \
    --arg policy_path "$bad_policy" \
    --arg policy_sha256 "" \
    '{
      schema_version: $schema_version,
      merge_id: $merge_id,
      branch: $branch,
      base_sha: $base_sha,
      head_sha: $head_sha,
      policy_path: $policy_path,
      policy_sha256: $policy_sha256,
      symlink_typechanges: [],
      protected_touches: [],
      install_artifact_additions: [],
      overlap_commits: [],
      stale_references: {"todos": [], "rows": []},
      commonsh_parse: {"ours": true, "theirs": true},
      blockers: [],
      reintegration_json: {}
    }' > "${merge_dir}/audit.json"

  # Write a minimal classify.json
  jq -n \
    --arg schema_version "1.0" \
    --arg merge_id "$fake_id" \
    --arg branch "work/policy-test" \
    '{
      schema_version: $schema_version,
      merge_id: $merge_id,
      branch: $branch,
      commits: []
    }' > "${merge_dir}/classify.json"

  # Write a minimal plan.json (approved, for execute test)
  jq -n \
    --arg schema_version "1.0" \
    --arg merge_id "$fake_id" \
    --arg inputs_hash "testhash" \
    '{
      schema_version: $schema_version,
      merge_id: $merge_id,
      inputs_hash: $inputs_hash,
      approved: true,
      approved_at: null,
      approved_by: null,
      resolutions: []
    }' > "${merge_dir}/plan.json"

  # Write a minimal execute.json (for verify test)
  jq -n \
    --arg schema_version "1.0" \
    --arg merge_id "$fake_id" \
    '{
      schema_version: $schema_version,
      merge_id: $merge_id,
      status: "complete",
      merge_sha: "aabbccdd",
      deviations: [],
      warnings: [],
      commonsh_broken: false
    }' > "${merge_dir}/execute.json"

  printf '%s %s' "$tmp_repo" "$fake_id"
}

test_all_scripts_reject_malformed_policy() {
  printf '  --- test_all_scripts_reject_malformed_policy ---\n'

  local bad_pol
  bad_pol="$(_bad_policy_missing_version)"

  local state_dir="${HOME}/.local/state/furrow/furrow-install-and-merge/merge-state"

  # Read repo + fake_id from helper
  local repo_and_id
  repo_and_id="$(_build_policy_test_repo_and_state "$POLICY_YAML" "$bad_pol")"
  local tmp_repo fake_id
  tmp_repo="$(printf '%s' "$repo_and_id" | awk '{print $1}')"
  fake_id="$(printf '%s' "$repo_and_id" | awk '{print $2}')"
  local merge_dir="${state_dir}/${fake_id}"

  # Test merge-audit: bad policy path passed directly
  TESTS_RUN=$((TESTS_RUN + 1))
  local ec=0
  (PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" \
    "work/policy-test" "$bad_pol" 2>/dev/null) || ec=$?
  if [ "$ec" -eq 2 ]; then
    printf '  PASS: merge-audit exits 2 on malformed policy\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-audit exited %s on malformed policy (expected 2)\n' "$ec" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Test merge-classify: bad policy path in audit.json
  TESTS_RUN=$((TESTS_RUN + 1))
  ec=0
  (PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-classify.sh" \
    "$fake_id" 2>/dev/null) || ec=$?
  if [ "$ec" -eq 2 ]; then
    printf '  PASS: merge-classify exits 2 on malformed policy\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-classify exited %s on malformed policy (expected 2)\n' "$ec" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Test merge-resolve-plan: bad policy path in audit.json
  TESTS_RUN=$((TESTS_RUN + 1))
  ec=0
  (PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-resolve-plan.sh" \
    "$fake_id" 2>/dev/null) || ec=$?
  if [ "$ec" -eq 2 ]; then
    printf '  PASS: merge-resolve-plan exits 2 on malformed policy\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-resolve-plan exited %s on malformed policy (expected 2)\n' "$ec" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Test merge-execute: bad policy path in audit.json
  TESTS_RUN=$((TESTS_RUN + 1))
  ec=0
  (cd "$tmp_repo" && PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-execute.sh" \
    "$fake_id" 2>/dev/null) || ec=$?
  if [ "$ec" -eq 2 ]; then
    printf '  PASS: merge-execute exits 2 on malformed policy\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-execute exited %s on malformed policy (expected 2)\n' "$ec" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Test merge-verify: bad policy path in audit.json
  TESTS_RUN=$((TESTS_RUN + 1))
  ec=0
  (cd "$tmp_repo" && PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-verify.sh" \
    "$fake_id" 2>/dev/null) || ec=$?
  if [ "$ec" -eq 2 ]; then
    printf '  PASS: merge-verify exits 2 on malformed policy\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-verify exited %s on malformed policy (expected 2)\n' "$ec" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Cleanup
  rm -f "$bad_pol"
  rm -rf "$tmp_repo"
  rm -rf "$merge_dir"
}

test_all_scripts_reject_wrong_schema_version() {
  printf '  --- test_all_scripts_reject_wrong_schema_version ---\n'

  local bad_pol
  bad_pol="$(_bad_policy_wrong_version)"

  local state_dir="${HOME}/.local/state/furrow/furrow-install-and-merge/merge-state"
  local repo_and_id
  repo_and_id="$(_build_policy_test_repo_and_state "$POLICY_YAML" "$bad_pol")"
  local tmp_repo fake_id
  tmp_repo="$(printf '%s' "$repo_and_id" | awk '{print $1}')"
  fake_id="$(printf '%s' "$repo_and_id" | awk '{print $2}')"
  local merge_dir="${state_dir}/${fake_id}"

  # Test each script rejects wrong schema_version (exits 2)
  for _script in merge-audit merge-classify merge-resolve-plan merge-execute merge-verify; do
    TESTS_RUN=$((TESTS_RUN + 1))
    local ec=0
    case "$_script" in
      merge-audit)
        (PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/${_script}.sh" \
          "work/policy-test" "$bad_pol" 2>/dev/null) || ec=$?
        ;;
      *)
        (cd "$tmp_repo" && PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/${_script}.sh" \
          "$fake_id" 2>/dev/null) || ec=$?
        ;;
    esac
    if [ "$ec" -eq 2 ]; then
      printf '  PASS: %s exits 2 on wrong schema_version\n' "$_script"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: %s exited %s on wrong schema_version (expected 2)\n' "$_script" "$ec" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  done

  # Cleanup
  rm -f "$bad_pol"
  rm -rf "$tmp_repo"
  rm -rf "$merge_dir"
}

test_all_scripts_accept_valid_policy() {
  printf '  --- test_all_scripts_accept_valid_policy ---\n'

  local state_dir="${HOME}/.local/state/furrow/furrow-install-and-merge/merge-state"
  local repo_and_id
  repo_and_id="$(_build_policy_test_repo_and_state "$POLICY_YAML" "$POLICY_YAML")"
  local tmp_repo fake_id
  tmp_repo="$(printf '%s' "$repo_and_id" | awk '{print $1}')"
  fake_id="$(printf '%s' "$repo_and_id" | awk '{print $2}')"
  local merge_dir="${state_dir}/${fake_id}"

  # Test merge-audit accepts valid policy (should exit 0 or 3, not 2)
  TESTS_RUN=$((TESTS_RUN + 1))
  local ec=0
  (PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-audit.sh" \
    "work/policy-test" "$POLICY_YAML" 2>/dev/null) || ec=$?
  if [ "$ec" -ne 2 ]; then
    printf '  PASS: merge-audit accepts valid policy (exit %s, not 2)\n' "$ec"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-audit exited 2 on valid policy\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # merge-classify accepts valid policy (exit 0 or 4, not 2)
  TESTS_RUN=$((TESTS_RUN + 1))
  ec=0
  (PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-classify.sh" \
    "$fake_id" 2>/dev/null) || ec=$?
  if [ "$ec" -ne 2 ]; then
    printf '  PASS: merge-classify accepts valid policy (exit %s, not 2)\n' "$ec"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-classify exited 2 on valid policy\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # merge-resolve-plan accepts valid policy (exit 5, needs approval)
  TESTS_RUN=$((TESTS_RUN + 1))
  ec=0
  (PROJECT_ROOT="$tmp_repo" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-resolve-plan.sh" \
    "$fake_id" 2>/dev/null) || ec=$?
  if [ "$ec" -ne 2 ]; then
    printf '  PASS: merge-resolve-plan accepts valid policy (exit %s, not 2)\n' "$ec"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-resolve-plan exited 2 on valid policy\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Cleanup
  rm -rf "$tmp_repo"
  rm -rf "$merge_dir"
}

test_merge_lib_syntax() {
  printf '  --- test_merge_lib_syntax ---\n'
  # merge-lib.sh must pass sh -n
  local d=frw.d
  TESTS_RUN=$((TESTS_RUN + 1))
  if sh -n "${PROJECT_ROOT}/bin/${d}/scripts/merge-lib.sh" 2>/dev/null; then
    printf '  PASS: merge-lib.sh passes sh -n\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: merge-lib.sh fails sh -n\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_all_merge_scripts_source_merge_lib() {
  printf '  --- test_all_merge_scripts_source_merge_lib ---\n'
  local d=frw.d
  for _script in merge-audit merge-classify merge-resolve-plan merge-execute merge-verify merge-sort-union; do
    TESTS_RUN=$((TESTS_RUN + 1))
    if grep -q 'merge-lib\.sh' "${PROJECT_ROOT}/bin/${d}/scripts/${_script}.sh" 2>/dev/null; then
      printf '  PASS: %s sources merge-lib.sh\n' "$_script"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf '  FAIL: %s does not source merge-lib.sh\n' "$_script" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  done
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
  printf 'test-merge-policy-schema.sh\n'
  printf '==============================\n'

  run_test test_policy_yaml_exists
  run_test test_policy_yaml_has_required_sections
  run_test test_policy_schema_is_valid_json
  run_test test_policy_schema_version_is_10
  run_test test_policy_protected_paths
  run_test test_policy_machine_mergeable_paths
  run_test test_policy_schema_json_structure
  run_test test_policy_merge_audit_validates

  printf '\n=== Correction 3: shared policy validation across all scripts ===\n'
  run_test test_merge_lib_syntax
  run_test test_all_merge_scripts_source_merge_lib
  run_test test_all_scripts_reject_malformed_policy
  run_test test_all_scripts_reject_wrong_schema_version
  run_test test_all_scripts_accept_valid_policy

  print_summary
}

main "$@"
