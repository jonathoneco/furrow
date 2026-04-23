#!/bin/bash
# test-sort-todos.sh — AC-E: sort invariant tests for todos.yaml
#
# Subtests:
#   sort_determinism   — shuffled todos.yaml → normalize → verify sorted
#   idempotent         — double normalize → zero diff
#   stable_ties        — two todos with same (created_at, id) retain relative order
#   cross_locale       — LC_ALL=en_US.UTF-8 outer shell; result identical to LC_ALL=C
#   validate_pass      — rws validate-sort-invariant exits 0 on sorted file
#   validate_fail      — scrambled file → rws validate-sort-invariant exits 3 + stderr

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-sort-todos.sh (AC-E: todos sort invariant) ==="

# ---------------------------------------------------------------------------
# Helper: write a todos.yaml entry (appends to existing YAML array)
# write_todo <id> <created_at> <title>
# ---------------------------------------------------------------------------
write_todos_yaml() {
  local todos_file="${TEST_DIR}/.furrow/almanac/todos.yaml"
  # Write complete YAML array of all passed entries
  printf '%s\n' "$1" > "$todos_file"
}

# Build a YAML array from arguments: each arg is "id|created_at|title"
# Output is a valid YAML block sequence (no leading "[")
build_todos_yaml() {
  local yaml=""
  for spec in "$@"; do
    local id created_at title
    id=$(printf '%s' "$spec" | cut -d'|' -f1)
    created_at=$(printf '%s' "$spec" | cut -d'|' -f2)
    title=$(printf '%s' "$spec" | cut -d'|' -f3-)
    yaml="${yaml}- id: ${id}
  title: \"${title}\"
  context: test
  work_needed: none
  source_type: manual
  status: active
  created_at: ${created_at}
  updated_at: ${created_at}
"
  done
  printf '%s' "$yaml"
}

