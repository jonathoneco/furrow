#!/bin/bash
# test-upgrade-migration.sh — AC-7 (full path)
# Verifies the end-to-end migration-fixture scenario:
#   (a) XDG config.yaml matches keys from legacy .claude/furrow.yaml
#   (b) XDG promotion-targets.yaml exists with targets: []
#   (c) .claude/furrow.yaml replaced by symlink to XDG copy
#   (d) install-state.json has migration_version=="1.0" + valid last_upgrade_at

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-upgrade-migration.sh (AC-7 end-to-end) ==="

FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT

FIXTURE_MAKER="${PROJECT_ROOT}/tests/fixtures/make-legacy-install.sh"

# Global temp dirs — cleaned by EXIT trap
_TMP_DIRS=()

_make_tmp_dir() {
  local d
  d="$(mktemp -d)"
  _TMP_DIRS+=("$d")
  printf '%s' "$d"
}

_cleanup_all() {
  for d in "${_TMP_DIRS[@]+"${_TMP_DIRS[@]}"}"; do
    rm -rf "$d"
  done
}
trap '_cleanup_all' EXIT

# ---------------------------------------------------------------------------
# _compute_slug <dir>: mirrors _upgrade_repo_slug from inside the dir
# ---------------------------------------------------------------------------
_compute_slug() {
  local dir="$1"
  local slug
  slug="$(basename "$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$dir")")"
  slug="$(LC_ALL=C printf '%s' "$slug" | tr -c '[:alnum:]-' '-' | sed 's/-*$//; s/^-*//')"
  [ -z "$slug" ] && slug="furrow"
  printf '%s' "$slug"
}

# ---------------------------------------------------------------------------
# _write_state_json <state_file> <slug> <root> <migration_version>
# ---------------------------------------------------------------------------
_write_state_json() {
  local file="$1" slug="$2" root="$3" mv="$4"
  mkdir -p "$(dirname "$file")"
  jq -n \
    --arg repo_slug "$slug" \
    --arg repo_root "$root" \
    --arg migration_version "$mv" \
    --arg installed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg last_install_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      schema_version: 1,
      repo_slug: $repo_slug,
      repo_root: $repo_root,
      install_mode: "consumer",
      migration_version: $migration_version,
      installed_at: $installed_at,
      last_install_at: $last_install_at
    }' > "$file"
}

# ---------------------------------------------------------------------------
# _frw_upgrade: invoke frw upgrade in isolated env (cd into project dir)
# ---------------------------------------------------------------------------
_frw_upgrade() {
  local proj="$1" xdg_cfg="$2" xdg_state="$3"
  shift 3
  (
    cd "$proj"
    PROJECT_ROOT="$proj" \
      XDG_CONFIG_HOME="$xdg_cfg" \
      XDG_STATE_HOME="$xdg_state" \
      FURROW_ROOT="$FURROW_ROOT" \
      "$FURROW_ROOT/bin/frw" upgrade "$@"
  )
}

