#!/bin/bash
# test-upgrade-idempotency.sh — AC-7
# Verifies frw upgrade --apply is idempotent:
#   - First run exits 0, produces expected files
#   - Second run exits 0 with zero bytewise diff on all written files
#   - install-state.json has migration_version="1.0" after first run,
#     unchanged after second run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-upgrade-idempotency.sh (AC-7) ==="

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
# _compute_slug <dir>: compute upgrade.sh-compatible slug for a git repo
# Mirrors _upgrade_repo_slug: git rev-parse from inside dir, then normalize.
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
# _write_state_json <state_file> <slug> <repo_root> <migration_version>
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
# Runs in a subshell to isolate cwd from the test process.
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
# test_idempotency
# ---------------------------------------------------------------------------
test_idempotency() {
  local fixture_dir xdg_cfg_dir xdg_state_dir
  fixture_dir="$(_make_tmp_dir)"
  xdg_cfg_dir="$(_make_tmp_dir)"
  xdg_state_dir="$(_make_tmp_dir)"

  # Build legacy install fixture
  "$FIXTURE_MAKER" "$fixture_dir"

  # Write minimal install-state.json (migration_version="0")
  local slug
  slug="$(_compute_slug "$fixture_dir")"
  local state_file="${xdg_state_dir}/furrow/${slug}/install-state.json"
  _write_state_json "$state_file" "$slug" "$fixture_dir" "0"

  # ---- First run ----
  local exit1=0
  _frw_upgrade "$fixture_dir" "$xdg_cfg_dir" "$xdg_state_dir" --apply \
    --from "${fixture_dir}/.claude/furrow.yaml" || exit1=$?

  assert_exit_code "first frw upgrade --apply exits 0" 0 "$exit1"
  assert_file_exists "XDG config.yaml created on first run" \
    "${xdg_cfg_dir}/furrow/config.yaml"
  assert_file_exists "promotion-targets.yaml created on first run" \
    "${xdg_cfg_dir}/furrow/promotion-targets.yaml"

  local mv1
  mv1="$(jq -r '.migration_version' "$state_file" 2>/dev/null)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$mv1" = "1.0" ]; then
    printf "  PASS: migration_version='1.0' after first run\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: migration_version expected '1.0', got '%s'\n" "$mv1" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Capture hashes before second run
  local cfg_hash1 pt_hash1
  cfg_hash1="$(sha256sum "${xdg_cfg_dir}/furrow/config.yaml" | awk '{print $1}')"
  pt_hash1="$(sha256sum "${xdg_cfg_dir}/furrow/promotion-targets.yaml" | awk '{print $1}')"

  # ---- Second run ----
  local exit2=0
  _frw_upgrade "$fixture_dir" "$xdg_cfg_dir" "$xdg_state_dir" --apply \
    --from "${fixture_dir}/.claude/furrow.yaml" || exit2=$?

  assert_exit_code "second frw upgrade --apply exits 0" 0 "$exit2"

  local cfg_hash2 pt_hash2
  cfg_hash2="$(sha256sum "${xdg_cfg_dir}/furrow/config.yaml" | awk '{print $1}')"
  pt_hash2="$(sha256sum "${xdg_cfg_dir}/furrow/promotion-targets.yaml" | awk '{print $1}')"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$cfg_hash1" = "$cfg_hash2" ]; then
    printf "  PASS: config.yaml unchanged after second run\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: config.yaml changed after second run\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$pt_hash1" = "$pt_hash2" ]; then
    printf "  PASS: promotion-targets.yaml unchanged after second run\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: promotion-targets.yaml changed after second run\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  local mv2
  mv2="$(jq -r '.migration_version' "$state_file" 2>/dev/null)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$mv2" = "1.0" ]; then
    printf "  PASS: migration_version unchanged ('1.0') after second run\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: migration_version changed after second run, got '%s'\n" "$mv2" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_check_mode_exits_10_when_migration_needed
# ---------------------------------------------------------------------------
test_check_mode_exits_10_when_migration_needed() {
  local fixture_dir xdg_cfg_dir xdg_state_dir
  fixture_dir="$(_make_tmp_dir)"
  xdg_cfg_dir="$(_make_tmp_dir)"
  xdg_state_dir="$(_make_tmp_dir)"

  "$FIXTURE_MAKER" "$fixture_dir"
  # No install-state.json and no XDG config → migration needed

  local exit_code=0
  _frw_upgrade "$fixture_dir" "$xdg_cfg_dir" "$xdg_state_dir" --check || exit_code=$?

  assert_exit_code "frw upgrade --check exits 10 when migration needed" 10 "$exit_code"
}

# ---------------------------------------------------------------------------
# test_check_mode_exits_0_when_current
# ---------------------------------------------------------------------------
test_check_mode_exits_0_when_current() {
  local fixture_dir xdg_cfg_dir xdg_state_dir
  fixture_dir="$(_make_tmp_dir)"
  xdg_cfg_dir="$(_make_tmp_dir)"
  xdg_state_dir="$(_make_tmp_dir)"

  "$FIXTURE_MAKER" "$fixture_dir"

  # Set up already-migrated state
  local slug
  slug="$(_compute_slug "$fixture_dir")"
  local state_file="${xdg_state_dir}/furrow/${slug}/install-state.json"
  _write_state_json "$state_file" "$slug" "$fixture_dir" "1.0"

  # Also create XDG config and promotion-targets (already migrated)
  mkdir -p "${xdg_cfg_dir}/furrow"
  printf 'gate_policy: supervised\n' > "${xdg_cfg_dir}/furrow/config.yaml"
  printf 'targets: []\n' > "${xdg_cfg_dir}/furrow/promotion-targets.yaml"

  local exit_code=0
  _frw_upgrade "$fixture_dir" "$xdg_cfg_dir" "$xdg_state_dir" --check || exit_code=$?

  assert_exit_code "frw upgrade --check exits 0 when already current" 0 "$exit_code"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
run_test test_idempotency
run_test test_check_mode_exits_10_when_migration_needed
run_test test_check_mode_exits_0_when_current

print_summary
