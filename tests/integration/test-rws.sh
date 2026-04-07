#!/bin/bash
# test-rws.sh — Integration tests for rws CLI
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=helpers.sh
. "${SCRIPT_DIR}/helpers.sh"

echo "=== test-rws.sh ==="

# --- Setup ---

setup_test_env
cd "$TEST_DIR"

# Initialize seeds first (rws init auto-creates seeds)
sds init --prefix test-proj

# Create a minimal definition.yaml helper
_write_definition() {
  _def_dir="$1"
  cat > "${_def_dir}/definition.yaml" << 'YAML'
objective: "test objective"
deliverables:
  - name: test-deliverable
    specialist: test-eng
    acceptance_criteria:
      - "tests pass"
    file_ownership:
      - "src/*.sh"
context_pointers:
  - path: test
    note: test
constraints: []
gate_policy: supervised
YAML
}

# --- Tests ---

# -- init --
test_init() {
  echo "  --- test_init ---"

  rws init test-row --title "Test Row"
  assert_file_exists "state.json created" ".furrow/rows/test-row/state.json"

  state_file=".furrow/rows/test-row/state.json"
  assert_json_field "initial step is ideate" "$state_file" '.step' "ideate"

  # Verify seed was auto-created
  seed_id=$(jq -r '.seed_id' "$state_file")
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -n "$seed_id" ] && [ "$seed_id" != "null" ]; then
    printf "  PASS: seed auto-created (id=%s)\n" "$seed_id"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: seed_id is null or empty\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Verify seed status is claimed
  seed_status=$(sds show "$seed_id" --json | jq -r '.status')
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$seed_status" = "claimed" ]; then
    printf "  PASS: seed status is claimed after init\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: seed status expected 'claimed', got '%s'\n" "$seed_status" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- status --
test_status() {
  echo "  --- test_status ---"

  output=$(rws status test-row)
  assert_output_contains "status shows row name" "$output" "test-row"
  assert_output_contains "status shows step" "$output" "ideate"
}

# -- list --active --
test_list() {
  echo "  --- test_list ---"

  output=$(rws list --active)
  assert_output_contains "list includes test-row" "$output" "test-row"
}

# -- focus --
test_focus() {
  echo "  --- test_focus ---"

  rws focus test-row
  assert_file_exists ".focused file exists" ".furrow/.focused"
  assert_file_contains "focused contains test-row" ".furrow/.focused" "test-row"

  # Show focus
  focus_output=$(rws focus)
  assert_output_contains "focus shows current" "$focus_output" "test-row"

  # Clear focus
  rws focus --clear
  assert_file_not_exists ".focused removed after clear" ".furrow/.focused"
}

# -- load-step --
test_load_step() {
  echo "  --- test_load_step ---"

  # Focus the row so load-step can resolve it
  rws focus test-row
  output=$(rws load-step test-row)
  assert_output_contains "load-step mentions ideate skill" "$output" "ideate"

  rws focus --clear
}

