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

  print_summary
}

main "$@"
