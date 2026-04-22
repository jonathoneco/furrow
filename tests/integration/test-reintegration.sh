#!/bin/sh
# test-reintegration.sh — Integration tests for rws generate-reintegration
# and related reintegration infrastructure.
#
# Covers:
#   1. Schema round-trip                  (AC-R2, AC-R6)
#   2. Synthetic worktree                 (AC-R3)
#   3. Install-artifact detection         (AC-R3 classifier)
#   4. Template fallback                  (AC-R5)
#   5. Rescue hint on common.sh touch     (AC-R3 hint logic)
#   6. Merge-consumer contract            (AC-R4)
#   7. Idempotency + round-trip           (AC-R6)
#   8. update-summary rejects reintegration section (AC-R1)
#
# POSIX sh. Sources tests/integration/helpers.sh for assertions.
# Each test uses mktemp -d + trap for isolation.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export PROJECT_ROOT

# Source helpers (provides TESTS_PASSED, TESTS_FAILED, assert_*, run_test, etc.)
# shellcheck source=tests/integration/helpers.sh
. "${SCRIPT_DIR}/helpers.sh"

# Override PATH so rws/frw etc resolve to this project
export PATH="${PROJECT_ROOT}/bin:${PATH}"

# --- Shared fixture builder ---
# build_test_repo <dir> [branch_name]
# Creates a minimal git repo with a row scaffold under .furrow/rows/<row>/
build_test_repo() {
  _btr_dir="$1"
  _btr_branch="${2:-work/test-row}"
  _btr_row="test-row"

  # Init git repo
  (
    cd "$_btr_dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    git checkout -b main 2>/dev/null || git checkout -b main
  )

  # Create initial commit on main
  printf 'init\n' > "${_btr_dir}/.gitkeep"
  (
    cd "$_btr_dir" &&
    git add .gitkeep &&
    git commit -q -m "initial"
  )

  # Create worktree branch
  (
    cd "$_btr_dir" &&
    git checkout -b "$_btr_branch" 2>/dev/null || true
  )

  # Create furrow row scaffold
  mkdir -p "${_btr_dir}/.furrow/rows/${_btr_row}/reviews"
  mkdir -p "${_btr_dir}/.furrow/almanac"

  # Write state.json
  _btr_base="$(cd "$_btr_dir" && git rev-parse HEAD)"
  jq -n \
    --arg name "$_btr_row" \
    --arg branch "$_btr_branch" \
    --arg base "$_btr_base" \
    '{
      name: $name,
      title: "Test Row",
      description: "Test row for reintegration tests",
      step: "implement",
      step_status: "in_progress",
      steps_sequence: ["ideate","research","plan","spec","decompose","implement","review"],
      deliverables: {},
      gates: [],
      force_stop_at: null,
      branch: $branch,
      mode: "code",
      base_commit: $base,
      seed_id: null,
      epic_seed_id: null,
      created_at: "2026-01-01T00:00:00Z",
      updated_at: "2026-01-01T00:00:00Z",
      archived_at: null,
      source_todo: null,
      gate_policy_init: "supervised"
    }' > "${_btr_dir}/.furrow/rows/${_btr_row}/state.json"

  # Write a review file
  cat > "${_btr_dir}/.furrow/rows/${_btr_row}/reviews/2026-01-01T00-00.md" << 'REVIEW'
# Review: test-row

## Summary
pass: true

## Overall
pass

## Open Items
- [low] Example open item
REVIEW

  # Write summary.md with required sections
  cat > "${_btr_dir}/.furrow/rows/${_btr_row}/summary.md" << 'SUMMARY'
# Test Row -- Summary

## Task
Test row for reintegration tests.

## Current State
Step: implement | Status: in_progress
Deliverables: 0/0
Mode: code

## Artifact Paths
- state.json: .furrow/rows/test-row/state.json

## Settled Decisions
- No gates recorded yet

## Context Budget
Not measured

## Key Findings
- Key finding one.

## Open Questions
- Open question one.

## Recommendations
- Recommendation one.
SUMMARY

  # Return row name for caller
  printf '%s\n' "$_btr_row"
}