# -- transition (two-phase supervised) --
test_transition() {
  echo "  --- test_transition ---"

  # Write definition.yaml for ideate->research validation
  _write_definition ".furrow/rows/test-row"

  state_file=".furrow/rows/test-row/state.json"

  # Single-command transition (records gate, validates, and advances atomically)
  rws transition test-row pass manual "test evidence"
  assert_json_field "step advanced to research" "$state_file" '.step' "research"

  # Verify seed status synced
  seed_id=$(jq -r '.seed_id' "$state_file")
  seed_status=$(sds show "$seed_id" --json | jq -r '.status')
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$seed_status" = "researching" ]; then
    printf "  PASS: seed status synced to researching\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: seed status expected 'researching', got '%s'\n" "$seed_status" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- rewind --
test_rewind() {
  echo "  --- test_rewind ---"

  state_file=".furrow/rows/test-row/state.json"

  # Currently at research from previous test; rewind to ideate
  rws rewind test-row ideate
  assert_json_field "rewound to ideate" "$state_file" '.step' "ideate"
}

# -- diff --
test_diff() {
  echo "  --- test_diff ---"

  # diff requires a valid base_commit
  output=$(rws diff test-row 2>&1 || true)
  # Should show something about the diff (row has a base_commit from git rev-parse at init)
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s\n' "$output" | grep -qE "Row Diff|Base commit"; then
    printf "  PASS: diff outputs diff header\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: diff output unexpected: %s\n" "$output" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- regenerate-summary --
test_regenerate_summary() {
  echo "  --- test_regenerate_summary ---"

  rws regenerate-summary test-row
  assert_file_exists "summary.md created" ".furrow/rows/test-row/summary.md"
  assert_file_contains "summary has Task section" ".furrow/rows/test-row/summary.md" "## Task"
  assert_file_contains "summary has Current State" ".furrow/rows/test-row/summary.md" "## Current State"
}

test_complete_deliverable() {
  echo "  --- test_complete_deliverable ---"

  # Set up a row at implement step with definition
  rws init deliv-row --title "Deliverable Test"
  _write_definition ".furrow/rows/deliv-row"

  # Fast-forward to implement step
  _deliv_state=".furrow/rows/deliv-row/state.json"
  jq '.step = "implement" | .step_status = "in_progress"' \
    "$_deliv_state" > "$_deliv_state.tmp" && mv "$_deliv_state.tmp" "$_deliv_state"

  # Complete deliverable (no plan.json, should default to wave=1)
  _cd_rc=0
  _cd_output=$(rws complete-deliverable deliv-row test-deliverable 2>&1) || _cd_rc=$?
  assert_exit_code "complete-deliverable succeeds" 0 "$_cd_rc"
  assert_output_contains "output mentions deliverable name" "$_cd_output" "test-deliverable"
  assert_output_contains "output mentions wave 1" "$_cd_output" "wave 1"

  # Verify state was updated
  assert_json_field "deliverable status is completed" "$_deliv_state" '.deliverables["test-deliverable"].status' "completed"

  # Invalid deliverable should fail with exit 3
  _cd_bad_rc=0
  rws complete-deliverable deliv-row nonexistent 2>/dev/null || _cd_bad_rc=$?
  assert_exit_code "invalid deliverable exits 3" 3 "$_cd_bad_rc"

  # Test with plan.json for wave assignment
  cat > ".furrow/rows/deliv-row/plan.json" << 'JSON'
{"waves":[{"wave":2,"deliverables":["test-deliverable"]}]}
JSON

  rws complete-deliverable deliv-row test-deliverable > /dev/null 2>&1
  _cd_wave="$(jq -r '.deliverables["test-deliverable"].wave' "$_deliv_state")"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_cd_wave" = "2" ]; then
    printf "  PASS: wave read from plan.json (wave=2)\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: expected wave 2 from plan.json, got '%s'\n" "$_cd_wave" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_complete_step() {
  echo "  --- test_complete_step ---"

  # Use the deliv-row from previous test (at implement step)
  _cs_state=".furrow/rows/deliv-row/state.json"

  # Complete the implement step (no review precondition check)
  _cs_rc=0
  _cs_output=$(rws complete-step deliv-row 2>&1) || _cs_rc=$?
  assert_exit_code "complete-step succeeds for implement" 0 "$_cs_rc"
  assert_output_contains "output mentions step name" "$_cs_output" "implement"
  assert_json_field "step_status is completed" "$_cs_state" '.step_status' "completed"

  # Advance to review step, reset step_status
  jq '.step = "review" | .step_status = "in_progress"' \
    "$_cs_state" > "$_cs_state.tmp" && mv "$_cs_state.tmp" "$_cs_state"

  # Complete review step — deliverable is already completed, should succeed
  _cs_rc2=0
  _cs_output2=$(rws complete-step deliv-row 2>&1) || _cs_rc2=$?
  assert_exit_code "complete-step succeeds at review with all deliverables done" 0 "$_cs_rc2"
  assert_output_contains "output mentions review" "$_cs_output2" "review"

  # Set up a row with incomplete deliverable to test precondition failure
  rws init cs-fail-row --title "Complete Step Fail Test"
  _write_definition ".furrow/rows/cs-fail-row"
  _cs_fail_state=".furrow/rows/cs-fail-row/state.json"
  jq '.step = "review" | .step_status = "in_progress"' \
    "$_cs_fail_state" > "$_cs_fail_state.tmp" && mv "$_cs_fail_state.tmp" "$_cs_fail_state"

  _cs_fail_rc=0
  rws complete-step cs-fail-row 2>/dev/null || _cs_fail_rc=$?
  assert_exit_code "complete-step fails at review with missing deliverables" 3 "$_cs_fail_rc"
}

test_archive() {
  echo "--- test_archive ---"
  # Set up a row that can be archived:
  # Must be at review step with step_status=completed and all deliverables completed
  rws init archive-row --title "Archive Test"
  _write_definition ".furrow/rows/archive-row"

  # Fast-forward state to review/completed via direct state manipulation
  # (testing the archive subcommand, not the full lifecycle)
  _archive_state=".furrow/rows/archive-row/state.json"
  _seed_id="$(jq -r '.seed_id' "$_archive_state")"
  jq '.step = "review" | .step_status = "completed" | .deliverables = {"test-deliverable": {"status": "completed", "wave": 1, "corrections": 0}}' \
    "$_archive_state" > "$_archive_state.tmp" && mv "$_archive_state.tmp" "$_archive_state"

  # Add required gate record
  jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '.gates += [{"boundary": "implement->review", "outcome": "pass", "decided_by": "manual", "evidence": "test", "timestamp": $ts}]' \
    "$_archive_state" > "$_archive_state.tmp" && mv "$_archive_state.tmp" "$_archive_state"

  # Sync seed to reviewing status
  sds update "$_seed_id" --status reviewing 2>/dev/null || true

  _archive_rc=0
  rws archive archive-row || _archive_rc=$?
  assert_exit_code "rws archive succeeds" 0 "$_archive_rc"

  assert_file_contains "archived_at is set" "$_archive_state" "archived_at"

  # Verify seed was closed
  _seed_status="$(sds show "$_seed_id" --json | jq -r '.status')"
  assert_output_contains "seed closed after archive" "$_seed_status" "closed"
}

# --- Run all tests ---

test_init
test_status
test_list
test_focus
test_load_step
test_transition
test_rewind
test_diff
test_regenerate_summary
test_complete_deliverable
test_complete_step
test_archive

# --- Summary ---

print_summary
