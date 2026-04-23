#!/bin/bash
# test-sort-seeds.sh — AC-E: sort invariant tests for seeds.jsonl
#
# Subtests:
#   sort_determinism   — 10 shuffled seeds → normalize → verify sorted + byte-identical
#   idempotent         — double normalize → zero diff
#   stable_ties        — two seeds with same (created_at, id) retain insertion order
#   cross_locale       — LC_ALL=en_US.UTF-8 outer shell; normalize result matches LC_ALL=C
#   validate_pass      — rws validate-sort-invariant exits 0 on sorted file
#   validate_fail      — scrambled file → rws validate-sort-invariant exits 3 + stderr

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-sort-seeds.sh (AC-E: seeds sort invariant) ==="

# ---------------------------------------------------------------------------
# Helper: write N seeds with given timestamps to seeds.jsonl (no normalization)
# write_seed <created_at> <id> <title>
# ---------------------------------------------------------------------------
write_seed() {
  local created_at="$1"
  local id="$2"
  local title="$3"
  local seeds_file="${TEST_DIR}/.furrow/seeds/seeds.jsonl"
  jq -nc \
    --arg id "$id" \
    --arg title "$title" \
    --arg created_at "$created_at" \
    '{id: $id, title: $title, status: "open", type: "task", priority: 2,
      description: null, close_reason: null, depends_on: [], blocks: [],
      created_at: $created_at, updated_at: $created_at, closed_at: null}' \
    >> "$seeds_file"
}

# ---------------------------------------------------------------------------
# Check whether output is sorted by (created_at, id)
# Prints PASS/FAIL and updates counters
assert_seeds_sorted() {
  local desc="$1"
  local seeds_file="${TEST_DIR}/.furrow/seeds/seeds.jsonl"

  # Build actual sorted order using same algorithm
  local sorted_keys sorted_content disk_content
  sorted_keys=$(mktemp)
  local linenum=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    linenum=$((linenum + 1))
    key=$(printf '%s\n' "$line" | LC_ALL=C jq -r '[.created_at // "", .id // ""] | @tsv' 2>/dev/null)
    printf '%s\t%d\t%s\n' "$key" "$linenum" "$line" >> "$sorted_keys"
  done < "$seeds_file"

  sorted_content=$(LC_ALL=C sort -t $'\t' -k1,1 -k2,2 -k3,3n "$sorted_keys" | cut -f4-)
  disk_content=$(grep -v '^$' "$seeds_file" 2>/dev/null || true)
  rm -f "$sorted_keys"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$sorted_content" = "$disk_content" ]; then
    printf "  PASS: %s\n" "$desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s — file is not sorted by (created_at, id)\n" "$desc" >&2
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

  mkdir -p .furrow/seeds
  touch .furrow/seeds/seeds.jsonl

  # Write 10 seeds with shuffled timestamps
  write_seed "2024-05-03T10:00:00Z" "proj-0503" "Seed E"
  write_seed "2024-05-01T10:00:00Z" "proj-0501" "Seed A"
  write_seed "2024-05-08T10:00:00Z" "proj-0508" "Seed H"
  write_seed "2024-05-06T10:00:00Z" "proj-0506" "Seed F"
  write_seed "2024-05-02T10:00:00Z" "proj-0502" "Seed B"
  write_seed "2024-05-10T10:00:00Z" "proj-0510" "Seed J"
  write_seed "2024-05-07T10:00:00Z" "proj-0507" "Seed G"
  write_seed "2024-05-04T10:00:00Z" "proj-0504" "Seed D"
  write_seed "2024-05-09T10:00:00Z" "proj-0509" "Seed I"
  write_seed "2024-05-05T10:00:00Z" "proj-0505" "Seed C"

  PROJECT_ROOT="$TEST_DIR" frw normalize-seeds 2>/dev/null

  assert_seeds_sorted "10 shuffled seeds sorted correctly"

  # Also verify: jq -c round-trip produces byte-identical output
  local jq_roundtrip
  jq_roundtrip=$(jq -c '.' .furrow/seeds/seeds.jsonl 2>/dev/null)
  local disk_content
  disk_content=$(cat .furrow/seeds/seeds.jsonl)
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$jq_roundtrip" = "$disk_content" ]; then
    printf "  PASS: sorted output byte-identical to jq -c round-trip\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: sorted output differs from jq -c round-trip\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  teardown_test_env
}

