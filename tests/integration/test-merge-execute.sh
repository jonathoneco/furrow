#!/bin/bash
# test-merge-execute.sh — Unit tests for merge-execute.sh (Phase 4) [AC-6]

set -eu
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${TESTS_DIR}/helpers.sh"

POLICY_PATH="${PROJECT_ROOT}/schemas/merge-policy.yaml"

# ─── Fixture setup ──────────────────────────────────────────────────────────

# Creates a synthetic merge-state with approved plan for execute tests
setup_execute_state() {
  local merge_id="$1"
  local audit_json_path="$2"
  local classify_json_path="$3"
  local extra_approved="${4:-true}"  # default approved

  local state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/furrow/$(basename "$PROJECT_ROOT")/merge-state"
  local merge_dir="${state_dir}/${merge_id}"
  mkdir -p "${merge_dir}/awaiting"

  cp "$audit_json_path" "${merge_dir}/audit.json"
  cp "$classify_json_path" "${merge_dir}/classify.json"

  # Compute inputs_hash
  local combined
  combined="$(cat "${merge_dir}/audit.json" "${merge_dir}/classify.json" "$POLICY_PATH")"
  local inputs_hash
  inputs_hash="$(printf '%s' "$combined" | sha256sum | awk '{print $1}')"

  # Write plan.json with computed inputs_hash
  jq -n \
    --arg merge_id "$merge_id" \
    --arg inputs_hash "$inputs_hash" \
    --argjson approved "$extra_approved" \
    '{
      schema_version: "1.0",
      merge_id: $merge_id,
      inputs_hash: $inputs_hash,
      approved: $approved,
      approved_at: null,
      approved_by: null,
      resolutions: []
    }' > "${merge_dir}/plan.json"

  printf '%s\n' "$merge_dir"
}

setup_exec_fixture() {
  EXEC_REPO="$(mktemp -d)"
  export EXEC_REPO

  (
    cd "$EXEC_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    printf '#!/bin/sh\nlog_info() { :; }\n' > common.sh
    git add -A
    git commit -q -m "initial"
    git checkout -q -b work/exec-test
    echo "feature content" > feature.txt
    git add feature.txt
    git commit -q -m "feat: add feature"
  )

  EXEC_BASE_SHA="$(git -C "$EXEC_REPO" rev-parse HEAD~1)"
  EXEC_HEAD_SHA="$(git -C "$EXEC_REPO" rev-parse HEAD)"
  export EXEC_BASE_SHA EXEC_HEAD_SHA

  # Build minimal audit.json template
  # State dir uses PROJECT_ROOT's basename (scripts compute FURROW_ROOT from script location)
  EXEC_AUDIT_TEMPLATE="$(mktemp)"
  jq -n \
    --arg base_sha "$EXEC_BASE_SHA" \
    --arg head_sha "$EXEC_HEAD_SHA" \
    --arg policy_path "$POLICY_PATH" \
    '{
      schema_version: "1.0",
      merge_id: "placeholder",
      branch: "work/exec-test",
      base_sha: $base_sha,
      head_sha: $head_sha,
      policy_path: $policy_path,
      policy_sha256: "abc",
      symlink_typechanges: [],
      protected_touches: [],
      install_artifact_additions: [],
      overlap_commits: [],
      stale_references: {"todos":[], "rows":[]},
      commonsh_parse: {"ours":true,"theirs":true},
      blockers: [],
      reintegration_json: {"schema_version":"1.0","row_name":"exec-test","branch":"work/exec-test","base_sha":"abc","head_sha":"def","generated_at":"2026-01-01T00:00:00Z","commits":[],"files_changed":[],"decisions":[],"open_items":[],"test_results":{"pass":true}}
    }' > "$EXEC_AUDIT_TEMPLATE"

  EXEC_CLASSIFY_TEMPLATE="$(mktemp)"
  jq -n '{schema_version:"1.0",merge_id:"placeholder",branch:"work/exec-test",commits:[]}' > "$EXEC_CLASSIFY_TEMPLATE"

  export EXEC_AUDIT_TEMPLATE EXEC_CLASSIFY_TEMPLATE
}