# ---------------------------------------------------------------------------
# test_migration_fixture_end_to_end
# ---------------------------------------------------------------------------
test_migration_fixture_end_to_end() {
  local fixture_dir xdg_cfg_dir xdg_state_dir
  fixture_dir="$(_make_tmp_dir)"
  xdg_cfg_dir="$(_make_tmp_dir)"
  xdg_state_dir="$(_make_tmp_dir)"

  # Build legacy install fixture
  "$FIXTURE_MAKER" "$fixture_dir"

  # Write initial install-state.json (migration_version="0")
  local slug
  slug="$(_compute_slug "$fixture_dir")"
  local state_file="${xdg_state_dir}/furrow/${slug}/install-state.json"
  _write_state_json "$state_file" "$slug" "$fixture_dir" "0"

  # Record legacy config content for later comparison
  local legacy_yaml="${fixture_dir}/.claude/furrow.yaml"
  local legacy_provider legacy_gate_policy
  legacy_provider="$(yq -r '.cross_model.provider' "$legacy_yaml" 2>/dev/null)"
  legacy_gate_policy="$(yq -r '.gate_policy' "$legacy_yaml" 2>/dev/null)"

  # Run upgrade
  local exit_code=0
  _frw_upgrade "$fixture_dir" "$xdg_cfg_dir" "$xdg_state_dir" --apply \
    --from "${fixture_dir}/.claude/furrow.yaml" || exit_code=$?

  assert_exit_code "frw upgrade --apply exits 0" 0 "$exit_code"

  local xdg_config="${xdg_cfg_dir}/furrow/config.yaml"
  local xdg_pt="${xdg_cfg_dir}/furrow/promotion-targets.yaml"

  # (a) XDG config.yaml exists and keys match legacy config
  assert_file_exists "XDG config.yaml created" "$xdg_config"

  local migrated_provider migrated_gate_policy
  migrated_provider="$(yq -r '.cross_model.provider' "$xdg_config" 2>/dev/null)"
  migrated_gate_policy="$(yq -r '.gate_policy' "$xdg_config" 2>/dev/null)"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$migrated_provider" = "$legacy_provider" ]; then
    printf "  PASS: (a) cross_model.provider matches legacy ('%s')\n" "$legacy_provider"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (a) cross_model.provider mismatch: legacy='%s' migrated='%s'\n" \
      "$legacy_provider" "$migrated_provider" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$migrated_gate_policy" = "$legacy_gate_policy" ]; then
    printf "  PASS: (a) gate_policy matches legacy ('%s')\n" "$legacy_gate_policy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (a) gate_policy mismatch: legacy='%s' migrated='%s'\n" \
      "$legacy_gate_policy" "$migrated_gate_policy" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # (b) promotion-targets.yaml contains targets: []
  assert_file_exists "promotion-targets.yaml created" "$xdg_pt"
  assert_file_contains "promotion-targets.yaml has 'targets:'" "$xdg_pt" "^targets:"

  local pt_val
  pt_val="$(yq '.targets' "$xdg_pt" 2>/dev/null)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$pt_val" = "[]" ]; then
    printf "  PASS: (b) promotion-targets.yaml has targets: []\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (b) promotion-targets.yaml targets value: '%s'\n" "$pt_val" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # (c) .claude/furrow.yaml is now a symlink to the XDG copy
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -L "$legacy_yaml" ]; then
    local link_target
    link_target="$(readlink "$legacy_yaml")"
    printf "  PASS: (c) .claude/furrow.yaml is a symlink -> %s\n" "$link_target"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (c) .claude/furrow.yaml is not a symlink\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # (d) install-state.json has migration_version=="1.0"
  local mv
  mv="$(jq -r '.migration_version' "$state_file" 2>/dev/null)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$mv" = "1.0" ]; then
    printf "  PASS: (d) migration_version='1.0' in install-state.json\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (d) migration_version expected '1.0', got '%s'\n" "$mv" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # (d) last_upgrade_at is a valid ISO-8601 timestamp
  local luat
  luat="$(jq -r '.last_upgrade_at // ""' "$state_file" 2>/dev/null)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s' "$luat" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
    printf "  PASS: (d) last_upgrade_at is valid ISO-8601 ('%s')\n" "$luat"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (d) last_upgrade_at is not valid ISO-8601: '%s'\n" "$luat" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_source_repo_guard
# Verifies upgrade refuses to write XDG artifacts inside the source repo
# ---------------------------------------------------------------------------
test_source_repo_guard() {
  local xdg_cfg_dir xdg_state_dir
  xdg_cfg_dir="$(_make_tmp_dir)"
  xdg_state_dir="$(_make_tmp_dir)"

  local exit_code=0
  # FURROW_ROOT == PROJECT_ROOT and SOURCE_REPO exists — source-repo guard fires
  PROJECT_ROOT="$FURROW_ROOT" \
    XDG_CONFIG_HOME="$xdg_cfg_dir" \
    XDG_STATE_HOME="$xdg_state_dir" \
    "$FURROW_ROOT/bin/frw" upgrade --apply || exit_code=$?

  assert_exit_code "source-repo guard exits 0 (skip, not error)" 0 "$exit_code"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ ! -f "${xdg_cfg_dir}/furrow/config.yaml" ]; then
    printf "  PASS: source-repo guard: no XDG artifacts written\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: source-repo guard: XDG artifacts were written (should be blocked)\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_pre_xdg_specialists_migration — MEDIUM-6
