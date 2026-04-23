#!/bin/bash
# test-install-consumer-mode.sh — AC-A refuse-copy guard
#
# Verifies that install.sh (via frw.d/install.sh) refuses to install into a
# consumer target that already has a SOURCE_REPO sentinel, and that the sentinel
# does NOT end up in the target after a refused run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-install-consumer-mode.sh (AC-A refuse-copy) ==="

# We need FURROW_ROOT to invoke frw install via the dispatcher.
# PROJECT_ROOT is set by helpers.sh.
FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT

# ---------------------------------------------------------------------------
# Helper: create minimal consumer fixture with SOURCE_REPO already present
# (simulating cp -r ./.furrow consumer/.furrow)
# ---------------------------------------------------------------------------
_make_consumer_fixture_with_sentinel() {
  local dir="$1"
  mkdir -p "$dir/.furrow"
  mkdir -p "$dir/.claude"
  mkdir -p "$dir/bin"
  # Simulate the contaminated case: SOURCE_REPO was copied into consumer target
  printf 'This file marks the Furrow source repository.\n' > "$dir/.furrow/SOURCE_REPO"
  # Initialize a minimal git repo so repo_slug works
  (
    cd "$dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    printf 'init\n' > .gitkeep &&
    git add .gitkeep &&
    git commit -q -m "initial"
  )
}

# ---------------------------------------------------------------------------
# test_refuse_copy_exits_2
# ---------------------------------------------------------------------------
# When a consumer target already has SOURCE_REPO, install should exit 2.
test_refuse_copy_exits_2() {
  local fixture_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  _make_consumer_fixture_with_sentinel "$fixture_dir"

  # Invoke frw install --project using the real dispatcher
  local exit_code=0
  local stderr_out
  stderr_out="$(
    XDG_STATE_HOME="$xdg_dir" \
    "$FURROW_ROOT/bin/frw" install \
      --project "$fixture_dir" \
      --xdg-state-home "$xdg_dir" \
      2>&1 >/dev/null
  )" || exit_code=$?

  assert_exit_code "install exits 2 when consumer target has SOURCE_REPO" 2 "$exit_code"
  assert_output_contains "stderr contains refusing message" "$stderr_out" \
    "refusing to copy .furrow/SOURCE_REPO"

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_source_repo_not_created_after_refused_run
# ---------------------------------------------------------------------------
# After a refused install, the target's .furrow/SOURCE_REPO must NOT exist
# in any "installed" state (it was pre-existing and should remain intact but
# install should not have proceeded to create new artifacts).
test_source_repo_not_created_after_refused_run() {
  local fixture_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  _make_consumer_fixture_with_sentinel "$fixture_dir"

  # Run install; it should fail (exit 2)
  XDG_STATE_HOME="$xdg_dir" \
  "$FURROW_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1 || true

  # The SOURCE_REPO should still be there (pre-existing), but no install-state.json
  # should have been written (install was refused before completing).
  local slug
  slug="$(basename "$fixture_dir" | LC_ALL=C tr -c '[:alnum:]-' '-' | sed 's/-*$//; s/^-*//')"
  [ -z "$slug" ] && slug="furrow"

  assert_file_not_exists \
    "install-state.json was NOT created after refused install" \
    "${xdg_dir}/furrow/${slug}/install-state.json"

  # Verify commands/ was NOT created (install was aborted early)
  assert_file_not_exists \
    ".claude/commands/ was NOT created after refused install" \
    "${fixture_dir}/.claude/commands"

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_clean_consumer_install_succeeds
# ---------------------------------------------------------------------------
# A consumer target without SOURCE_REPO should install cleanly (exit 0).
test_clean_consumer_install_succeeds() {
  local fixture_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  mkdir -p "$fixture_dir"
  (
    cd "$fixture_dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    printf 'init\n' > .gitkeep &&
    git add .gitkeep &&
    git commit -q -m "initial"
  )

  local exit_code=0
  XDG_STATE_HOME="$xdg_dir" \
  "$FURROW_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1 || exit_code=$?

  assert_exit_code "clean consumer install exits 0" 0 "$exit_code"

  # Verify .claude/commands was created
  local cmd_exists=0
  [ -d "${fixture_dir}/.claude/commands" ] && cmd_exists=1 || cmd_exists=0
  assert_exit_code ".claude/commands/ was created" 0 \
    "$([ "$cmd_exists" = "1" ] && echo 0 || echo 1)"

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
run_test test_refuse_copy_exits_2
run_test test_source_repo_not_created_after_refused_run
run_test test_clean_consumer_install_succeeds

print_summary