teardown_exec_fixture() {
  rm -rf "${EXEC_REPO:-}" "${EXEC_AUDIT_TEMPLATE:-}" "${EXEC_CLASSIFY_TEMPLATE:-}" 2>/dev/null || true
}

# ─── Tests ──────────────────────────────────────────────────────────────────

test_execute_usage_error() {
  printf '  --- test_execute_usage_error ---\n'
  local exit_code=0
  (PROJECT_ROOT="$EXEC_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-execute.sh" 2>/dev/null) || exit_code=$?
  assert_exit_code "execute with no args exits 1" 1 "$exit_code"
}

test_execute_missing_plan() {
  printf '  --- test_execute_missing_plan ---\n'
  local exit_code=0
  (PROJECT_ROOT="$EXEC_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-execute.sh" "nonexistent-id" 2>/dev/null) || exit_code=$?
  assert_exit_code "execute with missing plan exits 5" 5 "$exit_code"
}

test_execute_not_approved_exits_5() {
  printf '  --- test_execute_not_approved_exits_5 ---\n'
  local merge_id="exec-noapp-$(date +%s)"

  # Set up state with approved: false
  local merge_dir
  merge_dir="$(setup_execute_state "$merge_id" "$EXEC_AUDIT_TEMPLATE" "$EXEC_CLASSIFY_TEMPLATE" "false")"

  local exit_code=0
  (PROJECT_ROOT="$EXEC_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-execute.sh" "$merge_id" 2>/dev/null) || exit_code=$?
  assert_exit_code "execute with unapproved plan exits 5" 5 "$exit_code"

  rm -rf "$merge_dir"
}

test_execute_hash_mismatch_exits_5() {
  printf '  --- test_execute_hash_mismatch_exits_5 ---\n'
  local merge_id="exec-hashmm-$(date +%s)"
  local state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/furrow/$(basename "$PROJECT_ROOT")/merge-state"
  local merge_dir="${state_dir}/${merge_id}"
  mkdir -p "${merge_dir}/awaiting"

  cp "$EXEC_AUDIT_TEMPLATE" "${merge_dir}/audit.json"
  cp "$EXEC_CLASSIFY_TEMPLATE" "${merge_dir}/classify.json"

  # Write plan.json with WRONG inputs_hash
  jq -n \
    --arg merge_id "$merge_id" \
    '{
      schema_version: "1.0",
      merge_id: $merge_id,
      inputs_hash: "wrong_hash_value_that_will_not_match",
      approved: true,
      approved_at: null,
      approved_by: null,
      resolutions: []
    }' > "${merge_dir}/plan.json"

  local exit_code=0
  (PROJECT_ROOT="$EXEC_REPO" bash "${PROJECT_ROOT}/bin/frw.d/scripts/merge-execute.sh" "$merge_id" 2>/dev/null) || exit_code=$?
  assert_exit_code "execute with hash mismatch exits 5" 5 "$exit_code"

  rm -rf "$merge_dir"
}

test_execute_no_summary_md_parsing() {
  printf '  --- test_execute_no_summary_md_parsing ---\n'
  TESTS_RUN=$((TESTS_RUN + 1))
  local count=0
  count=$(grep -c 'summary\.md' "${PROJECT_ROOT}/bin/frw.d/scripts/merge-execute.sh" 2>/dev/null) || count=0
  count=$((count + 0))
  if [ "$count" -eq 0 ]; then
    printf '  PASS: no summary.md references in merge-execute.sh\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: %s summary.md reference(s) found\n' "$count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
  printf 'test-merge-execute.sh\n'
  printf '==============================\n'

  setup_exec_fixture
  trap 'teardown_exec_fixture' EXIT INT TERM

  run_test test_execute_usage_error
  run_test test_execute_missing_plan
  run_test test_execute_not_approved_exits_5
  run_test test_execute_hash_mismatch_exits_5
  run_test test_execute_no_summary_md_parsing

  print_summary
}

main "$@"
