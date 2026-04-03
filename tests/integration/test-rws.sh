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

  # Request transition
  rws transition --request test-row pass manual "test evidence"

  state_file=".furrow/rows/test-row/state.json"
  assert_json_field "step_status pending after request" "$state_file" '.step_status' "pending_approval"

  # Confirm transition
  rws transition --confirm test-row
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
test_archive

# --- Summary ---

print_summary
