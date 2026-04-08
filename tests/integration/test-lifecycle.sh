#!/bin/bash
# test-lifecycle.sh — End-to-end integration test across sds, rws, alm
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=helpers.sh
. "${SCRIPT_DIR}/helpers.sh"

echo "=== test-lifecycle.sh ==="

# --- Setup ---

setup_test_env
cd "$TEST_DIR"

# Initialize seeds
sds init --prefix lifecycle-test

# Create almanac with empty todos
mkdir -p .furrow/almanac
printf '[]' > .furrow/almanac/todos.yaml

# Create definition.yaml helper
_write_definition() {
  _def_dir="$1"
  cat > "${_def_dir}/definition.yaml" << 'YAML'
objective: "lifecycle test objective"
deliverables:
  - name: lifecycle-deliverable
    specialist: test-eng
    acceptance_criteria:
      - "lifecycle test passes"
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

# -- Step 1: Create TODO via alm --
test_create_todo() {
  echo "  --- test_create_todo ---"

  slug=$(alm add --title "Lifecycle Test" --context "E2E" --work "Complete lifecycle")
  assert_not_empty "TODO created with slug" "$slug"

  # Store slug for later use
  echo "$slug" > "${TEST_DIR}/.test_todo_slug"
}

# -- Step 2: Create row from TODO --
test_create_row_from_todo() {
  echo "  --- test_create_row_from_todo ---"

  todo_slug=$(cat "${TEST_DIR}/.test_todo_slug")

  rws init lifecycle-row --title "Lifecycle Test" --source-todo "$todo_slug"
  assert_file_exists "row state.json created" ".furrow/rows/lifecycle-row/state.json"

  state_file=".furrow/rows/lifecycle-row/state.json"

  # Verify seed created and linked
  seed_id=$(jq -r '.seed_id' "$state_file")
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -n "$seed_id" ] && [ "$seed_id" != "null" ]; then
    printf "  PASS: seed linked to row (id=%s)\n" "$seed_id"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: seed_id is null or empty after init\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Verify seed status is claimed
  seed_status=$(sds show "$seed_id" --json | jq -r '.status')
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$seed_status" = "claimed" ]; then
    printf "  PASS: seed status is claimed\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: seed status expected 'claimed', got '%s'\n" "$seed_status" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Store seed_id for later
  echo "$seed_id" > "${TEST_DIR}/.test_seed_id"
}

# -- Step 3: Transition ideate -> research --
test_transition_ideate_research() {
  echo "  --- test_transition_ideate_research ---"

  state_file=".furrow/rows/lifecycle-row/state.json"
  seed_id=$(cat "${TEST_DIR}/.test_seed_id")

  # Write definition.yaml (needed for ideate->research artifact validation)
  _write_definition ".furrow/rows/lifecycle-row"

  # Single-command transition (records gate, validates, and advances atomically)
  rws transition lifecycle-row pass manual "ideation complete"
  assert_json_field "step is research" "$state_file" '.step' "research"

  # Verify seed synced to researching
  seed_status=$(sds show "$seed_id" --json | jq -r '.status')
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$seed_status" = "researching" ]; then
    printf "  PASS: seed synced to researching after ideate->research\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: seed status expected 'researching', got '%s'\n" "$seed_status" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- Step 4: Transition research -> plan --
test_transition_research_plan() {
  echo "  --- test_transition_research_plan ---"

  state_file=".furrow/rows/lifecycle-row/state.json"
  seed_id=$(cat "${TEST_DIR}/.test_seed_id")
  row_dir=".furrow/rows/lifecycle-row"

  # Create research.md artifact (needed for research->plan validation)
  cat > "${row_dir}/research.md" << 'MD'
# Research Findings

## Architecture Analysis
Found relevant patterns in the codebase.

## Prior Art
Existing solutions reviewed.
MD

  # Write summary.md with required sections so summary validation passes
  cat > "${row_dir}/summary.md" << 'MD'
# Lifecycle Test -- Summary

## Task
Lifecycle test objective

## Current State
Step: research | Status: in_progress

## Artifact Paths
- definition.yaml

## Settled Decisions
- No gates recorded yet

## Context Budget
Not measured

## Key Findings
Found relevant patterns.

## Open Questions
- What about edge cases?

## Recommendations
Proceed with implementation.
MD

  # Single-command transition
  rws transition lifecycle-row pass manual "research complete"
  assert_json_field "step is plan" "$state_file" '.step' "plan"

  # Verify seed synced to planning
  seed_status=$(sds show "$seed_id" --json | jq -r '.status')
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$seed_status" = "planning" ]; then
    printf "  PASS: seed synced to planning after research->plan\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: seed status expected 'planning', got '%s'\n" "$seed_status" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- Step 5: Gate check --
test_gate_check() {
  echo "  --- test_gate_check ---"

  state_file=".furrow/rows/lifecycle-row/state.json"

  # Verify gates were recorded
  gate_count=$(jq '.gates | length' "$state_file")
  assert_ge "at least 2 gates recorded" "$gate_count" 2

  # Verify gate boundaries
  boundaries=$(jq -r '[.gates[] | .boundary] | join(",")' "$state_file")
  assert_output_contains "ideate->research gate" "$boundaries" "ideate->research"
  assert_output_contains "research->plan gate" "$boundaries" "research->plan"
}

# --- Run all tests ---

test_create_todo
test_create_row_from_todo
test_transition_ideate_research
test_transition_research_plan
test_gate_check

# --- Summary ---

print_summary
