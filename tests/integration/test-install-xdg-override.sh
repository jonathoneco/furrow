#!/bin/bash
# test-install-xdg-override.sh — AC-C: XDG_STATE_HOME override + install-state.json
#
# Verifies:
# - --xdg-state-home flag routes install-state.json to specified path
# - install-state.json has required schema fields
# - schema_version=1, migration_version="1.0" for new consumer installs
# - .bak files are moved from bin/ and .claude/rules/ to XDG bak dir
# - XDG_STATE_HOME is NOT hardcoded to /tmp/xdg-test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-install-xdg-override.sh (AC-C) ==="

# Sandbox the four env vars inside $TMP; snapshot protected paths.
setup_sandbox >/dev/null
snapshot_guard_targets

# ---------------------------------------------------------------------------
# Helper: create minimal consumer tree with fake .bak files staged
# ---------------------------------------------------------------------------
_make_consumer_with_baks() {
  local dir="$1"
  (
    cd "$dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    mkdir -p bin .claude/rules &&
    printf '#!/bin/sh\necho alm\n' > bin/alm.bak &&
    printf '#!/bin/sh\necho rws\n' > bin/rws.bak &&
    printf '# rule bak\n' > .claude/rules/cli-mediation.md.bak &&
    printf 'init\n' > .gitkeep &&
    git add .gitkeep &&
    git commit -q -m "initial"
  )
}

