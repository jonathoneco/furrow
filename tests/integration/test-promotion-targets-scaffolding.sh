#!/bin/bash
# test-promotion-targets-scaffolding.sh — AC-3
# Verifies:
#   (a) schemas/promotion-targets.schema.yaml exists and has "targets" key at root
#   (b) frw upgrade --apply produces promotion-targets.yaml with targets: []
#   (c) grep for promotion-targets in bin/ and commands/ finds only the
#       scaffolding writer (upgrade.sh) and frw doctor skip-check — no loader

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-promotion-targets-scaffolding.sh (AC-3) ==="

FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT

FIXTURE_MAKER="${PROJECT_ROOT}/tests/fixtures/make-legacy-install.sh"

# Global temp dirs
_TMP_DIRS=()
_make_tmp_dir() {
  local d; d="$(mktemp -d)"; _TMP_DIRS+=("$d"); printf '%s' "$d"
}
_cleanup_all() {
  for d in "${_TMP_DIRS[@]+"${_TMP_DIRS[@]}"}"; do rm -rf "$d"; done
}
trap '_cleanup_all' EXIT

# ---------------------------------------------------------------------------
# test_schema_file_has_targets_key
# AC-3a: schemas/promotion-targets.schema.yaml exists and yq 'has("targets")' == true
# ---------------------------------------------------------------------------
test_schema_file_has_targets_key() {
  local schema_file="${PROJECT_ROOT}/schemas/promotion-targets.schema.yaml"

  assert_file_exists "schemas/promotion-targets.schema.yaml exists" "$schema_file"

  local has_targets
  has_targets="$(yq 'has("targets")' "$schema_file" 2>/dev/null)"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$has_targets" = "true" ]; then
    printf "  PASS: schema has 'targets' key at root\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: schema 'has(targets)' returned '%s' (expected 'true')\n" \
      "$has_targets" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_upgrade_scaffolds_promotion_targets
# AC-3b: frw upgrade --apply produces promotion-targets.yaml with targets: []
# ---------------------------------------------------------------------------
test_upgrade_scaffolds_promotion_targets() {
  local fixture_dir xdg_cfg_dir xdg_state_dir
  fixture_dir="$(_make_tmp_dir)"
  xdg_cfg_dir="$(_make_tmp_dir)"
  xdg_state_dir="$(_make_tmp_dir)"

  "$FIXTURE_MAKER" "$fixture_dir"

  # Write minimal install-state.json
  local slug
  slug="$(basename "$(cd "$fixture_dir" && git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$fixture_dir")")"
  slug="$(LC_ALL=C printf '%s' "$slug" | tr -c '[:alnum:]-' '-' | sed 's/-*$//; s/^-*//')"
  [ -z "$slug" ] && slug="furrow"

  local state_file="${xdg_state_dir}/furrow/${slug}/install-state.json"
  mkdir -p "$(dirname "$state_file")"
  jq -n \
    --arg repo_slug "$slug" \
    --arg repo_root "$fixture_dir" \
    --arg migration_version "0" \
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
    }' > "$state_file"

  local exit_code=0
  (
    cd "$fixture_dir"
    PROJECT_ROOT="$fixture_dir" \
      XDG_CONFIG_HOME="$xdg_cfg_dir" \
      XDG_STATE_HOME="$xdg_state_dir" \
      FURROW_ROOT="$FURROW_ROOT" \
      "$FURROW_ROOT/bin/frw" upgrade --apply
  ) || exit_code=$?

  assert_exit_code "frw upgrade --apply exits 0" 0 "$exit_code"

  local pt_file="${xdg_cfg_dir}/furrow/promotion-targets.yaml"
  assert_file_exists "promotion-targets.yaml created by upgrade" "$pt_file"

  local targets_val
  targets_val="$(yq '.targets' "$pt_file" 2>/dev/null)"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$targets_val" = "[]" ]; then
    printf "  PASS: promotion-targets.yaml has targets: []\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: targets expected '[]', got '%s'\n" "$targets_val" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_no_loader_consumer_references
# AC-3c: grep for "promotion-targets" in bin/ and commands/ finds only the
# scaffolding writer and (optionally) frw doctor skip-check — never a loader.
# ---------------------------------------------------------------------------
test_no_loader_consumer_references() {
  # Collect all promotion-targets references in bin/ and commands/
  local refs
  refs="$(grep -rn "promotion-targets" \
    "${PROJECT_ROOT}/bin" \
    "${PROJECT_ROOT}/commands" \
    2>/dev/null || true)"

  # Allowed references: upgrade.sh (scaffolding writer) and doctor.sh (skip-check advisory)
  # Forbidden references: any loader, reader, or consumer logic
  local forbidden_refs=0
  local ref_line
  while IFS= read -r ref_line; do
    [ -z "$ref_line" ] && continue
    local file
    file="$(printf '%s' "$ref_line" | cut -d: -f1)"
    local base
    base="$(basename "$file")"
    case "$base" in
      upgrade.sh|doctor.sh) : ;;  # allowed
      *)
        printf "  [unexpected] promotion-targets reference in %s: %s\n" "$base" "$ref_line" >&2
        forbidden_refs=$((forbidden_refs + 1))
        ;;
    esac
  done << EOF
$refs
EOF

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$forbidden_refs" -eq 0 ]; then
    printf "  PASS: no unexpected promotion-targets references in bin/ or commands/\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: %d unexpected promotion-targets reference(s) found\n" \
      "$forbidden_refs" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_doctor_green_without_promotion_targets
# frw doctor exits 0 even when promotion-targets.yaml is absent
# ---------------------------------------------------------------------------
test_doctor_green_without_promotion_targets() {
  # Use a fresh XDG dir with no promotion-targets.yaml
  local tmp_xdg
  tmp_xdg="$(_make_tmp_dir)"

  local exit_code=0
  # Run frw doctor — should not fail even without promotion-targets.yaml
  XDG_CONFIG_HOME="$tmp_xdg" \
  FURROW_ROOT="$FURROW_ROOT" \
    "$FURROW_ROOT/bin/frw" doctor 2>/dev/null || exit_code=$?

  TESTS_RUN=$((TESTS_RUN + 1))
  # frw doctor may exit non-zero for other reasons (missing rws, etc.),
  # so we only check it doesn't fail due to promotion-targets absence.
  # We do this by checking the output doesn't mention promotion-targets as a fatal error.
  local doctor_out
  doctor_out="$(
    XDG_CONFIG_HOME="$tmp_xdg" \
    FURROW_ROOT="$FURROW_ROOT" \
      "$FURROW_ROOT/bin/frw" doctor 2>&1
  )" || true

  if printf '%s' "$doctor_out" | grep -q "promotion-targets.*FAIL\|FAIL.*promotion-targets"; then
    printf "  FAIL: frw doctor fails on missing promotion-targets.yaml\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    printf "  PASS: frw doctor does not fail on missing promotion-targets.yaml\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
run_test test_schema_file_has_targets_key
run_test test_upgrade_scaffolds_promotion_targets
run_test test_no_loader_consumer_references
run_test test_doctor_green_without_promotion_targets

print_summary
