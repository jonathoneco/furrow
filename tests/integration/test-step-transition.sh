#!/bin/bash
# test-step-transition.sh — Integration tests for commands/lib/step-transition.sh
#
# Sourced by the test runner. Requires helpers.sh (provides setup_fixture,
# teardown_fixture, assert_exit_code, assert_file_exists, assert_file_contains,
# assert_json_field, HARNESS_ROOT).

# --- helper: create fixture with symlinked scripts and a complete work unit ---

_unit_name="__test-transition"

_setup_transition_fixture() {
  setup_fixture "$_unit_name"

  # Symlink commands/lib/step-transition.sh so harness_root resolves to FIXTURE_DIR
  # (step-transition.sh does: script_dir -> commands/lib, harness_root -> ../.. = FIXTURE_DIR)
  mkdir -p "${FIXTURE_DIR}/commands/lib"
  ln -sf "${HARNESS_ROOT}/commands/lib/step-transition.sh" "${FIXTURE_DIR}/commands/lib/step-transition.sh"

  # Symlink all scripts from scripts/ into FIXTURE_DIR/scripts/
  # (step-transition.sh calls ${harness_root}/scripts/*, and update-state.sh
  #  resolves schema via ${script_dir}/.. which will be FIXTURE_DIR)
  mkdir -p "${FIXTURE_DIR}/scripts"
  for script in record-gate.sh update-state.sh validate-step-artifacts.sh \
                regenerate-summary.sh advance-step.sh check-wave-conflicts.sh; do
    ln -sf "${HARNESS_ROOT}/scripts/${script}" "${FIXTURE_DIR}/scripts/${script}"
  done

  # Symlink schema for update-state.sh validation
  # (update-state.sh: harness_root = script_dir/.., schema = harness_root/schemas/state.schema.json)
  mkdir -p "${FIXTURE_DIR}/schemas"
  ln -sf "${HARNESS_ROOT}/schemas/state.schema.json" "${FIXTURE_DIR}/schemas/state.schema.json"

  # Symlink hooks/lib/ for validate-step-artifacts.sh (needed on pass path)
  mkdir -p "${FIXTURE_DIR}/hooks/lib"
  ln -sf "${HARNESS_ROOT}/hooks/lib/common.sh" "${FIXTURE_DIR}/hooks/lib/common.sh"
  ln -sf "${HARNESS_ROOT}/hooks/lib/validate.sh" "${FIXTURE_DIR}/hooks/lib/validate.sh"

  # Create minimal summary.md and definition.yaml (needed by regenerate-summary)
  touch "${WORK_DIR}/summary.md"
  cat > "${WORK_DIR}/definition.yaml" << 'YAML'
name: __test-transition
title: test
objective: test
deliverables:
  - name: api
    description: test deliverable
YAML
}

# Write state.json with configurable step and deliverables.
# Args: $1 = step, $2 = deliverables_json
_write_transition_state() {
  _step="$1"
  _deliverables="$2"

  cat > "${WORK_DIR}/state.json" << JSON
{
  "name": "${_unit_name}",
  "title": "test",
  "description": "test",
  "step": "${_step}",
  "step_status": "in_progress",
  "steps_sequence": ["ideate","research","plan","spec","decompose","implement","review"],
  "deliverables": ${_deliverables},
  "gates": [],
  "force_stop_at": null,
  "branch": "test-branch",
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

# Run step-transition.sh from inside FIXTURE_DIR (so .work/ paths resolve).
# Args: $1 = name, $2 = outcome, $3 = decided_by, $4 = evidence
# Sets: _exit_code, _stderr_file, _stdout_file
_run_transition() {
  _exit_code=0
  _stderr_file="${FIXTURE_DIR}/stderr.txt"
  _stdout_file="${FIXTURE_DIR}/stdout.txt"

  (cd "${FIXTURE_DIR}" && \
    "${FIXTURE_DIR}/commands/lib/step-transition.sh" "$@") \
    >"$_stdout_file" 2>"$_stderr_file" || _exit_code=$?
}

# --- test functions ---

test_fail_increments_in_progress_only() {
  _setup_transition_fixture
  _write_transition_state "implement" '{
    "api": {"status": "in_progress", "assigned_to": "test-eng", "wave": 1, "corrections": 0},
    "docs": {"status": "completed", "assigned_to": "test-eng", "wave": 1, "corrections": 0}
  }'

  _run_transition "$_unit_name" "fail" "manual" "test failure"

  assert_exit_code "fail at implement exits 0" 0 "$_exit_code"
  assert_json_field "api corrections incremented to 1" "${WORK_DIR}/state.json" \
    '.deliverables.api.corrections' "1"
  assert_json_field "docs corrections unchanged at 0" "${WORK_DIR}/state.json" \
    '.deliverables.docs.corrections' "0"
  assert_json_field "docs status still completed" "${WORK_DIR}/state.json" \
    '.deliverables.docs.status' "completed"
  assert_json_field "step remains implement" "${WORK_DIR}/state.json" \
    '.step' "implement"
  assert_json_field "step_status reset to in_progress" "${WORK_DIR}/state.json" \
    '.step_status' "in_progress"

  teardown_fixture
}

test_pass_at_final_step() {
  _setup_transition_fixture
  _write_transition_state "review" '{
    "api": {"status": "in_progress", "assigned_to": "test-eng", "wave": 1, "corrections": 0}
  }'

  _run_transition "$_unit_name" "pass" "manual" "looks good"

  assert_exit_code "pass at review exits 3" 3 "$_exit_code"
  assert_file_contains "stderr mentions cannot advance" "$_stderr_file" \
    "Cannot advance past final step"
  # Gate should NOT be recorded (exit happens before record-gate)
  assert_json_field "gates array still empty" "${WORK_DIR}/state.json" \
    '.gates | length' "0"

  teardown_fixture
}

test_fail_at_final_step() {
  _setup_transition_fixture
  _write_transition_state "review" '{
    "api": {"status": "in_progress", "assigned_to": "test-eng", "wave": 1, "corrections": 0}
  }'

  _run_transition "$_unit_name" "fail" "manual" "needs rework"

  assert_exit_code "fail at review exits 0" 0 "$_exit_code"
  assert_json_field "step remains review" "${WORK_DIR}/state.json" \
    '.step' "review"
  assert_json_field "api corrections incremented to 1" "${WORK_DIR}/state.json" \
    '.deliverables.api.corrections' "1"
  assert_json_field "gate recorded" "${WORK_DIR}/state.json" \
    '.gates | length' "1"
  assert_json_field "gate outcome is fail" "${WORK_DIR}/state.json" \
    '.gates[0].outcome' "fail"

  teardown_fixture
}
