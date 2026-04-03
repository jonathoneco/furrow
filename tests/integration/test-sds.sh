#!/bin/bash
# test-sds.sh — Integration tests for sds CLI
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=helpers.sh
. "${SCRIPT_DIR}/helpers.sh"

echo "=== test-sds.sh ==="

# --- Setup ---

setup_test_env
cd "$TEST_DIR"

# --- Tests ---

# -- init --
test_init() {
  echo "  --- test_init ---"

  sds init --prefix test-proj
  assert_file_exists "config created" ".furrow/seeds/config"
  assert_file_exists "seeds.jsonl created" ".furrow/seeds/seeds.jsonl"
  assert_file_contains "prefix stored" ".furrow/seeds/config" "test-proj"
}

# -- create --
test_create() {
  echo "  --- test_create ---"

  id=$(sds create --title "Test seed" --type task)
  assert_not_empty "create returns ID" "$id"

  # Show with --json
  status=$(sds show "$id" --json | jq -r '.status')
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$status" = "open" ]; then
    printf "  PASS: new seed status is open\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: new seed status expected 'open', got '%s'\n" "$status" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- show --json --
test_show_json() {
  echo "  --- test_show_json ---"

  id=$(sds create --title "Show test" --type bug --priority 1 --description "A bug")
  assert_not_empty "create for show" "$id"

  output=$(sds show "$id" --json)
  actual_title=$(printf '%s' "$output" | jq -r '.title')
  actual_type=$(printf '%s' "$output" | jq -r '.type')
  actual_priority=$(printf '%s' "$output" | jq -r '.priority')

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$actual_title" = "Show test" ] && [ "$actual_type" = "bug" ] && [ "$actual_priority" = "1" ]; then
    printf "  PASS: show --json returns correct fields\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: show --json fields mismatch (title=%s type=%s priority=%s)\n" "$actual_title" "$actual_type" "$actual_priority" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- update with all valid statuses --
test_update_statuses() {
  echo "  --- test_update_statuses ---"

  id=$(sds create --title "Status test" --type task)

  for status in claimed ideating researching planning speccing decomposing implementing reviewing; do
    sds update "$id" --status "$status"
    actual=$(sds show "$id" --json | jq -r '.status')
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$actual" = "$status" ]; then
      printf "  PASS: update --status %s\n" "$status"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf "  FAIL: update --status %s (got '%s')\n" "$status" "$actual" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  done
}

# -- invalid status rejected --
test_invalid_status_rejected() {
  echo "  --- test_invalid_status_rejected ---"

  id=$(sds create --title "Invalid status test" --type task)

  ec=0
  sds update "$id" --status "in_progress" 2>/dev/null || ec=$?
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$ec" -ne 0 ]; then
    printf "  PASS: in_progress status rejected (exit %s)\n" "$ec"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: in_progress status should have been rejected\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- close --
test_close() {
  echo "  --- test_close ---"

  id=$(sds create --title "Close test" --type task)
  sds close "$id" --reason "test complete"

  actual=$(sds show "$id" --json | jq -r '.status')
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$actual" = "closed" ]; then
    printf "  PASS: close sets status to closed\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: close expected 'closed', got '%s'\n" "$actual" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  reason=$(sds show "$id" --json | jq -r '.close_reason')
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$reason" = "test complete" ]; then
    printf "  PASS: close_reason stored\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: close_reason expected 'test complete', got '%s'\n" "$reason" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- list --json --
test_list() {
  echo "  --- test_list ---"

  # Count seeds created so far (at least 5 from previous tests)
  count=$(sds list --json | wc -l)
  assert_ge "list returns multiple seeds" "$count" 2
}

# -- ready (dependency filtering) --
test_ready() {
  echo "  --- test_ready ---"

  id_a=$(sds create --title "Dep A" --type task)
  id_b=$(sds create --title "Dep B" --type task)
  sds dep add "$id_b" "$id_a"

  # id_b should NOT appear in ready (blocked by id_a)
  ready_output=$(sds ready --json 2>/dev/null || true)
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s\n' "$ready_output" | grep -q "\"id\":\"${id_b}\""; then
    printf "  FAIL: blocked seed %s should not appear in ready\n" "$id_b" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    printf "  PASS: blocked seed not in ready output\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi

  # Close id_a, now id_b should appear
  sds close "$id_a"
  ready_output=$(sds ready --json 2>/dev/null || true)
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s\n' "$ready_output" | grep -q "\"id\":\"${id_b}\""; then
    printf "  PASS: unblocked seed appears in ready\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: unblocked seed %s should appear in ready\n" "$id_b" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- dep add / dep rm --
test_dep_add_rm() {
  echo "  --- test_dep_add_rm ---"

  id_x=$(sds create --title "Dep X" --type task)
  id_y=$(sds create --title "Dep Y" --type task)

  # Add dependency
  sds dep add "$id_y" "$id_x"
  deps=$(sds show "$id_y" --json | jq -r '.depends_on[]')
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s\n' "$deps" | grep -q "$id_x"; then
    printf "  PASS: dep add sets depends_on\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: dep add did not set depends_on\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Remove dependency
  sds dep rm "$id_y" "$id_x"
  dep_count=$(sds show "$id_y" --json | jq '.depends_on | length')
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$dep_count" = "0" ]; then
    printf "  PASS: dep rm removes dependency\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: dep rm did not remove dependency (count=%s)\n" "$dep_count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# -- search --
test_search() {
  echo "  --- test_search ---"

  sds create --title "Searchable needle" --type feature > /dev/null

  output=$(sds search "needle" --json)
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s\n' "$output" | grep -q "needle"; then
    printf "  PASS: search finds seed by keyword\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: search did not find 'needle'\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# --- Run all tests ---

test_init
test_create
test_show_json
test_update_statuses
test_invalid_status_rejected
test_close
test_list
test_ready
test_dep_add_rm
test_search

# --- Summary ---

print_summary
