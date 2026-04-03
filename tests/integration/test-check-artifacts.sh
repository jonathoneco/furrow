#!/bin/bash
# test-check-artifacts.sh — Integration tests for scripts/check-artifacts.sh
#
# Sourced by the test runner. Requires helpers.sh (provides setup_fixture,
# teardown_fixture, assert_exit_code, assert_file_exists, assert_json_field,
# FURROW_ROOT).

# --- helper: set up symlink structure so check-artifacts.sh resolves FURROW_ROOT to FIXTURE_DIR ---

_setup_artifacts_fixture() {
  _name="$1"
  setup_fixture "$_name"

  mkdir -p "${FIXTURE_DIR}/scripts" "${FIXTURE_DIR}/hooks/lib"
  ln -sf "${FURROW_ROOT}/scripts/check-artifacts.sh" "${FIXTURE_DIR}/scripts/check-artifacts.sh"
  ln -sf "${FURROW_ROOT}/hooks/lib/validate.sh" "${FIXTURE_DIR}/hooks/lib/validate.sh"
}

# --- helper: write a minimal valid state.json ---

_write_state_json() {
  _state_dir="$1"
  _name="$2"
  _mode="$3"
  _base_commit="$4"

  cat > "${_state_dir}/state.json" << JSON
{
  "name": "${_name}",
  "title": "test",
  "description": "test",
  "step": "implement",
  "step_status": "in_progress",
  "steps_sequence": ["ideate","research","plan","spec","decompose","implement","review"],
  "deliverables": {},
  "gates": [],
  "force_stop_at": null,
  "branch": null,
  "mode": "${_mode}",
  "base_commit": "${_base_commit}",
  "epic_id": null,
  "issue_id": null,
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z",
  "archived_at": null
}
JSON
}

# --- helper: write a minimal valid definition.yaml ---

_write_definition_yaml() {
  _def_dir="$1"
  _deliverable="$2"

  cat > "${_def_dir}/definition.yaml" << YAML
objective: "test"
deliverables:
  - name: ${_deliverable}
    specialist: test-eng
    acceptance_criteria:
      - "api endpoint works"
    file_ownership:
      - "src/*.sh"
context_pointers:
  - path: test
    note: test
constraints: []
gate_policy: supervised
YAML
}

# --- helper: write a minimal valid plan.json ---

_write_plan_json() {
  _plan_dir="$1"
  _deliverable="$2"

  cat > "${_plan_dir}/plan.json" << JSON
{
  "waves": [{"wave": 1, "deliverables": ["${_deliverable}"], "assignments": {"${_deliverable}": {"specialist": "test-eng", "file_ownership": ["src/*.sh"], "skills": []}}}],
  "created_at": "2026-01-01T00:00:00Z",
  "created_by": "test"
}
JSON
}

# --- test functions ---

test_code_mode_pass() {
  _setup_artifacts_fixture "__test-artifacts-code-pass"

  # Initialize git repo in fixture
  (cd "${FIXTURE_DIR}" && git init -q && git config user.email "test@test.com" && git config user.name "Test")

  # Create initial content and commit (base)
  mkdir -p "${FIXTURE_DIR}/src"
  echo "initial" > "${FIXTURE_DIR}/src/placeholder.sh"
  (cd "${FIXTURE_DIR}" && git add -A && git commit -q -m "initial")
  base_sha="$(cd "${FIXTURE_DIR}" && git rev-parse HEAD)"

  _write_definition_yaml "${WORK_DIR}" "api"
  _write_plan_json "${WORK_DIR}" "api"
  _write_state_json "${WORK_DIR}" "__test-artifacts-code-pass" "code" "${base_sha}"

  # Make changes after base commit so git diff finds them
  echo "new content" > "${FIXTURE_DIR}/src/new-file.sh"
  (cd "${FIXTURE_DIR}" && git add -A && git commit -q -m "add new file")

  # Run from within fixture dir so git commands work
  exit_code=0
  (cd "${FIXTURE_DIR}" && "${FIXTURE_DIR}/scripts/check-artifacts.sh" "__test-artifacts-code-pass" "api") > /dev/null 2>&1 || exit_code=$?

  assert_exit_code "code mode with owned changes passes" 0 "$exit_code"
  assert_file_exists "phase-a results written" "${WORK_DIR}/reviews/phase-a-results.json"
  assert_json_field "verdict is pass" "${WORK_DIR}/reviews/phase-a-results.json" '.verdict' "pass"
  assert_json_field "artifacts present" "${WORK_DIR}/reviews/phase-a-results.json" '.artifacts_present' "true"

  teardown_fixture
}

