#!/bin/bash
# test-correction-limit.sh — Integration tests for hooks/correction-limit.sh
#
# Sourced by the test runner. Requires helpers.sh (provides setup_fixture,
# teardown_fixture, assert_exit_code, assert_file_exists, assert_file_contains,
# assert_file_not_contains, assert_json_field, FURROW_ROOT).

# --- helper: create fixture with symlinked hooks and a complete work unit ---

_unit_name="__test-corr-limit"

_setup_corr_fixture() {
  setup_fixture "$_unit_name"

  # Symlink hooks so the script resolves FURROW_ROOT to FIXTURE_DIR
  mkdir -p "${FIXTURE_DIR}/hooks/lib"
  ln -sf "${FURROW_ROOT}/hooks/correction-limit.sh" "${FIXTURE_DIR}/hooks/correction-limit.sh"
  ln -sf "${FURROW_ROOT}/hooks/lib/common.sh" "${FIXTURE_DIR}/hooks/lib/common.sh"

  # Create .focused file so find_focused_work_unit() finds our unit
  echo "$_unit_name" > "${FIXTURE_DIR}/.work/.focused"

  # Write plan.json with file_ownership globs
  cat > "${WORK_DIR}/plan.json" << 'JSON'
{
  "waves": [
    {
      "wave": 1,
      "deliverables": ["api"],
      "assignments": {
        "api": {
          "specialist": "test-eng",
          "file_ownership": ["src/api/*.js"],
          "skills": []
        }
      }
    }
  ],
  "created_at": "2026-01-01T00:00:00Z",
  "created_by": "test"
}
JSON
}

# Write state.json with configurable step and corrections count.
# Args: $1 = step, $2 = corrections
_write_state() {
  _step="$1"
  _corrections="$2"

  cat > "${WORK_DIR}/state.json" << JSON
{
  "name": "${_unit_name}",
  "title": "Test correction limit",
  "description": "Integration test fixture",
  "step": "${_step}",
  "step_status": "in_progress",
  "steps_sequence": ["ideate","research","plan","spec","decompose","implement","review"],
  "deliverables": {
    "api": {
      "status": "in_progress",
      "assigned_to": "test-eng",
      "wave": 1,
      "corrections": ${_corrections}
    }
  },
  "gates": [],
  "force_stop_at": null,
  "branch": "work/test",
  "mode": "feature",
  "base_commit": "abc123",
  "epic_id": null,
  "issue_id": null,
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z",
  "archived_at": null
}
JSON
}

# Run the hook from inside FIXTURE_DIR (so .work/ paths resolve) with stdin.
# Args: $1 = JSON string for stdin
# Sets: _exit_code, _stderr_file
_run_hook() {
  _stdin_json="$1"
  _exit_code=0
  _stderr_file="${FIXTURE_DIR}/stderr.txt"

  printf '%s' "$_stdin_json" | \
    (cd "${FIXTURE_DIR}" && "${FIXTURE_DIR}/hooks/correction-limit.sh") \
    2>"$_stderr_file" || _exit_code=$?
}

# --- test functions ---

test_at_limit_blocked() {
  _setup_corr_fixture
  _write_state "implement" 3

  _run_hook '{"tool_name":"Write","tool_input":{"file_path":"src/api/handler.js"}}'

  assert_exit_code "at-limit blocked" 2 "$_exit_code"
  assert_file_contains "stderr has correction limit msg" "$_stderr_file" "Correction limit"

  teardown_fixture
}

test_under_limit_allowed() {
  _setup_corr_fixture
  _write_state "implement" 1

  _run_hook '{"tool_name":"Write","tool_input":{"file_path":"src/api/handler.js"}}'

  assert_exit_code "under-limit allowed" 0 "$_exit_code"

  teardown_fixture
}

test_unowned_file_passes() {
  _setup_corr_fixture
  _write_state "implement" 3

  _run_hook '{"tool_name":"Write","tool_input":{"file_path":"README.md"}}'

  assert_exit_code "unowned file passes" 0 "$_exit_code"

  teardown_fixture
}

test_non_implement_step_skips() {
  _setup_corr_fixture
  _write_state "review" 3

  _run_hook '{"tool_name":"Write","tool_input":{"file_path":"src/api/handler.js"}}'

  assert_exit_code "non-implement step skips" 0 "$_exit_code"

  teardown_fixture
}

test_filepath_field_variant() {
  _setup_corr_fixture
  _write_state "implement" 3

  _run_hook '{"tool_name":"Edit","tool_input":{"filePath":"src/api/handler.js"}}'

  assert_exit_code "filePath variant blocked" 2 "$_exit_code"
  assert_file_contains "stderr has correction limit msg" "$_stderr_file" "Correction limit"

  teardown_fixture
}

test_custom_correction_limit() {
  _setup_corr_fixture
  _write_state "implement" 2

  # Set custom correction limit of 2 via furrow.yaml
  mkdir -p "${FIXTURE_DIR}/.claude"
  cat > "${FIXTURE_DIR}/.claude/furrow.yaml" << 'YAML'
defaults:
  correction_limit: 2
YAML

  _run_hook '{"tool_name":"Write","tool_input":{"file_path":"src/api/handler.js"}}'

  assert_exit_code "custom limit=2 blocks at corrections=2" 2 "$_exit_code"
  assert_file_contains "stderr has correction limit msg" "$_stderr_file" "Correction limit (2)"

  teardown_fixture
}
