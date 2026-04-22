#!/bin/bash
# test-legacy-migration.sh — AC-H: legacy install detection and migration
#
# Verifies:
# - Fixture with bin/*.bak + .claude/furrow.yaml + no install-state.json
#   is detected as legacy and migrated
# - .bak files moved to $XDG_STATE_HOME/furrow/<slug>/bak/
# - .claude/furrow.yaml removed when .furrow/furrow.yaml exists
# - install-state.json written with migration_version="1.0"
# - Second run is idempotent (migration_version stays "1.0")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-legacy-migration.sh (AC-H) ==="

FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT

# ---------------------------------------------------------------------------
# Helper: create legacy fixture
# ---------------------------------------------------------------------------
_make_legacy_fixture() {
  local dir="$1"
  (
    cd "$dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    mkdir -p bin .claude/rules .furrow &&
    # Legacy .bak files (pre-XDG artifacts)
    printf '#!/bin/sh\necho alm\n' > bin/alm.bak &&
    chmod +x bin/alm.bak &&
    printf '#!/bin/sh\necho rws\n' > bin/rws.bak &&
    chmod +x bin/rws.bak &&
    printf '#!/bin/sh\necho sds\n' > bin/sds.bak &&
    chmod +x bin/sds.bak &&
    # Legacy .claude/furrow.yaml (superseded location)
    printf 'legacy: true\n' > .claude/furrow.yaml &&
    # Current .furrow/furrow.yaml (canonical location)
    printf 'canonical: true\n' > .furrow/furrow.yaml &&
    # No install-state.json — this is the legacy indicator
    printf 'init\n' > .gitkeep &&
    git add .gitkeep &&
    git commit -q -m "initial"
  )
}

# ---------------------------------------------------------------------------
# test_legacy_baks_migrated
# ---------------------------------------------------------------------------
test_legacy_baks_migrated() {
  local fixture_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  _make_legacy_fixture "$fixture_dir"

  XDG_STATE_HOME="$xdg_dir" \
  "$FURROW_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  local slug
  slug="$(basename "$fixture_dir" | LC_ALL=C tr -c '[:alnum:]-' '-' | sed 's/-*$//; s/^-*//')"
  [ -z "$slug" ] && slug="furrow"

  # .bak files should be in XDG bak dir
  local bak_dir="${xdg_dir}/furrow/${slug}/bak"

  assert_file_exists "alm.bak migrated to XDG bak dir" "${bak_dir}/alm.bak"
  assert_file_exists "rws.bak migrated to XDG bak dir" "${bak_dir}/rws.bak"
  assert_file_exists "sds.bak migrated to XDG bak dir" "${bak_dir}/sds.bak"

  # .bak files should NOT remain in bin/
  assert_file_not_exists "bin/alm.bak removed from project" "${fixture_dir}/bin/alm.bak"
  assert_file_not_exists "bin/rws.bak removed from project" "${fixture_dir}/bin/rws.bak"
  assert_file_not_exists "bin/sds.bak removed from project" "${fixture_dir}/bin/sds.bak"

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_legacy_claude_furrow_yaml_removed
# ---------------------------------------------------------------------------
test_legacy_claude_furrow_yaml_removed() {
  local fixture_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  _make_legacy_fixture "$fixture_dir"

  XDG_STATE_HOME="$xdg_dir" \
  "$FURROW_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  # .claude/furrow.yaml should have been removed (superseded by .furrow/furrow.yaml)
  assert_file_not_exists \
    ".claude/furrow.yaml removed (superseded by .furrow/furrow.yaml)" \
    "${fixture_dir}/.claude/furrow.yaml"

  # .furrow/furrow.yaml should still exist
  assert_file_exists \
    ".furrow/furrow.yaml remains (canonical location)" \
    "${fixture_dir}/.furrow/furrow.yaml"

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_install_state_migration_version
# ---------------------------------------------------------------------------
test_install_state_migration_version() {
  local fixture_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  _make_legacy_fixture "$fixture_dir"

  XDG_STATE_HOME="$xdg_dir" \
  "$FURROW_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  local slug
  slug="$(basename "$fixture_dir" | LC_ALL=C tr -c '[:alnum:]-' '-' | sed 's/-*$//; s/^-*//')"
  [ -z "$slug" ] && slug="furrow"
  local state_file="${xdg_dir}/furrow/${slug}/install-state.json"

  assert_file_exists "install-state.json created" "$state_file"
  assert_json_field "migration_version=1.0 after migration" \
    "$state_file" ".migration_version" "1.0"

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_legacy_migration_idempotent
# ---------------------------------------------------------------------------
# Running install again on the migrated tree must be idempotent:
# manifest diff empty (except last_install_at), migration_version stays "1.0".
test_legacy_migration_idempotent() {
  local fixture_dir xdg_dir manifest_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  manifest_dir="$(mktemp -d)"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")" "$manifest_dir"' EXIT INT TERM

  _make_legacy_fixture "$fixture_dir"

  # First run
  XDG_STATE_HOME="$xdg_dir" \
  "$FURROW_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  local slug
  slug="$(basename "$fixture_dir" | LC_ALL=C tr -c '[:alnum:]-' '-' | sed 's/-*$//; s/^-*//')"
  [ -z "$slug" ] && slug="furrow"
  local state_file="${xdg_dir}/furrow/${slug}/install-state.json"

  # Manifest after first run (exclude install-state.json timestamps — checked via jq)
  find "$fixture_dir" -not -path '*/.git/*' -printf '%P %s\n' 2>/dev/null | sort \
    > "$manifest_dir/manifest1.txt"

  sleep 1

  # Second run
  XDG_STATE_HOME="$xdg_dir" \
  "$FURROW_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  find "$fixture_dir" -not -path '*/.git/*' -printf '%P %s\n' 2>/dev/null | sort \
    > "$manifest_dir/manifest2.txt"

  local diff_out
  diff_out="$(diff "$manifest_dir/manifest1.txt" "$manifest_dir/manifest2.txt")" || true
  assert_exit_code "manifest identical after second run" 0 \
    "$([ -z "$diff_out" ] && echo 0 || echo 1)"

  # migration_version must stay "1.0" (monotonic)
  assert_json_field "migration_version stays 1.0 on re-run" \
    "$state_file" ".migration_version" "1.0"

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")" "$manifest_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
run_test test_legacy_baks_migrated
run_test test_legacy_claude_furrow_yaml_removed
run_test test_install_state_migration_version
run_test test_legacy_migration_idempotent

print_summary