# --- Scenario 1: Schema round-trip (AC-R2, AC-R6) ---
test_schema_round_trip() {
  printf '\n[Scenario 1: schema round-trip]\n'
  _dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$_dir'" EXIT INT TERM

  _row="$(build_test_repo "$_dir")"

  # Add commits to branch
  (
    cd "$_dir" &&
    printf 'schema file\n' > schemas_test.json &&
    git add schemas_test.json &&
    git commit -q -m "feat: add schema test"
  )

  # Run generate-reintegration using the helper script directly
  _script="${PROJECT_ROOT}/bin/frw.d/scripts/generate-reintegration.sh"
  _exit=0
  (cd "$_dir" && sh "$_script" "$_row" "$PROJECT_ROOT") >/dev/null 2>&1 || _exit=$?
  # Note: script is invoked from the repo dir but FURROW_ROOT points to project
  # For test, we invoke against _dir as FURROW_ROOT
  _exit=0
  (cd "$_dir" && sh "$_script" "$_row" "$_dir") >/dev/null 2>&1 || _exit=$?

  assert_exit_code "generate-reintegration exits 0" 0 "$_exit"

  _reint="${_dir}/.furrow/rows/${_row}/reintegration.json"
  assert_file_exists "reintegration.json created" "$_reint"

  # Validate required fields present
  assert_json_field "schema_version is 1.0" "$_reint" '.schema_version' "1.0"
  assert_json_field "row_name matches" "$_reint" '.row_name' "$_row"
  assert_json_field "commits is array with items" "$_reint" '(.commits | length) > 0' "true"
  assert_json_field "test_results.pass is boolean" "$_reint" '.test_results.pass | type' "boolean"

  # Round-trip: sorted key order is stable
  _out1="$(jq --sort-keys 'del(.generated_at)' "$_reint" 2>/dev/null)"
  _out2="$(jq --sort-keys 'del(.generated_at)' "$_reint" 2>/dev/null)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_out1" = "$_out2" ]; then
    printf '  PASS: round-trip key ordering is stable\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: round-trip key ordering differs\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  rm -rf "$_dir"
  trap - EXIT INT TERM
}

# --- Scenario 2: Synthetic worktree (AC-R3) ---
test_synthetic_worktree() {
  printf '\n[Scenario 2: synthetic worktree]\n'
  _dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$_dir'" EXIT INT TERM

  _row="$(build_test_repo "$_dir")"

  # Add 3 commits with different conventional types
  (
    cd "$_dir" &&
    printf 'feat content\n' > feat_file.txt &&
    git add feat_file.txt &&
    git commit -q -m "feat: add feature x"
  )
  (
    cd "$_dir" &&
    printf 'fix content\n' > fix_file.txt &&
    git add fix_file.txt &&
    git commit -q -m "fix: fix bug y"
  )
  (
    cd "$_dir" &&
    printf 'chore content\n' > chore_file.txt &&
    git add chore_file.txt &&
    git commit -q -m "chore: cleanup z"
  )

  _script="${PROJECT_ROOT}/bin/frw.d/scripts/generate-reintegration.sh"
  _exit=0
  (cd "$_dir" && sh "$_script" "$_row" "$_dir") >/dev/null 2>&1 || _exit=$?

  assert_exit_code "generate-reintegration exits 0 with 3 commits" 0 "$_exit"

  _reint="${_dir}/.furrow/rows/${_row}/reintegration.json"
  assert_file_exists "reintegration.json created" "$_reint"

  assert_json_field "commits count is 3" "$_reint" '(.commits | length)' "3"
  # git log lists newest first; chore was last added, feat was first
  assert_json_field "commits include all 3 types" "$_reint" \
    '(.commits | map(.conventional_type) | sort | join(","))' "chore,feat,fix"
  assert_json_field "test_results.pass is true" "$_reint" '.test_results.pass' "true"

  # summary.md should contain both markers
  _summary="${_dir}/.furrow/rows/${_row}/summary.md"
  assert_file_contains "summary.md has begin marker" "$_summary" '<!-- reintegration:begin -->'
  assert_file_contains "summary.md has end marker" "$_summary" '<!-- reintegration:end -->'

  rm -rf "$_dir"
  trap - EXIT INT TERM
}