test_code_mode_no_changes() {
  _setup_artifacts_fixture "__test-artifacts-no-change"

  # Initialize git repo in fixture
  (cd "${FIXTURE_DIR}" && git init -q && git config user.email "test@test.com" && git config user.name "Test")

  # Create initial content and commit (base) — no further commits after this
  mkdir -p "${FIXTURE_DIR}/src"
  echo "initial" > "${FIXTURE_DIR}/src/placeholder.sh"
  (cd "${FIXTURE_DIR}" && git add -A && git commit -q -m "initial")
  base_sha="$(cd "${FIXTURE_DIR}" && git rev-parse HEAD)"

  _write_definition_yaml "${WORK_DIR}" "api"
  _write_plan_json "${WORK_DIR}" "api"
  _write_state_json "${WORK_DIR}" "__test-artifacts-no-change" "code" "${base_sha}"

  exit_code=0
  (cd "${FIXTURE_DIR}" && "${FIXTURE_DIR}/scripts/check-artifacts.sh" "__test-artifacts-no-change" "api") > /dev/null 2>&1 || exit_code=$?

  assert_exit_code "code mode with no changes fails" 1 "$exit_code"
  assert_file_exists "phase-a results written" "${WORK_DIR}/reviews/phase-a-results.json"
  assert_json_field "verdict is fail" "${WORK_DIR}/reviews/phase-a-results.json" '.verdict' "fail"
  assert_json_field "artifacts not present" "${WORK_DIR}/reviews/phase-a-results.json" '.artifacts_present' "false"

  teardown_fixture
}

test_research_mode_pass() {
  _setup_artifacts_fixture "__test-artifacts-research"

  _write_definition_yaml "${WORK_DIR}" "api"
  _write_state_json "${WORK_DIR}" "__test-artifacts-research" "research" ""

  # Create deliverables directory with a non-empty file
  mkdir -p "${WORK_DIR}/deliverables"
  echo "Research findings about the API." > "${WORK_DIR}/deliverables/findings.md"

  exit_code=0
  "${FIXTURE_DIR}/scripts/check-artifacts.sh" "__test-artifacts-research" "api" > /dev/null 2>&1 || exit_code=$?

  assert_exit_code "research mode with deliverables passes" 0 "$exit_code"
  assert_file_exists "phase-a results written" "${WORK_DIR}/reviews/phase-a-results.json"
  assert_json_field "verdict is pass" "${WORK_DIR}/reviews/phase-a-results.json" '.verdict' "pass"
  assert_json_field "artifacts present" "${WORK_DIR}/reviews/phase-a-results.json" '.artifacts_present' "true"
  assert_json_field "mode is research" "${WORK_DIR}/reviews/phase-a-results.json" '.mode' "research"

  teardown_fixture
}

test_research_mode_empty() {
  _setup_artifacts_fixture "__test-artifacts-research-empty"

  _write_definition_yaml "${WORK_DIR}" "api"
  _write_state_json "${WORK_DIR}" "__test-artifacts-research-empty" "research" ""

  # Create deliverables directory with only an empty file
  mkdir -p "${WORK_DIR}/deliverables"
  touch "${WORK_DIR}/deliverables/empty.md"

  exit_code=0
  "${FIXTURE_DIR}/scripts/check-artifacts.sh" "__test-artifacts-research-empty" "api" > /dev/null 2>&1 || exit_code=$?

  assert_exit_code "research mode with empty deliverables fails" 1 "$exit_code"
  assert_file_exists "phase-a results written" "${WORK_DIR}/reviews/phase-a-results.json"
  assert_json_field "verdict is fail" "${WORK_DIR}/reviews/phase-a-results.json" '.verdict' "fail"
  assert_json_field "artifacts not present" "${WORK_DIR}/reviews/phase-a-results.json" '.artifacts_present' "false"

  teardown_fixture
}

test_missing_base_commit() {
  _setup_artifacts_fixture "__test-artifacts-no-base"

  _write_definition_yaml "${WORK_DIR}" "api"
  _write_plan_json "${WORK_DIR}" "api"
  _write_state_json "${WORK_DIR}" "__test-artifacts-no-base" "code" ""

  exit_code=0
  "${FIXTURE_DIR}/scripts/check-artifacts.sh" "__test-artifacts-no-base" "api" > /dev/null 2>&1 || exit_code=$?

  assert_exit_code "code mode with missing base_commit fails" 1 "$exit_code"
  assert_file_exists "phase-a results written" "${WORK_DIR}/reviews/phase-a-results.json"
  assert_json_field "verdict is fail" "${WORK_DIR}/reviews/phase-a-results.json" '.verdict' "fail"
  assert_json_field "artifacts not present" "${WORK_DIR}/reviews/phase-a-results.json" '.artifacts_present' "false"

  teardown_fixture
}
