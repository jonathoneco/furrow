#!/bin/bash
# test-hook-cascade.sh — Integration tests for hook-cascade split (AC-G, AC-D)
#
# Subtests:
#   1. hook_switchover      — no hooks reference lib/common.sh; >= 10 reference common-minimal.sh
#   2. function_set         — common-minimal.sh exports exactly the 8 hook-safe functions
#   3. bodies_identical     — rescue.sh --baseline-check exits 0 (common-minimal unchanged)
#   4. typechange_block     — pre-commit-typechange.sh exits 1 + stderr on all 4 protected globs
#   5. bakfile_block        — pre-commit-bakfiles.sh exits 1 + stderr on both .bak locations

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export PROJECT_ROOT

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT

echo "=== test-hook-cascade.sh ==="

# ---------------------------------------------------------------------------
# Subtest 1: hook_switchover
# Verify no hook in hooks/ references lib/common.sh directly,
# and at least 10 hooks reference lib/common-minimal.sh.
# ---------------------------------------------------------------------------
test_hook_switchover() {
  echo ""
  echo "--- test_hook_switchover ---"

  _hooks_dir="$PROJECT_ROOT/bin/frw.d/hooks"

  # grep -l returns non-zero when no files match — that's the desired result
  _common_count=0
  if grep -rl 'lib/common\.sh' "$_hooks_dir" --include='*.sh' >/dev/null 2>&1; then
    _common_count="$(grep -rl 'lib/common\.sh' "$_hooks_dir" --include='*.sh' 2>/dev/null | wc -l)"
  fi
  assert_exit_code "no hooks reference lib/common.sh (count=0)" 0 "$([ "$_common_count" -eq 0 ] && echo 0 || echo 1)"

  _minimal_count="$(grep -rl 'lib/common-minimal\.sh' "$_hooks_dir" --include='*.sh' 2>/dev/null | wc -l)"
  assert_ge "at least 10 hooks reference lib/common-minimal.sh" "$_minimal_count" 10
}

# ---------------------------------------------------------------------------
# Subtest 2: function_set
# Verify common-minimal.sh defines exactly the 8 hook-safe functions by name.
# ---------------------------------------------------------------------------
test_function_set() {
  echo ""
  echo "--- test_function_set ---"

  _lib="$PROJECT_ROOT/bin/frw.d/lib/common-minimal.sh"

  # Extract function names defined at top level (no leading whitespace)
  _actual="$(grep -oE '^[a-z_]+\(\)' "$_lib" 2>/dev/null | sort | uniq | tr '\n' ' ' | sed 's/ $//')"

  # Expected: exactly these 8 (alphabetical, with trailing parens)
  _expected="extract_row_from_path() find_active_row() find_focused_row() is_row_file() log_error() log_warning() read_state_field() row_name()"

  assert_exit_code "common-minimal.sh has exactly the 8 hook-safe functions" 0 \
    "$([ "$_actual" = "$_expected" ] && echo 0 || echo 1)"

  if [ "$_actual" != "$_expected" ]; then
    printf "  Expected: %s\n" "$_expected" >&2
    printf "  Actual:   %s\n" "$_actual" >&2
  fi
}

# ---------------------------------------------------------------------------
# Subtest 3: bodies_identical
# Verify rescue.sh --baseline-check exits 0 (common-minimal.sh is unchanged).
# ---------------------------------------------------------------------------
test_bodies_identical() {
  echo ""
  echo "--- test_bodies_identical ---"

  setup_test_env

  _rescue="$PROJECT_ROOT/bin/frw.d/scripts/rescue.sh"
  _exit=0
  (cd "$TEST_DIR" && bash "$_rescue" --baseline-check 2>/dev/null) || _exit=$?

  assert_exit_code "rescue.sh --baseline-check exits 0 (no drift)" 0 "$_exit"

  teardown_test_env
}

# ---------------------------------------------------------------------------
# Subtest 4: typechange_block
# For each of the 4 protected globs, set up a temp git repo where the file
# is staged as a typechange (regular → symlink), then verify the hook exits 1
# and emits the expected stderr pattern.
# ---------------------------------------------------------------------------

_run_typechange_test() {
  _label="$1"
  _rel_path="$2"

  setup_test_env

  (
    cd "$TEST_DIR"

    # Create the file as a regular file and commit it
    _dir="$(dirname "$_rel_path")"
    mkdir -p "$_dir"
    printf 'placeholder\n' > "$_rel_path"
    git add "$_rel_path"
    git commit -q -m "add $_rel_path"

    # Now replace with a symlink and stage the typechange
    rm "$_rel_path"
    ln -s /tmp/nowhere "$_rel_path"
    git add "$_rel_path" 2>/dev/null || true
  )

  _hook="$PROJECT_ROOT/bin/frw.d/hooks/pre-commit-typechange.sh"
  _stderr_out=""
  _exit=0
  _stderr_out="$(cd "$TEST_DIR" && sh "$_hook" 2>&1)" || _exit=$?

  assert_exit_code "typechange block: $_label exits 1" 1 "$_exit"
  assert_output_contains "typechange block: $_label stderr mentions pre-commit" \
    "$_stderr_out" "pre-commit"
  assert_output_contains "typechange block: $_label stderr mentions path" \
    "$_stderr_out" "$_rel_path"

  teardown_test_env
}

test_typechange_block() {
  echo ""
  echo "--- test_typechange_block ---"

  _run_typechange_test "bin/alm" "bin/alm"
  _run_typechange_test "bin/rws" "bin/rws"
  _run_typechange_test "bin/sds" "bin/sds"
  _run_typechange_test ".claude/rules/cli-mediation.md" ".claude/rules/cli-mediation.md"
}

# ---------------------------------------------------------------------------
# Subtest 5: bakfile_block
# For each of the 2 protected .bak locations, stage a .bak file and verify
# the hook exits 1 and emits the expected stderr pattern.
# ---------------------------------------------------------------------------

_run_bakfile_test() {
  _label="$1"
  _rel_path="$2"

  setup_test_env

  (
    cd "$TEST_DIR"
    _dir="$(dirname "$_rel_path")"
    mkdir -p "$_dir"
    printf 'backup artifact\n' > "$_rel_path"
    git add -f "$_rel_path"
  )

  _hook="$PROJECT_ROOT/bin/frw.d/hooks/pre-commit-bakfiles.sh"
  _stderr_out=""
  _exit=0
  _stderr_out="$(cd "$TEST_DIR" && sh "$_hook" 2>&1)" || _exit=$?

  assert_exit_code "bakfile block: $_label exits 1" 1 "$_exit"
  assert_output_contains "bakfile block: $_label stderr mentions pre-commit" \
    "$_stderr_out" "pre-commit"
  assert_output_contains "bakfile block: $_label stderr mentions path" \
    "$_stderr_out" "$_rel_path"

  teardown_test_env
}

test_bakfile_block() {
  echo ""
  echo "--- test_bakfile_block ---"

  _run_bakfile_test "bin/alm.bak" "bin/alm.bak"
  _run_bakfile_test ".claude/rules/cli-mediation.md.bak" ".claude/rules/cli-mediation.md.bak"
}

# ---------------------------------------------------------------------------
# Run all subtests
# ---------------------------------------------------------------------------

run_test test_hook_switchover
run_test test_function_set
run_test test_bodies_identical
run_test test_typechange_block
run_test test_bakfile_block

print_summary