# Simulates a pre-XDG install with .claude/specialists/*.md populated and
# no XDG specialists dir. Verifies upgrade:
#   (a) copies the .md files to $XDG_CONFIG_HOME/furrow/specialists/
#   (b) preserves content (byte-for-byte)
#   (c) replaces .claude/specialists with a symlink to the XDG dir
#   (d) moves the legacy dir aside to .claude/specialists.pre-xdg
#   (e) records the migration in install-state.json migrations_applied
#   (f) second --apply is a no-op (no new files, no state churn)
# ---------------------------------------------------------------------------
test_pre_xdg_specialists_migration() {
  local fixture_dir xdg_cfg_dir xdg_state_dir
  fixture_dir="$(_make_tmp_dir)"
  xdg_cfg_dir="$(_make_tmp_dir)"
  xdg_state_dir="$(_make_tmp_dir)"

  "$FIXTURE_MAKER" "$fixture_dir"

  # Populate legacy .claude/specialists/ with two .md files
  mkdir -p "${fixture_dir}/.claude/specialists"
  printf '# harness-engineer (legacy user override)\nreasoning: legacy\n' \
    > "${fixture_dir}/.claude/specialists/harness-engineer.md"
  printf '# shell-specialist (legacy user override)\nreasoning: legacy\n' \
    > "${fixture_dir}/.claude/specialists/shell-specialist.md"

  local harness_hash_before shell_hash_before
  harness_hash_before="$(sha256sum "${fixture_dir}/.claude/specialists/harness-engineer.md" | awk '{print $1}')"
  shell_hash_before="$(sha256sum "${fixture_dir}/.claude/specialists/shell-specialist.md" | awk '{print $1}')"

  # Write initial install-state.json (migration_version="0")
  local slug
  slug="$(_compute_slug "$fixture_dir")"
  local state_file="${xdg_state_dir}/furrow/${slug}/install-state.json"
  _write_state_json "$state_file" "$slug" "$fixture_dir" "0"

  # Run upgrade
  local exit_code=0
  _frw_upgrade "$fixture_dir" "$xdg_cfg_dir" "$xdg_state_dir" --apply \
    --from "${fixture_dir}/.claude/furrow.yaml" || exit_code=$?

  assert_exit_code "frw upgrade --apply exits 0 (with pre-XDG specialists)" 0 "$exit_code"

  # (a) XDG specialists exist
  local xdg_harness="${xdg_cfg_dir}/furrow/specialists/harness-engineer.md"
  local xdg_shell="${xdg_cfg_dir}/furrow/specialists/shell-specialist.md"
  assert_file_exists "XDG specialists/harness-engineer.md created" "$xdg_harness"
  assert_file_exists "XDG specialists/shell-specialist.md created" "$xdg_shell"

  # (b) content preserved byte-for-byte
  local harness_hash_after shell_hash_after
  harness_hash_after="$(sha256sum "$xdg_harness" | awk '{print $1}')"
  shell_hash_after="$(sha256sum "$xdg_shell" | awk '{print $1}')"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$harness_hash_before" = "$harness_hash_after" ]; then
    printf "  PASS: (b) harness-engineer.md content preserved\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (b) harness-engineer.md content changed during migration\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$shell_hash_before" = "$shell_hash_after" ]; then
    printf "  PASS: (b) shell-specialist.md content preserved\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (b) shell-specialist.md content changed during migration\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # (c) .claude/specialists is a symlink to XDG dir
  local legacy_link="${fixture_dir}/.claude/specialists"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -L "$legacy_link" ]; then
    local link_target
    link_target="$(readlink "$legacy_link")"
    printf "  PASS: (c) .claude/specialists is a symlink -> %s\n" "$link_target"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (c) .claude/specialists is not a symlink\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Symlink resolves to a file with matching content
  assert_file_exists "(c) symlink resolves: harness-engineer.md reachable via legacy path" \
    "${legacy_link}/harness-engineer.md"

  # (d) legacy dir moved aside
  assert_file_exists "(d) .claude/specialists.pre-xdg/ backup exists" \
    "${fixture_dir}/.claude/specialists.pre-xdg/harness-engineer.md"

  # (e) install-state.json records the migration
  local recorded
  recorded="$(jq -r '(.migrations_applied // []) | index("pre_xdg_specialists") // "null"' \
               "$state_file" 2>/dev/null)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$recorded" != "null" ] && [ -n "$recorded" ]; then
    printf "  PASS: (e) migrations_applied contains 'pre_xdg_specialists'\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (e) migrations_applied missing 'pre_xdg_specialists'\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Capture hashes for idempotency check
  local cfg_hash1 xdg_hash1 state_hash1
  cfg_hash1="$(sha256sum "${xdg_cfg_dir}/furrow/config.yaml" | awk '{print $1}')"
  xdg_hash1="$(sha256sum "$xdg_harness" | awk '{print $1}')"
  # Exclude volatile last_upgrade_at for state-hash comparison
  state_hash1="$(jq 'del(.last_upgrade_at)' "$state_file" | sha256sum | awk '{print $1}')"

  # (f) Second --apply is a no-op
  local exit2=0
  _frw_upgrade "$fixture_dir" "$xdg_cfg_dir" "$xdg_state_dir" --apply \
    --from "${fixture_dir}/.claude/furrow.yaml" || exit2=$?

  assert_exit_code "second frw upgrade --apply exits 0 (idempotent)" 0 "$exit2"

  local cfg_hash2 xdg_hash2 state_hash2
  cfg_hash2="$(sha256sum "${xdg_cfg_dir}/furrow/config.yaml" | awk '{print $1}')"
  xdg_hash2="$(sha256sum "$xdg_harness" | awk '{print $1}')"
  state_hash2="$(jq 'del(.last_upgrade_at)' "$state_file" | sha256sum | awk '{print $1}')"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$cfg_hash1" = "$cfg_hash2" ] && \
     [ "$xdg_hash1" = "$xdg_hash2" ] && \
     [ "$state_hash1" = "$state_hash2" ]; then
    printf "  PASS: (f) second --apply is a no-op (no file or state churn)\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (f) second --apply changed files or state\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_already_migrated_specialists_no_op
