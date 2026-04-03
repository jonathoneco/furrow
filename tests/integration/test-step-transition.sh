#!/bin/bash
# test-step-transition.sh — Integration tests for commands/lib/step-transition.sh
#
# Sourced by the test runner. Requires helpers.sh (provides setup_fixture,
# teardown_fixture, assert_exit_code, assert_file_exists, assert_file_contains,
# assert_json_field, FURROW_ROOT).

# --- helper: create fixture with symlinked scripts and a complete row ---

_unit_name="__test-transition"

_setup_transition_fixture() {
  setup_fixture "$_unit_name"

  # Symlink commands/lib/step-transition.sh so furrow_root resolves to FIXTURE_DIR
  # (step-transition.sh does: script_dir -> commands/lib, furrow_root -> ../.. = FIXTURE_DIR)
  mkdir -p "${FIXTURE_DIR}/commands/lib"
  ln -sf "${FURROW_ROOT}/commands/lib/step-transition.sh" "${FIXTURE_DIR}/commands/lib/step-transition.sh"

  # Symlink all scripts from scripts/ into FIXTURE_DIR/scripts/
  # (step-transition.sh calls ${furrow_root}/scripts/*, and update-state.sh
  #  resolves schema via ${script_dir}/.. which will be FIXTURE_DIR)
  mkdir -p "${FIXTURE_DIR}/scripts"
  for script in record-gate.sh update-state.sh validate-step-artifacts.sh \
                regenerate-summary.sh advance-step.sh check-wave-conflicts.sh; do
    ln -sf "${FURROW_ROOT}/scripts/${script}" "${FIXTURE_DIR}/scripts/${script}"
  done

  # Symlink schema for update-state.sh validation
  # (update-state.sh: furrow_root = script_dir/.., schema = furrow_root/schemas/state.schema.json)
  mkdir -p "${FIXTURE_DIR}/schemas"
  ln -sf "${FURROW_ROOT}/schemas/state.schema.json" "${FIXTURE_DIR}/schemas/state.schema.json"

  # Symlink hooks/lib/ for validate-step-artifacts.sh (needed on pass path)
  mkdir -p "${FIXTURE_DIR}/hooks/lib"
  ln -sf "${FURROW_ROOT}/hooks/lib/common.sh" "${FIXTURE_DIR}/hooks/lib/common.sh"
  ln -sf "${FURROW_ROOT}/hooks/lib/validate.sh" "${FIXTURE_DIR}/hooks/lib/validate.sh"

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

# Run step-transition.sh from inside FIXTURE_DIR (so .furrow/rows/ paths resolve).
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

# --- two-phase gate tests ---

# Helper to write state with gate_policy in definition.yaml
_write_supervised_definition() {
  cat > "${WORK_DIR}/definition.yaml" << 'YAML'
objective: test
deliverables:
  - name: api
    acceptance_criteria:
      - "test AC"
    specialist: shell-specialist
context_pointers:
  - path: "test.sh"
    note: "test"
constraints:
  - "test constraint"
gate_policy: supervised
YAML
}

_write_delegated_definition() {
  cat > "${WORK_DIR}/definition.yaml" << 'YAML'
objective: test
deliverables:
  - name: api
    acceptance_criteria:
      - "test AC"
    specialist: shell-specialist
context_pointers:
  - path: "test.sh"
    note: "test"
constraints:
  - "test constraint"
gate_policy: delegated
YAML
}

test_request_sets_pending_approval() {
  _setup_transition_fixture
  _write_transition_state "ideate" '{}'
  _write_supervised_definition

  # Write minimal summary with required sections
  cat > "${WORK_DIR}/summary.md" << 'MD'
# Test Summary
## Task
test
## Current State
test
## Artifact Paths
test
## Settled Decisions
test
## Context Budget
test
## Key Findings
- finding one
## Open Questions
- question one
## Recommendations
- rec one
MD

  # Symlink validate-summary hook
  ln -sf "${FURROW_ROOT}/hooks/validate-summary.sh" "${FIXTURE_DIR}/hooks/validate-summary.sh"

  _run_transition --request "$_unit_name" "pass" "manual" "test evidence"

  assert_exit_code "request exits 0" 0 "$_exit_code"
  assert_json_field "step_status is pending_approval" "${WORK_DIR}/state.json" \
    '.step_status' "pending_approval"
  assert_json_field "gate recorded" "${WORK_DIR}/state.json" \
    '.gates | length' "1"
  assert_json_field "step still ideate" "${WORK_DIR}/state.json" \
    '.step' "ideate"

  teardown_fixture
}

test_confirm_advances_after_request() {
  _setup_transition_fixture
  _write_supervised_definition

  # Set up state as if --request already ran
  cat > "${WORK_DIR}/state.json" << JSON
{
  "name": "${_unit_name}",
  "title": "test",
  "description": "test",
  "step": "ideate",
  "step_status": "pending_approval",
  "steps_sequence": ["ideate","research","plan","spec","decompose","implement","review"],
  "deliverables": {},
  "gates": [{"boundary": "ideate->research", "outcome": "pass", "decided_by": "manual", "evidence": "test", "timestamp": "2026-01-01T00:00:00Z"}],
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

  _run_transition --confirm "$_unit_name"

  assert_exit_code "confirm exits 0" 0 "$_exit_code"
  assert_json_field "step advanced to research" "${WORK_DIR}/state.json" \
    '.step' "research"
  assert_json_field "step_status is not_started" "${WORK_DIR}/state.json" \
    '.step_status' "not_started"

  teardown_fixture
}

test_confirm_rejects_without_request() {
  _setup_transition_fixture
  _write_supervised_definition
  _write_transition_state "ideate" '{}'

  _run_transition --confirm "$_unit_name"

  assert_exit_code "confirm without request exits 5" 5 "$_exit_code"
  assert_file_contains "stderr mentions pending_approval" "$_stderr_file" \
    "expected 'pending_approval'"

  teardown_fixture
}

test_confirm_rejects_policy_violation() {
  _setup_transition_fixture
  _write_supervised_definition

  # State with pending_approval but decided_by=evaluated (violates supervised policy)
  cat > "${WORK_DIR}/state.json" << JSON
{
  "name": "${_unit_name}",
  "title": "test",
  "description": "test",
  "step": "ideate",
  "step_status": "pending_approval",
  "steps_sequence": ["ideate","research","plan","spec","decompose","implement","review"],
  "deliverables": {},
  "gates": [{"boundary": "ideate->research", "outcome": "pass", "decided_by": "evaluated", "evidence": "test", "timestamp": "2026-01-01T00:00:00Z"}],
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

  _run_transition --confirm "$_unit_name"

  assert_exit_code "policy violation exits 6" 6 "$_exit_code"
  assert_file_contains "stderr mentions policy violation" "$_stderr_file" \
    "Policy violation"

  teardown_fixture
}

test_request_delegated_completes_inline() {
  _setup_transition_fixture
  _write_transition_state "ideate" '{}'
  _write_delegated_definition

  cat > "${WORK_DIR}/summary.md" << 'MD'
# Test Summary
## Task
test
## Current State
test
## Artifact Paths
test
## Settled Decisions
test
## Context Budget
test
## Key Findings
- finding one
## Open Questions
- question one
## Recommendations
- rec one
MD

  ln -sf "${FURROW_ROOT}/hooks/validate-summary.sh" "${FIXTURE_DIR}/hooks/validate-summary.sh"

  _run_transition --request "$_unit_name" "pass" "manual" "test evidence"

  assert_exit_code "delegated request exits 0" 0 "$_exit_code"
  # Delegated mode should complete inline (no pending_approval)
  assert_json_field "step advanced to research" "${WORK_DIR}/state.json" \
    '.step' "research"
  assert_json_field "step_status is not_started" "${WORK_DIR}/state.json" \
    '.step_status' "not_started"

  teardown_fixture
}