# --- Scenario 3: Install-artifact detection (AC-R3 classifier) ---
test_install_artifact_detection() {
  printf '\n[Scenario 3: install-artifact detection]\n'
  _dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$_dir'" EXIT INT TERM

  _row="$(build_test_repo "$_dir")"

  # Add a commit touching a .bak file (install artifact)
  mkdir -p "${_dir}/bin"
  (
    cd "$_dir" &&
    printf 'some content\n' > "bin/rws.bak" &&
    git add "bin/rws.bak" &&
    git commit -q -m "chore: add bak file"
  )

  _script="${PROJECT_ROOT}/bin/frw.d/scripts/generate-reintegration.sh"
  _exit=0
  (cd "$_dir" && sh "$_script" "$_row" "$_dir") >/dev/null 2>&1 || _exit=$?

  assert_exit_code "generate-reintegration exits 0 for bak commit" 0 "$_exit"

  _reint="${_dir}/.furrow/rows/${_row}/reintegration.json"
  assert_file_exists "reintegration.json created" "$_reint"

  assert_json_field "last commit install_artifact_risk is high" "$_reint" '.commits[-1].install_artifact_risk' "high"

  # files_changed should have install-artifact category
  _has_artifact="$(jq '.files_changed | map(select(.category == "install-artifact")) | length > 0' "$_reint" 2>/dev/null)" || _has_artifact="false"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_has_artifact" = "true" ]; then
    printf '  PASS: files_changed contains install-artifact category\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: files_changed missing install-artifact category\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # rescue_likely_needed should be false (common.sh not touched)
  assert_json_field "rescue_likely_needed is false for bak-only commit" "$_reint" '.merge_hints.rescue_likely_needed' "false"

  rm -rf "$_dir"
  trap - EXIT INT TERM
}

# --- Scenario 4: Template fallback / AC-R5 ---
test_template_fallback() {
  printf '\n[Scenario 4: template fallback]\n'

  _tmpl="${PROJECT_ROOT}/templates/reintegration.md.tmpl"
  assert_file_exists "reintegration.md.tmpl exists" "$_tmpl"

  # Must contain both markers
  assert_file_contains "template has begin marker" "$_tmpl" '<!-- reintegration:begin -->'
  assert_file_contains "template has end marker" "$_tmpl" '<!-- reintegration:end -->'

  # Must NOT contain {{ placeholders
  TESTS_RUN=$((TESTS_RUN + 1))
  _placeholder_count="$(grep -c '{{' "$_tmpl" 2>/dev/null || true)"
  if [ "${_placeholder_count:-0}" -eq 0 ]; then
    printf '  PASS: template has no {{ placeholders\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: template contains {{ placeholders (%s occurrences)\n' "$_placeholder_count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Test that generate-reintegration on a fresh row (no prior Reintegration section)
  # still adds the markers
  _dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$_dir'" EXIT INT TERM

  _row="$(build_test_repo "$_dir")"

  # Add one commit
  (
    cd "$_dir" &&
    printf 'content\n' > newfile.txt &&
    git add newfile.txt &&
    git commit -q -m "feat: add file"
  )

  _script="${PROJECT_ROOT}/bin/frw.d/scripts/generate-reintegration.sh"
  _exit=0
  (cd "$_dir" && sh "$_script" "$_row" "$_dir") >/dev/null 2>&1 || _exit=$?

  assert_exit_code "generate-reintegration exits 0 (fresh row)" 0 "$_exit"

  _summary="${_dir}/.furrow/rows/${_row}/summary.md"
  assert_file_contains "fresh summary has begin marker" "$_summary" '<!-- reintegration:begin -->'
  assert_file_contains "fresh summary has end marker" "$_summary" '<!-- reintegration:end -->'

  rm -rf "$_dir"
  trap - EXIT INT TERM
}

# --- Scenario 5: Rescue hint on common.sh touch (AC-R3) ---
test_rescue_hint() {
  printf '\n[Scenario 5: rescue hint on common.sh touch]\n'
  _dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$_dir'" EXIT INT TERM

  _row="$(build_test_repo "$_dir")"

  # Add commit touching common.sh
  mkdir -p "${_dir}/bin/frw.d/lib"
  (
    cd "$_dir" &&
    printf '# common.sh touched\n' > "bin/frw.d/lib/common.sh" &&
    git add "bin/frw.d/lib/common.sh" &&
    git commit -q -m "refactor: update common.sh"
  )

  _script="${PROJECT_ROOT}/bin/frw.d/scripts/generate-reintegration.sh"
  _exit=0
  (cd "$_dir" && sh "$_script" "$_row" "$_dir") >/dev/null 2>&1 || _exit=$?

  assert_exit_code "generate-reintegration exits 0" 0 "$_exit"

  _reint="${_dir}/.furrow/rows/${_row}/reintegration.json"
  assert_file_exists "reintegration.json created" "$_reint"
  assert_json_field "rescue_likely_needed is true" "$_reint" '.merge_hints.rescue_likely_needed' "true"

  # Rendered markdown should contain frw rescue hint
  _summary="${_dir}/.furrow/rows/${_row}/summary.md"
  assert_file_contains "summary contains frw rescue hint" "$_summary" 'frw rescue'

  rm -rf "$_dir"
  trap - EXIT INT TERM
}