# ---------------------------------------------------------------------------
# test_xdg_override_creates_install_state
# ---------------------------------------------------------------------------
test_xdg_override_creates_install_state() {
  local fixture_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"  # NOT /tmp/xdg-test — dynamically allocated
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  _make_consumer_with_baks "$fixture_dir"

  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  # Derive slug the same way repo_slug() does
  local slug
  slug="$(basename "$fixture_dir" | LC_ALL=C tr -c '[:alnum:]-' '-' | sed 's/-*$//; s/^-*//')"
  [ -z "$slug" ] && slug="furrow"

  local state_file="${xdg_dir}/furrow/${slug}/install-state.json"
  assert_file_exists "install-state.json created at XDG path" "$state_file"

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_install_state_schema_fields
# ---------------------------------------------------------------------------
test_install_state_schema_fields() {
  local fixture_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  _make_consumer_with_baks "$fixture_dir"

  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  local slug
  slug="$(basename "$fixture_dir" | LC_ALL=C tr -c '[:alnum:]-' '-' | sed 's/-*$//; s/^-*//')"
  [ -z "$slug" ] && slug="furrow"
  local state_file="${xdg_dir}/furrow/${slug}/install-state.json"

  # Validate required schema fields present
  local has_fields
  has_fields="$(jq -r 'if has("schema_version") and has("install_mode") and has("migration_version") and has("repo_slug") and has("repo_root") and has("installed_at") and has("last_install_at") then "yes" else "no" end' "$state_file" 2>/dev/null)"
  assert_exit_code "install-state.json has all required schema fields" 0 \
    "$([ "$has_fields" = "yes" ] && echo 0 || echo 1)"

  # schema_version must be 1
  assert_json_field "schema_version=1" "$state_file" ".schema_version" "1"

  # install_mode must be consumer (no SOURCE_REPO in fixture)
  assert_json_field "install_mode=consumer" "$state_file" ".install_mode" "consumer"

  # migration_version must be "1.0"
  assert_json_field "migration_version=1.0" "$state_file" ".migration_version" "1.0"

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_bak_files_moved_to_xdg
# ---------------------------------------------------------------------------
test_bak_files_moved_to_xdg() {
  local fixture_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  trap 'rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  _make_consumer_with_baks "$fixture_dir"

  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  local slug
  slug="$(basename "$fixture_dir" | LC_ALL=C tr -c '[:alnum:]-' '-' | sed 's/-*$//; s/^-*//')"
  [ -z "$slug" ] && slug="furrow"

  # .bak files should NOT be under bin/ anymore
  local bak_in_bin
  bak_in_bin="$(find "$fixture_dir/bin" -name '*.bak' 2>/dev/null | wc -l)"
  assert_exit_code "no .bak files remain under bin/" 0 \
    "$([ "$bak_in_bin" = "0" ] && echo 0 || echo 1)"

  local bak_in_rules
  bak_in_rules="$(find "$fixture_dir/.claude/rules" -name '*.bak' 2>/dev/null | wc -l)"
  assert_exit_code "no .bak files remain under .claude/rules/" 0 \
    "$([ "$bak_in_rules" = "0" ] && echo 0 || echo 1)"

  # .bak files should be in XDG bak dir
  local bak_dir="${xdg_dir}/furrow/${slug}/bak"
  local bak_count
  bak_count="$(find "$bak_dir" -name '*.bak' 2>/dev/null | wc -l)"
  assert_ge "bak files moved to XDG bak dir" "$bak_count" 2

  rm -rf "$fixture_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_xdg_config_bootstrap_fresh_install [AC-3]
# Fresh frw install --project on a clean consumer tree must bootstrap:
#   - ${XDG_CONFIG_HOME}/furrow/config.yaml   (if absent)
#   - ${XDG_CONFIG_HOME}/furrow/promotion-targets.yaml (if absent)
# Uses mktemp -d isolation so the real ~/.config is never touched.
# ---------------------------------------------------------------------------
test_xdg_config_bootstrap_fresh_install() {
  local fixture_dir cfg_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  cfg_dir="$(mktemp -d)"  # isolated XDG_CONFIG_HOME
  xdg_dir="$(mktemp -d)/xdg"  # isolated XDG_STATE_HOME
  trap 'rm -rf "$fixture_dir" "$cfg_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  # Minimal git-init consumer tree (no .bak files needed)
  (
    cd "$fixture_dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    echo "init" > .gitkeep &&
    git add .gitkeep &&
    git commit -q -m "initial"
  )

  # Run install — XDG_CONFIG_HOME redirected so real ~/.config is untouched
  XDG_CONFIG_HOME="$cfg_dir" \
  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  # Both files must exist
  assert_file_exists "config.yaml bootstrapped under XDG_CONFIG_HOME" \
    "${cfg_dir}/furrow/config.yaml"
  assert_file_exists "promotion-targets.yaml bootstrapped under XDG_CONFIG_HOME" \
    "${cfg_dir}/furrow/promotion-targets.yaml"

  # config.yaml must be valid YAML (yq can parse it)
  local cfg_ok=0
  yq -r '.' "${cfg_dir}/furrow/config.yaml" >/dev/null 2>&1 && cfg_ok=1
  assert_exit_code "config.yaml is valid YAML" 0 "$([ "$cfg_ok" = "1" ] && echo 0 || echo 1)"

  # promotion-targets.yaml must contain 'targets:' key with empty list
  assert_file_contains "promotion-targets.yaml contains 'targets:'" \
    "${cfg_dir}/furrow/promotion-targets.yaml" "targets:"

  rm -rf "$fixture_dir" "$cfg_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_xdg_config_bootstrap_idempotent [AC-3]
# Re-running frw install must NOT overwrite existing config files.
# ---------------------------------------------------------------------------
test_xdg_config_bootstrap_idempotent() {
  local fixture_dir cfg_dir xdg_dir
  fixture_dir="$(mktemp -d)"
  cfg_dir="$(mktemp -d)"
  xdg_dir="$(mktemp -d)/xdg"
  trap 'rm -rf "$fixture_dir" "$cfg_dir" "$(dirname "$xdg_dir")"' EXIT INT TERM

  (
    cd "$fixture_dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    echo "init" > .gitkeep &&
    git add .gitkeep &&
    git commit -q -m "initial"
  )

  # Pre-create config files with sentinel content
  mkdir -p "${cfg_dir}/furrow"
  printf '# sentinel: do-not-overwrite\ncross_model:\n  provider: sentinel\n' \
    > "${cfg_dir}/furrow/config.yaml"
  printf 'targets:\n  - id: sentinel-entry\n    path: /sentinel\n    category: test\n    promoted_at: "2026-01-01T00:00:00Z"\n' \
    > "${cfg_dir}/furrow/promotion-targets.yaml"

  # First install
  XDG_CONFIG_HOME="$cfg_dir" \
  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  # Second install (idempotency check)
  XDG_CONFIG_HOME="$cfg_dir" \
  XDG_STATE_HOME="$xdg_dir" \
  "$PROJECT_ROOT/bin/frw" install \
    --project "$fixture_dir" \
    --xdg-state-home "$xdg_dir" \
    > /dev/null 2>&1

  # Existing files must be unchanged (sentinel content still present)
  assert_file_contains "config.yaml sentinel content preserved after re-install" \
    "${cfg_dir}/furrow/config.yaml" "sentinel: do-not-overwrite"
  assert_file_contains "promotion-targets.yaml sentinel entry preserved after re-install" \
    "${cfg_dir}/furrow/promotion-targets.yaml" "sentinel-entry"

  rm -rf "$fixture_dir" "$cfg_dir" "$(dirname "$xdg_dir")"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
run_test test_xdg_override_creates_install_state
run_test test_install_state_schema_fields
run_test test_bak_files_moved_to_xdg
run_test test_xdg_config_bootstrap_fresh_install
run_test test_xdg_config_bootstrap_idempotent

# Sandbox guard: fail the suite if any protected path was mutated.
assert_no_worktree_mutation

print_summary
