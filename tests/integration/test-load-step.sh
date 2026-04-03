#!/bin/bash
# test-load-step.sh — Integration tests for commands/lib/load-step.sh
#
# Sourced by the test runner. Requires helpers.sh (provides setup_fixture,
# teardown_fixture, assert_exit_code, assert_file_exists, assert_file_contains,
# assert_file_not_contains, FURROW_ROOT).

# --- helper: set up fixture with symlinked load-step.sh and commands/lib structure ---

_setup_load_step_fixture() {
  _name="$1"
  setup_fixture "$_name"

  mkdir -p "${FIXTURE_DIR}/commands/lib"
  ln -sf "${FURROW_ROOT}/commands/lib/load-step.sh" "${FIXTURE_DIR}/commands/lib/load-step.sh"
}

# --- helper: write state.json with a given step and gates array ---

_write_load_step_state() {
  _state_dir="$1"
  _name="$2"
  _step="$3"
  _gates="$4"

  cat > "${_state_dir}/state.json" << JSON
{
  "name": "${_name}",
  "title": "test",
  "description": "test",
  "step": "${_step}",
  "step_status": "in_progress",
  "steps_sequence": ["ideate","research","plan","spec","decompose","implement","review"],
  "deliverables": {},
  "gates": ${_gates},
  "force_stop_at": null,
  "branch": null,
  "mode": "code",
  "base_commit": "abc123",
  "epic_id": null,
  "issue_id": null,
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z",
  "archived_at": null
}
JSON
}

# --- test functions ---

test_conditional_with_conditions() {
  _setup_load_step_fixture "__test-load-step"

  _gates='[{"boundary": "implement->review", "outcome": "conditional", "decided_by": "evaluated", "evidence": "partial pass", "conditions": ["Fix error handling in api.sh", "Add missing test for edge case"], "timestamp": "2026-01-01T00:00:00Z"}]'
  _write_load_step_state "${WORK_DIR}" "__test-load-step" "review" "$_gates"

  # Create required skill file and summary
  echo "# test skill" > "${FIXTURE_DIR}/skills/review.md"
  echo "# summary" > "${WORK_DIR}/summary.md"

  # Run from FIXTURE_DIR since work_dir is relative to CWD
  _stdout="${FIXTURE_DIR}/stdout.txt"
  exit_code=0
  (cd "${FIXTURE_DIR}" && "${FIXTURE_DIR}/commands/lib/load-step.sh" "__test-load-step") > "$_stdout" 2>/dev/null || exit_code=$?

  assert_exit_code "conditional with conditions exits 0" 0 "$exit_code"
  assert_file_contains "stdout contains CONDITIONAL PASS" "$_stdout" "CONDITIONAL PASS"
  assert_file_contains "stdout contains first condition" "$_stdout" "Fix error handling in api.sh"
  assert_file_contains "stdout contains second condition" "$_stdout" "Add missing test for edge case"

  teardown_fixture
}

test_conditional_null_conditions() {
  _setup_load_step_fixture "__test-load-step"

  _gates='[{"boundary": "implement->review", "outcome": "conditional", "decided_by": "evaluated", "evidence": "partial pass", "conditions": null, "timestamp": "2026-01-01T00:00:00Z"}]'
  _write_load_step_state "${WORK_DIR}" "__test-load-step" "review" "$_gates"

  echo "# test skill" > "${FIXTURE_DIR}/skills/review.md"
  echo "# summary" > "${WORK_DIR}/summary.md"

  _stdout="${FIXTURE_DIR}/stdout.txt"
  exit_code=0
  (cd "${FIXTURE_DIR}" && "${FIXTURE_DIR}/commands/lib/load-step.sh" "__test-load-step") > "$_stdout" 2>/dev/null || exit_code=$?

  assert_exit_code "conditional with null conditions exits 0" 0 "$exit_code"
  assert_file_not_contains "stdout does not contain CONDITIONAL PASS" "$_stdout" "CONDITIONAL PASS"

  teardown_fixture
}

test_pass_no_conditions() {
  _setup_load_step_fixture "__test-load-step"

  _gates='[{"boundary": "implement->review", "outcome": "pass", "decided_by": "manual", "evidence": "all good", "timestamp": "2026-01-01T00:00:00Z"}]'
  _write_load_step_state "${WORK_DIR}" "__test-load-step" "review" "$_gates"

  echo "# test skill" > "${FIXTURE_DIR}/skills/review.md"
  echo "# summary" > "${WORK_DIR}/summary.md"

  _stdout="${FIXTURE_DIR}/stdout.txt"
  exit_code=0
  (cd "${FIXTURE_DIR}" && "${FIXTURE_DIR}/commands/lib/load-step.sh" "__test-load-step") > "$_stdout" 2>/dev/null || exit_code=$?

  assert_exit_code "pass gate exits 0" 0 "$exit_code"
  assert_file_not_contains "stdout does not contain CONDITIONAL PASS" "$_stdout" "CONDITIONAL PASS"

  teardown_fixture
}

test_missing_skill_file() {
  _setup_load_step_fixture "__test-load-step"

  _gates='[]'
  _write_load_step_state "${WORK_DIR}" "__test-load-step" "nonexistent" "$_gates"

  # Do NOT create skills/nonexistent.md
  echo "# summary" > "${WORK_DIR}/summary.md"

  _stderr="${FIXTURE_DIR}/stderr.txt"
  exit_code=0
  (cd "${FIXTURE_DIR}" && "${FIXTURE_DIR}/commands/lib/load-step.sh" "__test-load-step") > /dev/null 2>"$_stderr" || exit_code=$?

  assert_exit_code "missing skill file exits 3" 3 "$exit_code"
  assert_file_contains "stderr mentions skill file not found" "$_stderr" "Skill file not found"

  teardown_fixture
}