# ---------------------------------------------------------------------------
# Check whether todos.yaml is sorted by (created_at, id)
assert_todos_sorted() {
  local desc="$1"
  local todos_file="${TEST_DIR}/.furrow/almanac/todos.yaml"

  local disk_ids sorted_ids
  disk_ids=$(yq -r '.[].id' "$todos_file" 2>/dev/null | tr '\n' ',')
  sorted_ids=$(yq -r 'sort_by(.created_at, .id) | .[].id' "$todos_file" 2>/dev/null | tr '\n' ',')

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$disk_ids" = "$sorted_ids" ]; then
    printf "  PASS: %s\n" "$desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s\n  disk:   %s\n  sorted: %s\n" "$desc" "$disk_ids" "$sorted_ids" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# ---------------------------------------------------------------------------
# sort_determinism
# ---------------------------------------------------------------------------
test_sort_determinism() {
  setup_test_env
  cd "$TEST_DIR"

  mkdir -p .furrow/almanac

  # Write 6 todos with shuffled timestamps
  build_todos_yaml \
    "todo-e|2024-05-05T00:00:00Z|Todo E" \
    "todo-a|2024-05-01T00:00:00Z|Todo A" \
    "todo-c|2024-05-03T00:00:00Z|Todo C" \
    "todo-f|2024-05-06T00:00:00Z|Todo F" \
    "todo-b|2024-05-02T00:00:00Z|Todo B" \
    "todo-d|2024-05-04T00:00:00Z|Todo D" \
    > .furrow/almanac/todos.yaml

  PROJECT_ROOT="$TEST_DIR" frw normalize-todos 2>/dev/null

  assert_todos_sorted "6 shuffled todos sorted correctly"

  # yq round-trip: sorted file should be stable after another yq pass
  local before after
  before=$(cat .furrow/almanac/todos.yaml)
  yq -o=yaml '.' .furrow/almanac/todos.yaml > /tmp/todos_roundtrip.$$ && mv /tmp/todos_roundtrip.$$ .furrow/almanac/todos.yaml
  after=$(cat .furrow/almanac/todos.yaml)
  # Restore before comparison (yq may change whitespace but sort order should hold)
  assert_todos_sorted "sorted order stable after yq round-trip"

  teardown_test_env
}

# ---------------------------------------------------------------------------
# idempotent
# ---------------------------------------------------------------------------
test_idempotent() {
  setup_test_env
  cd "$TEST_DIR"

  mkdir -p .furrow/almanac

  build_todos_yaml \
    "todo-c|2024-03-03T00:00:00Z|Third" \
    "todo-a|2024-03-01T00:00:00Z|First" \
    "todo-b|2024-03-02T00:00:00Z|Second" \
    > .furrow/almanac/todos.yaml

  PROJECT_ROOT="$TEST_DIR" frw normalize-todos 2>/dev/null
  local after_first
  after_first=$(cat .furrow/almanac/todos.yaml)

  PROJECT_ROOT="$TEST_DIR" frw normalize-todos 2>/dev/null
  local after_second
  after_second=$(cat .furrow/almanac/todos.yaml)

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$after_first" = "$after_second" ]; then
    printf "  PASS: idempotent — double normalize produces zero diff\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: second normalize changed the file\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  teardown_test_env
}

# ---------------------------------------------------------------------------
# stable_ties
# Two todos with identical (created_at, id) — both must survive, order stable.
# In practice identical keys are degenerate; we test idempotence of the sort.
# ---------------------------------------------------------------------------
test_stable_ties() {
  setup_test_env
  cd "$TEST_DIR"

  mkdir -p .furrow/almanac

  # Two entries with same created_at but same id (pathological)
  # yq will keep both; we verify both survive and order is stable.
  local same_ts="2024-06-01T00:00:00Z"
  cat > .furrow/almanac/todos.yaml << YAML
- id: todo-tie
  title: "Tie A"
  context: test
  work_needed: none
  source_type: manual
  status: active
  created_at: ${same_ts}
  updated_at: ${same_ts}
- id: todo-tie
  title: "Tie B"
  context: test
  work_needed: none
  source_type: manual
  status: active
  created_at: ${same_ts}
  updated_at: ${same_ts}
YAML

  PROJECT_ROOT="$TEST_DIR" frw normalize-todos 2>/dev/null
  local after_first
  after_first=$(cat .furrow/almanac/todos.yaml)

  local count
  count=$(yq -r 'length' .furrow/almanac/todos.yaml 2>/dev/null)
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$count" -eq 2 ]; then
    printf "  PASS: stable_ties — both tie entries survive normalize\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: stable_ties — expected 2 entries, got %s\n" "$count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  PROJECT_ROOT="$TEST_DIR" frw normalize-todos 2>/dev/null
  local after_second
  after_second=$(cat .furrow/almanac/todos.yaml)

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$after_first" = "$after_second" ]; then
    printf "  PASS: stable_ties — order stable across runs\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: stable_ties — order changed on second normalize\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  teardown_test_env
}

# ---------------------------------------------------------------------------
# cross_locale
# ---------------------------------------------------------------------------
test_cross_locale() {
  setup_test_env
  cd "$TEST_DIR"

  mkdir -p .furrow/almanac

  build_todos_yaml \
    "todo-b|2024-05-02T00:00:00Z|B" \
    "todo-a|2024-05-01T00:00:00Z|A" \
    "todo-c|2024-05-03T00:00:00Z|C" \
    > .furrow/almanac/todos.yaml

  # Run with LC_ALL=C
  LC_ALL=C PROJECT_ROOT="$TEST_DIR" frw normalize-todos 2>/dev/null
  local result_c
  result_c=$(cat .furrow/almanac/todos.yaml)

  # Rebuild same shuffled content
  build_todos_yaml \
    "todo-b|2024-05-02T00:00:00Z|B" \
    "todo-a|2024-05-01T00:00:00Z|A" \
    "todo-c|2024-05-03T00:00:00Z|C" \
    > .furrow/almanac/todos.yaml

  # Run with LC_ALL=en_US.UTF-8
  LC_ALL=en_US.UTF-8 PROJECT_ROOT="$TEST_DIR" frw normalize-todos 2>/dev/null
  local result_utf8
  result_utf8=$(cat .furrow/almanac/todos.yaml)

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$result_c" = "$result_utf8" ]; then
    printf "  PASS: cross_locale — LC_ALL=en_US.UTF-8 produces same result as LC_ALL=C\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: cross_locale — locale difference changed output\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  teardown_test_env
}

# ---------------------------------------------------------------------------
# validate_pass
# ---------------------------------------------------------------------------
test_validate_pass() {
  setup_test_env
  cd "$TEST_DIR"

  mkdir -p .furrow/almanac

  build_todos_yaml \
    "todo-a|2024-01-01T00:00:00Z|First" \
    "todo-b|2024-01-02T00:00:00Z|Second" \
    > .furrow/almanac/todos.yaml

  local exit_code=0
  rws validate-sort-invariant --file .furrow/almanac/todos.yaml >/dev/null 2>&1 || exit_code=$?

  assert_exit_code "validate-sort-invariant exits 0 on sorted todos.yaml" 0 "$exit_code"

  teardown_test_env
}

# ---------------------------------------------------------------------------
# validate_fail
# ---------------------------------------------------------------------------
test_validate_fail() {
  setup_test_env
  cd "$TEST_DIR"

  mkdir -p .furrow/almanac

  # Write in REVERSE order (out-of-sort)
  build_todos_yaml \
    "todo-b|2024-01-02T00:00:00Z|Second" \
    "todo-a|2024-01-01T00:00:00Z|First" \
    > .furrow/almanac/todos.yaml

  local exit_code=0
  local stderr_out
  stderr_out=$(rws validate-sort-invariant --file .furrow/almanac/todos.yaml 2>&1 >/dev/null) || exit_code=$?

  assert_exit_code "validate-sort-invariant exits 3 on scrambled todos.yaml" 3 "$exit_code"
  assert_output_contains "stderr contains 'sort-invariant violated'" "$stderr_out" "sort-invariant violated"

  teardown_test_env
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
echo ""
echo "--- sort_determinism ---"
test_sort_determinism

echo ""
echo "--- idempotent ---"
test_idempotent

echo ""
echo "--- stable_ties ---"
test_stable_ties

echo ""
echo "--- cross_locale ---"
test_cross_locale

echo ""
echo "--- validate_pass ---"
test_validate_pass

echo ""
echo "--- validate_fail ---"
test_validate_fail

print_summary
