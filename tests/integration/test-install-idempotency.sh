#!/bin/bash
# test-install-idempotency.sh — AC-C, AC-H: second run produces identical tree
#
# Verifies:
# - Running install twice on the same consumer fixture is idempotent
# - File manifest is identical between runs (except last_install_at in install-state.json)
# - install-state.json migration_version stays "1.0" (monotonic)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-install-idempotency.sh (AC-C, AC-H) ==="

setup_sandbox >/dev/null
snapshot_guard_targets
# Sandbox the four env vars inside $TMP; snapshot the protected path set.
# Tests invoke the harness via PROJECT_ROOT; setup_sandbox repoints
# FURROW_ROOT at $TMP/fixture.

# ---------------------------------------------------------------------------
# Helper: create minimal consumer fixture
# ---------------------------------------------------------------------------
_make_consumer_fixture() {
  local dir="$1"
  (
    cd "$dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    mkdir -p bin .claude/commands .claude/rules &&
    printf 'init\n' > .gitkeep &&
    git add .gitkeep &&
    git commit -q -m "initial"
  )
}

# ---------------------------------------------------------------------------
# test_idempotent_install
# ---------------------------------------------------------------------------
test_idempotent_install() {
  local fixture_dir xdg_dir manifest_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  manifest_dir="$(mktemp -d)"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")" "$manifest_dir"' EXIT INT TERM

  _make_consumer_fixture "$fixture_dir"

  # First install
  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  # Capture manifest after first run (path + size, not mtime)
  # Exclude install-state.json itself since last_install_at will differ
  find "$fixture_dir" \
    -not -path '*/.git/*' \
    -printf '%P %s\n' 2>/dev/null | sort > "$manifest_dir/manifest1.txt"

  # Brief pause to ensure timestamps differ
  sleep 1

  # Second install
  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  # Capture manifest after second run
  find "$fixture_dir" \
    -not -path '*/.git/*' \
    -printf '%P %s\n' 2>/dev/null | sort > "$manifest_dir/manifest2.txt"

  # Manifests must be identical (same files, same sizes)
  local diff_out
  diff_out="$(diff "$manifest_dir/manifest1.txt" "$manifest_dir/manifest2.txt")" || true

  assert_exit_code "file manifests identical between runs" 0 \
    "$([ -z "$diff_out" ] && echo 0 || echo 1)"

  if [ -n "$diff_out" ]; then
    printf "  Manifest diff:\n%s\n" "$diff_out" >&2
  fi

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")" "$manifest_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_migration_version_monotonic
# ---------------------------------------------------------------------------
test_migration_version_monotonic() {
  local fixture_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  _make_consumer_fixture "$fixture_dir"

  # First install
  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  local slug
  slug="$(basename "$fixture_dir" | LC_ALL=C tr -c '[:alnum:]-' '-' | sed 's/-*$//; s/^-*//')"
  [ -z "$slug" ] && slug="furrow"
  local state_file="${xdg_dir}/furrow/${slug}/install-state.json"

  # Verify migration_version after first run
  assert_json_field "migration_version=1.0 after first run" \
    "$state_file" ".migration_version" "1.0"

  # Second install
  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  # migration_version must still be "1.0" (monotonic — not reset to "0")
  assert_json_field "migration_version stays 1.0 after second run (monotonic)" \
    "$state_file" ".migration_version" "1.0"

  # installed_at must not change between runs
  local installed_at_1 installed_at_2
  installed_at_1="$(jq -r '.installed_at' "$state_file" 2>/dev/null)"

  # Run again to compare
  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  installed_at_2="$(jq -r '.installed_at' "$state_file" 2>/dev/null)"
  assert_exit_code "installed_at unchanged on subsequent runs" 0 \
    "$([ "$installed_at_1" = "$installed_at_2" ] && echo 0 || echo 1)"

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
run_test test_idempotent_install
run_test test_migration_version_monotonic

# Sandbox guard: fail the suite if any protected path was mutated.
assert_no_worktree_mutation

print_summary