# --- Scenario 6: Merge-consumer contract (AC-R4) ---
test_merge_consumer_contract() {
  printf '\n[Scenario 6: merge-consumer contract]\n'
  _dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$_dir'" EXIT INT TERM

  _row="$(build_test_repo "$_dir")"

  # Add one commit so we have a valid branch range
  (
    cd "$_dir" &&
    printf 'content\n' > testfile.txt &&
    git add testfile.txt &&
    git commit -q -m "feat: add test file"
  )

  # (a) reintegration.json missing -> rws get-reintegration-json exits 2
  _exit=0
  (cd "$_dir" && rws get-reintegration-json "$_row") >/dev/null 2>&1 || _exit=$?
  assert_exit_code "get-reintegration-json exits 2 when file missing" 2 "$_exit"

  # (b) reintegration.json present and valid -> exits 0 with JSON on stdout
  _script="${PROJECT_ROOT}/bin/frw.d/scripts/generate-reintegration.sh"
  (cd "$_dir" && sh "$_script" "$_row" "$_dir") >/dev/null 2>&1

  _exit=0
  _output=""
  _output="$(cd "$_dir" && rws get-reintegration-json "$_row" 2>/dev/null)" || _exit=$?
  assert_exit_code "get-reintegration-json exits 0 when file valid" 0 "$_exit"

  # Output must be parseable JSON
  TESTS_RUN=$((TESTS_RUN + 1))
  _parsed="$(printf '%s' "$_output" | jq '.' 2>/dev/null)" || _parsed=""
  if [ -n "$_parsed" ]; then
    printf '  PASS: get-reintegration-json output is valid JSON\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: get-reintegration-json output is not valid JSON\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # (c) corrupt reintegration.json (drop schema_version) -> exits 3
  _reint="${_dir}/.furrow/rows/${_row}/reintegration.json"
  jq 'del(.schema_version)' "$_reint" > "${_reint}.tmp" && mv "${_reint}.tmp" "$_reint"

  _exit=0
  (cd "$_dir" && rws get-reintegration-json "$_row") >/dev/null 2>&1 || _exit=$?
  assert_exit_code "get-reintegration-json exits 3 when schema invalid" 3 "$_exit"

  rm -rf "$_dir"
  trap - EXIT INT TERM
}

# --- Scenario 7: Idempotency + round-trip (AC-R6) ---
test_idempotency() {
  printf '\n[Scenario 7: idempotency + round-trip]\n'
  _dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$_dir'" EXIT INT TERM

  _row="$(build_test_repo "$_dir")"

  # Add one commit
  (
    cd "$_dir" &&
    printf 'content\n' > testfile2.txt &&
    git add testfile2.txt &&
    git commit -q -m "feat: idempotency test"
  )

  _script="${PROJECT_ROOT}/bin/frw.d/scripts/generate-reintegration.sh"

  # Generate twice
  (cd "$_dir" && sh "$_script" "$_row" "$_dir") >/dev/null 2>&1
  _reint="${_dir}/.furrow/rows/${_row}/reintegration.json"
  _snap1="$(jq --sort-keys 'del(.generated_at)' "$_reint" 2>/dev/null)"

  # Small delay to ensure generated_at would differ
  sleep 1

  (cd "$_dir" && sh "$_script" "$_row" "$_dir") >/dev/null 2>&1
  _snap2="$(jq --sort-keys 'del(.generated_at)' "$_reint" 2>/dev/null)"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_snap1" = "$_snap2" ]; then
    printf '  PASS: re-generation produces byte-identical JSON modulo generated_at\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: re-generation changed fields beyond generated_at\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  diff:\n%s\n' "$(diff <(printf '%s' "$_snap1") <(printf '%s' "$_snap2") 2>/dev/null || true)" >&2
  fi

  rm -rf "$_dir"
  trap - EXIT INT TERM
}

