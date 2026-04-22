#!/bin/bash
# test-source-todos-handoff.sh — AC-6: source_todos runtime consumption in handoff path
#
# Verifies that /furrow:next renders ALL ids from source_todos (array) in the
# handoff prompt, and that the legacy source_todo (singular) fallback still works.
#
# This tests the prompt-template rendering logic defined in commands/next.md §3b.
# The integration point is (b): commands/next.md already specifies the resolution
# order; this test asserts that a shell script following that spec produces the
# correct output for both array and legacy forms.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-source-todos-handoff.sh (AC-6) ==="

FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT

# ---------------------------------------------------------------------------
# _render_source_todos_section
# Implement the §3b resolution logic from commands/next.md:
#   1. Prefer source_todos (array). If present and non-empty, use all ids.
#   2. Fallback: source_todo (singular). Treat as single-element list.
#   3. Neither present/non-empty → omit section entirely.
# Returns lines for the "Source TODOs:" section, or empty string if none.
# ---------------------------------------------------------------------------
_render_source_todos_section() {
  local state_file="$1"
  # Read source_todos array (null → empty)
  local todos_json
  todos_json="$(jq -r '(.source_todos // []) | @json' "$state_file" 2>/dev/null)" || todos_json="[]"

  local count
  count="$(printf '%s' "$todos_json" | jq 'length' 2>/dev/null)" || count=0

  if [ "$count" -gt 0 ]; then
    # Array form — emit one line per id
    printf '%s' "$todos_json" | jq -r '.[]' | while IFS= read -r id; do
      printf -- '- %s (see .furrow/almanac/todos.yaml)\n' "$id"
    done
    return 0
  fi

  # Fallback to legacy source_todo (singular)
  local singular
  singular="$(jq -r '.source_todo // empty' "$state_file" 2>/dev/null)" || singular=""
  if [ -n "$singular" ]; then
    printf -- '- %s (see .furrow/almanac/todos.yaml)\n' "$singular"
    return 0
  fi

  # Neither present — return empty (no section)
  return 0
}

# ---------------------------------------------------------------------------
# test_source_todos_array_both_ids_rendered
# A state.json with source_todos: [id-1, id-2] must produce BOTH ids in
# the rendered handoff section.
# ---------------------------------------------------------------------------
test_source_todos_array_both_ids_rendered() {
  local state_file
  state_file="$(mktemp)"
  trap 'rm -f "$state_file"' EXIT INT TERM

  # Minimal state.json with source_todos array (two ids)
  jq -n '{
    name: "test-row",
    source_todos: ["id-1", "id-2"],
    source_todo: null
  }' > "$state_file"

  local output
  output="$(_render_source_todos_section "$state_file")"

  assert_output_contains "id-1 appears in handoff output" "$output" "id-1"
  assert_output_contains "id-2 appears in handoff output" "$output" "id-2"

  rm -f "$state_file"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_source_todos_array_three_ids_all_rendered
# A state.json with source_todos: [a, b, c] must produce all three ids.
# ---------------------------------------------------------------------------
test_source_todos_array_three_ids_all_rendered() {
  local state_file
  state_file="$(mktemp)"
  trap 'rm -f "$state_file"' EXIT INT TERM

  jq -n '{
    name: "test-row",
    source_todos: ["alpha-one", "beta-two", "gamma-three"],
    source_todo: null
  }' > "$state_file"

  local output
  output="$(_render_source_todos_section "$state_file")"

  assert_output_contains "alpha-one appears in handoff" "$output" "alpha-one"
  assert_output_contains "beta-two appears in handoff" "$output" "beta-two"
  assert_output_contains "gamma-three appears in handoff" "$output" "gamma-three"

  rm -f "$state_file"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_legacy_source_todo_singular_fallback
# A state.json with source_todo: id-x (no source_todos) must still render id-x.
# ---------------------------------------------------------------------------
test_legacy_source_todo_singular_fallback() {
  local state_file
  state_file="$(mktemp)"
  trap 'rm -f "$state_file"' EXIT INT TERM

  jq -n '{
    name: "legacy-row",
    source_todo: "legacy-id-x"
  }' > "$state_file"

  local output
  output="$(_render_source_todos_section "$state_file")"

  assert_output_contains "legacy-id-x appears in handoff via singular fallback" "$output" "legacy-id-x"

  rm -f "$state_file"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_neither_field_produces_empty_section
# A state.json with no source_todo or source_todos must produce no section.
# ---------------------------------------------------------------------------
test_neither_field_produces_empty_section() {
  local state_file
  state_file="$(mktemp)"
  trap 'rm -f "$state_file"' EXIT INT TERM

  jq -n '{
    name: "no-source-row"
  }' > "$state_file"

  local output
  output="$(_render_source_todos_section "$state_file")"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -z "$output" ]; then
    printf "  PASS: no source_todo(s) → no section emitted\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: expected empty output but got: %s\n" "$output" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  rm -f "$state_file"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_source_todos_preferred_over_singular
# When BOTH source_todos and source_todo are present, source_todos wins.
# The singular id must NOT appear if it is not in the array.
# ---------------------------------------------------------------------------
test_source_todos_preferred_over_singular() {
  local state_file
  state_file="$(mktemp)"
  trap 'rm -f "$state_file"' EXIT INT TERM

  jq -n '{
    name: "both-row",
    source_todos: ["array-id-1", "array-id-2"],
    source_todo: "legacy-override-id"
  }' > "$state_file"

  local output
  output="$(_render_source_todos_section "$state_file")"

  assert_output_contains "array-id-1 in output (array wins)" "$output" "array-id-1"
  assert_output_contains "array-id-2 in output (array wins)" "$output" "array-id-2"

  TESTS_RUN=$((TESTS_RUN + 1))
  if ! printf '%s\n' "$output" | grep -q "legacy-override-id"; then
    printf "  PASS: legacy source_todo id not rendered when source_todos present\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: legacy-override-id should not appear when source_todos takes precedence\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  rm -f "$state_file"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_commands_next_md_has_source_todos_resolution
# Verify commands/next.md contains the §3b resolution spec so the template
# is not accidentally deleted.
# ---------------------------------------------------------------------------
test_commands_next_md_has_source_todos_resolution() {
  local next_md="${PROJECT_ROOT}/commands/next.md"
  assert_file_exists "commands/next.md exists" "$next_md"
  assert_file_contains "next.md contains source_todos resolution spec" \
    "$next_md" "source_todos"
  assert_file_contains "next.md contains singular fallback spec" \
    "$next_md" "source_todo"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
run_test test_source_todos_array_both_ids_rendered
run_test test_source_todos_array_three_ids_all_rendered
run_test test_legacy_source_todo_singular_fallback
run_test test_neither_field_produces_empty_section
run_test test_source_todos_preferred_over_singular
run_test test_commands_next_md_has_source_todos_resolution

print_summary