# ---------------------------------------------------------------------------
# idempotent
# ---------------------------------------------------------------------------
test_idempotent() {
  setup_test_env
  cd "$TEST_DIR"

  mkdir -p .furrow/seeds
  touch .furrow/seeds/seeds.jsonl

  write_seed "2024-03-02T00:00:00Z" "p-002" "Second"
  write_seed "2024-03-01T00:00:00Z" "p-001" "First"
  write_seed "2024-03-03T00:00:00Z" "p-003" "Third"

  PROJECT_ROOT="$TEST_DIR" frw normalize-seeds 2>/dev/null
  local after_first
  after_first=$(cat .furrow/seeds/seeds.jsonl)

  PROJECT_ROOT="$TEST_DIR" frw normalize-seeds 2>/dev/null
  local after_second
  after_second=$(cat .furrow/seeds/seeds.jsonl)

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
# Two seeds with identical (created_at, id) but differing payloads
# Both must survive and their relative order must be stable (line-num tiebreak).
# ---------------------------------------------------------------------------
test_stable_ties() {
  setup_test_env
  cd "$TEST_DIR"

  mkdir -p .furrow/seeds
  touch .furrow/seeds/seeds.jsonl

  # Two entries with identical created_at AND id (degenerate duplicate — tests tiebreak)
  # In normal usage identical (created_at, id) shouldn't happen, but we test the sort stability.
  local same_ts="2024-06-01T00:00:00Z"
  local same_id="proj-tie"
  # Append two entries differing only in title (and updated_at can differ)
  jq -nc --arg id "$same_id" --arg ts "$same_ts" \
    '{id: $id, title: "Tie-A", status: "open", type: "task", priority: 2,
      description: null, close_reason: null, depends_on: [], blocks: [],
      created_at: $ts, updated_at: $ts, closed_at: null}' \
    >> .furrow/seeds/seeds.jsonl

  jq -nc --arg id "$same_id" --arg ts "$same_ts" \
    '{id: $id, title: "Tie-B", status: "open", type: "task", priority: 2,
      description: null, close_reason: null, depends_on: [], blocks: [],
      created_at: $ts, updated_at: $ts, closed_at: null}' \
    >> .furrow/seeds/seeds.jsonl

  PROJECT_ROOT="$TEST_DIR" frw normalize-seeds 2>/dev/null
  local after_first
  after_first=$(cat .furrow/seeds/seeds.jsonl)

  # Both entries must survive
  local count
  count=$(wc -l < .furrow/seeds/seeds.jsonl | tr -d ' ')
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$count" -eq 2 ]; then
    printf "  PASS: stable_ties — both tie entries survive normalize\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: stable_ties — expected 2 entries, got %s\n" "$count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  PROJECT_ROOT="$TEST_DIR" frw normalize-seeds 2>/dev/null
  local after_second
  after_second=$(cat .furrow/seeds/seeds.jsonl)

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
# Run normalize with LC_ALL=en_US.UTF-8 at outer shell; result must be byte-identical
# to a run with LC_ALL=C.
# ---------------------------------------------------------------------------
test_cross_locale() {
  setup_test_env
  cd "$TEST_DIR"

  mkdir -p .furrow/seeds
  touch .furrow/seeds/seeds.jsonl

  write_seed "2024-05-02T00:00:00Z" "proj-b" "B"
  write_seed "2024-05-01T00:00:00Z" "proj-a" "A"
  write_seed "2024-05-03T00:00:00Z" "proj-c" "C"

  # Run with LC_ALL=C
  LC_ALL=C PROJECT_ROOT="$TEST_DIR" frw normalize-seeds 2>/dev/null
  local result_c
  result_c=$(cat .furrow/seeds/seeds.jsonl)

  # Scramble again
  printf '' > .furrow/seeds/seeds.jsonl
  write_seed "2024-05-02T00:00:00Z" "proj-b" "B"
  write_seed "2024-05-01T00:00:00Z" "proj-a" "A"
  write_seed "2024-05-03T00:00:00Z" "proj-c" "C"

  # Run with LC_ALL=en_US.UTF-8 (regression test for locale-lock)
  LC_ALL=en_US.UTF-8 PROJECT_ROOT="$TEST_DIR" frw normalize-seeds 2>/dev/null
  local result_utf8
  result_utf8=$(cat .furrow/seeds/seeds.jsonl)

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

  mkdir -p .furrow/seeds
  touch .furrow/seeds/seeds.jsonl

  write_seed "2024-01-01T00:00:00Z" "proj-001" "First"
  write_seed "2024-01-02T00:00:00Z" "proj-002" "Second"
  # Already sorted by timestamp

  local exit_code=0
  rws validate-sort-invariant --file .furrow/seeds/seeds.jsonl >/dev/null 2>&1 || exit_code=$?

  assert_exit_code "validate-sort-invariant exits 0 on sorted file" 0 "$exit_code"

  teardown_test_env
}

# ---------------------------------------------------------------------------
# validate_fail
# ---------------------------------------------------------------------------
test_validate_fail() {
  setup_test_env
  cd "$TEST_DIR"

  mkdir -p .furrow/seeds
  touch .furrow/seeds/seeds.jsonl

  # Write in sorted order
  write_seed "2024-01-01T00:00:00Z" "proj-001" "First"
  write_seed "2024-01-02T00:00:00Z" "proj-002" "Second"

  # Deliberately scramble (swap lines)
  local line1 line2
  line1=$(sed -n '1p' .furrow/seeds/seeds.jsonl)
  line2=$(sed -n '2p' .furrow/seeds/seeds.jsonl)
  printf '%s\n%s\n' "$line2" "$line1" > .furrow/seeds/seeds.jsonl

  local exit_code=0
  local stderr_out
  stderr_out=$(rws validate-sort-invariant --file .furrow/seeds/seeds.jsonl 2>&1 >/dev/null) || exit_code=$?

  assert_exit_code "validate-sort-invariant exits 3 on scrambled file" 3 "$exit_code"
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