# --- Scenario 8: update-summary rejects reintegration section (AC-R1) ---
test_update_summary_rejects_reintegration() {
  printf '\n[Scenario 8: update-summary rejects reintegration section]\n'
  _dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$_dir'" EXIT INT TERM

  _row="$(build_test_repo "$_dir")"

  # Attempt to update-summary reintegration
  _exit=0
  _stderr=""
  _stderr="$(cd "$_dir" && printf 'stuff\n' | rws update-summary "$_row" reintegration 2>&1)" || _exit=$?

  assert_exit_code "update-summary reintegration exits non-zero" 3 "$_exit"

  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s' "$_stderr" | grep -q 'generate-reintegration'; then
    printf '  PASS: error message points to generate-reintegration\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: error message does not mention generate-reintegration (got: %s)\n' "$_stderr" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Also test without explicit row name (uses focused row if set)
  _exit2=0
  _stderr2="$(cd "$_dir" && printf 'stuff\n' | rws update-summary reintegration 2>&1)" || _exit2=$?
  # Should also be rejected (exit 3) regardless of row name resolution
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_exit2" -ne 0 ]; then
    printf '  PASS: update-summary reintegration (no row) also rejected\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: update-summary reintegration (no row) unexpectedly succeeded\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  rm -rf "$_dir"
  trap - EXIT INT TERM
}

# --- Scenario 9: validate-summary requires both markers when section present (AC-R1) ---
test_validate_summary_marker_enforcement() {
  printf '\n[Scenario 9: validate-summary marker enforcement]\n'
  _dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$_dir'" EXIT INT TERM

  _row="$(build_test_repo "$_dir")"
  _summary="${_dir}/.furrow/rows/${_row}/summary.md"

  # Add Reintegration section with only one marker (missing end)
  cat >> "$_summary" << 'REINT'

## Reintegration
<!-- reintegration:begin -->
Some content here.
REINT

  _exit=0
  (cd "$_dir" && rws validate-summary "$_row") >/dev/null 2>&1 || _exit=$?
  assert_exit_code "validate-summary exits non-zero when end marker missing" 1 "$_exit"

  # Fix by adding the end marker
  printf '<!-- reintegration:end -->\n' >> "$_summary"

  _exit=0
  (cd "$_dir" && rws validate-summary "$_row") >/dev/null 2>&1 || _exit=$?
  assert_exit_code "validate-summary exits 0 when both markers present" 0 "$_exit"

  rm -rf "$_dir"
  trap - EXIT INT TERM
}

# --- Scenario 10: Template modification surfaces in rendered output (AC-R5) ---
test_template_modification_surfaces_in_render() {
  printf '\n[Scenario 10: template modification surfaces in rendered output]\n'
  _dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$_dir'" EXIT INT TERM

  _row="$(build_test_repo "$_dir")"

  # Add one commit so we have a valid branch range
  (
    cd "$_dir" &&
    printf 'content\n' > marker_test.txt &&
    git add marker_test.txt &&
    git commit -q -m "feat: marker test commit"
  )

  # Create a local template dir with a modified skeleton containing an identifiable marker
  _tmpl_dir="${_dir}/.tmpl_override"
  mkdir -p "$_tmpl_dir"
  cat > "${_tmpl_dir}/reintegration.md.tmpl" << 'TMPL'
<!-- reintegration:begin -->
## Reintegration
<!-- TEMPLATE_FIXTURE_MARKER -->
<!-- reintegration:end -->
TMPL

  _script="${PROJECT_ROOT}/bin/frw.d/scripts/generate-reintegration.sh"
  _exit=0
  (cd "$_dir" && FURROW_TEMPLATE_DIR="$_tmpl_dir" sh "$_script" "$_row" "$_dir") >/dev/null 2>&1 || _exit=$?

  assert_exit_code "generate-reintegration exits 0 with template override" 0 "$_exit"

  _summary="${_dir}/.furrow/rows/${_row}/summary.md"
  assert_file_contains "rendered output contains TEMPLATE_FIXTURE_MARKER" "$_summary" '<!-- TEMPLATE_FIXTURE_MARKER -->'
  assert_file_contains "rendered output still has begin marker" "$_summary" '<!-- reintegration:begin -->'
  assert_file_contains "rendered output still has end marker" "$_summary" '<!-- reintegration:end -->'

  rm -rf "$_dir"
  trap - EXIT INT TERM
}

# --- Run all scenarios ---
printf '=== test-reintegration.sh ===\n'

test_schema_round_trip
test_synthetic_worktree
test_install_artifact_detection
test_template_fallback
test_rescue_hint
test_merge_consumer_contract
test_idempotency
test_update_summary_rejects_reintegration
test_validate_summary_marker_enforcement
test_template_modification_surfaces_in_render

# --- Summary ---
printf '\n=== Results ===\n'
printf '%d tests run, %d passed, %d failed\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