# Verifies that when .claude/specialists/ is absent (already migrated or
# never existed), upgrade still records the sub-migration and is a no-op
# on subsequent runs — no phantom XDG specialists dir is created.
# ---------------------------------------------------------------------------
test_already_migrated_specialists_no_op() {
  local fixture_dir xdg_cfg_dir xdg_state_dir
  fixture_dir="$(_make_tmp_dir)"
  xdg_cfg_dir="$(_make_tmp_dir)"
  xdg_state_dir="$(_make_tmp_dir)"

  "$FIXTURE_MAKER" "$fixture_dir"
  # Deliberately no .claude/specialists/ present

  local slug
  slug="$(_compute_slug "$fixture_dir")"
  local state_file="${xdg_state_dir}/furrow/${slug}/install-state.json"
  _write_state_json "$state_file" "$slug" "$fixture_dir" "0"

  local exit_code=0
  _frw_upgrade "$fixture_dir" "$xdg_cfg_dir" "$xdg_state_dir" --apply \
    --from "${fixture_dir}/.claude/furrow.yaml" || exit_code=$?

  assert_exit_code "frw upgrade --apply exits 0 (no legacy specialists)" 0 "$exit_code"

  # No phantom specialists dir created
  assert_file_not_exists "no phantom XDG specialists dir when nothing to migrate" \
    "${xdg_cfg_dir}/furrow/specialists/harness-engineer.md"

  # migrations_applied still records the sub-migration (so future runs skip)
  local recorded
  recorded="$(jq -r '(.migrations_applied // []) | index("pre_xdg_specialists") // "null"' \
               "$state_file" 2>/dev/null)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$recorded" != "null" ] && [ -n "$recorded" ]; then
    printf "  PASS: migrations_applied records 'pre_xdg_specialists' even when absent\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: migrations_applied missing 'pre_xdg_specialists' on empty path\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
run_test test_migration_fixture_end_to_end
run_test test_source_repo_guard
run_test test_pre_xdg_specialists_migration
run_test test_already_migrated_specialists_no_op

print_summary
