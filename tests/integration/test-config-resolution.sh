#!/bin/bash
# test-config-resolution.sh — AC-4, AC-5
# Verifies resolve_config_value three-tier chain and XDG_CONFIG_HOME override.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-config-resolution.sh (AC-4, AC-5) ==="

FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT

_D="frw.d"
COMMON_SH="${PROJECT_ROOT}/bin/$_D/lib/common.sh"

# ---------------------------------------------------------------------------
# Helper: write YAML to a path, creating parent dirs
# ---------------------------------------------------------------------------
_write_yaml() {
  local path="$1" content="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
}

# ---------------------------------------------------------------------------
# test_three_tier_precedence
# AC-5a: project > XDG > compiled-in
# Strategy: put fixture yaml at FURROW_ROOT/.furrow/furrow.yaml (tier 3),
# back it up globally, restore in global trap.
# ---------------------------------------------------------------------------

# Global backup state for tier-3 yaml mutation
_T3_REAL_YAML="${PROJECT_ROOT}/.furrow/furrow.yaml"
_T3_BACKUP=""
_T3_HAD_YAML=0
if [ -f "$_T3_REAL_YAML" ]; then
  _T3_BACKUP="$(mktemp)"
  cp "$_T3_REAL_YAML" "$_T3_BACKUP"
  _T3_HAD_YAML=1
fi

_restore_tier3_yaml() {
  if [ "$_T3_HAD_YAML" = "1" ] && [ -n "$_T3_BACKUP" ] && [ -f "$_T3_BACKUP" ]; then
    cp "$_T3_BACKUP" "$_T3_REAL_YAML"
    rm -f "$_T3_BACKUP"
  else
    rm -f "$_T3_REAL_YAML"
  fi
}

# Register global cleanup
trap '_restore_tier3_yaml' EXIT

test_three_tier_precedence() {
  local tmp_proj tmp_xdg
  tmp_proj="$(mktemp -d)"
  tmp_xdg="$(mktemp -d)"

  # Write compiled-in tier (tier 3) into FURROW_ROOT's .furrow/furrow.yaml
  _write_yaml "$_T3_REAL_YAML" "cross_model:
  provider: gamma"

  # Set up tier 1 and tier 2
  _write_yaml "${tmp_proj}/.furrow/furrow.yaml" "cross_model:
  provider: alpha"
  _write_yaml "${tmp_xdg}/furrow/config.yaml" "cross_model:
  provider: beta"

  local result
  # All three tiers present: project wins
  result="$(PROJECT_ROOT="$tmp_proj" XDG_CONFIG_HOME="$tmp_xdg" \
    sh -c ". '$COMMON_SH' && resolve_config_value cross_model.provider")"
  assert_output_contains "tier-1 (project) wins over XDG+compiled-in" "$result" "alpha"

  # Remove project file: XDG wins
  rm "${tmp_proj}/.furrow/furrow.yaml"
  result="$(PROJECT_ROOT="$tmp_proj" XDG_CONFIG_HOME="$tmp_xdg" \
    sh -c ". '$COMMON_SH' && resolve_config_value cross_model.provider")"
  assert_output_contains "tier-2 (XDG) wins over compiled-in" "$result" "beta"

  # Remove XDG file: compiled-in wins
  rm "${tmp_xdg}/furrow/config.yaml"
  result="$(PROJECT_ROOT="$tmp_proj" XDG_CONFIG_HOME="$tmp_xdg" \
    sh -c ". '$COMMON_SH' && resolve_config_value cross_model.provider")"
  assert_output_contains "tier-3 (compiled-in) wins when others absent" "$result" "gamma"

  rm -rf "$tmp_proj" "$tmp_xdg"
}

# ---------------------------------------------------------------------------
# test_xdg_override
# AC-5b: XDG_CONFIG_HOME env redirects tier-2 reads to that dir
# ---------------------------------------------------------------------------
test_xdg_override() {
  local tmp_xdg tmp_proj
  tmp_xdg="$(mktemp -d)"
  tmp_proj="$(mktemp -d)"

  # Only XDG tier set, no project file
  _write_yaml "${tmp_xdg}/furrow/config.yaml" "gate_policy: strict"

  local result exit_code=0
  result="$(PROJECT_ROOT="$tmp_proj" XDG_CONFIG_HOME="$tmp_xdg" \
    sh -c ". '$COMMON_SH' && resolve_config_value gate_policy")" || exit_code=$?

  assert_exit_code "XDG override: exits 0 when key found" 0 "$exit_code"
  assert_output_contains "XDG override: returns 'strict'" "$result" "strict"

  rm -rf "$tmp_xdg" "$tmp_proj"
}

# ---------------------------------------------------------------------------
# test_unset_key_exits_1
# AC-5c: key absent from all tiers exits 1 with no stdout
# ---------------------------------------------------------------------------
test_unset_key_exits_1() {
  local tmp_proj tmp_xdg
  tmp_proj="$(mktemp -d)"
  tmp_xdg="$(mktemp -d)"
  # Ensure tier-3 has no matching key (real yaml may have cross_model etc but not this)
  local result exit_code=0
  result="$(PROJECT_ROOT="$tmp_proj" XDG_CONFIG_HOME="$tmp_xdg" \
    sh -c ". '$COMMON_SH' && resolve_config_value nonexistent.key.xyz123")" || exit_code=$?

  assert_exit_code "unset key: exits 1" 1 "$exit_code"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -z "$result" ]; then
    printf "  PASS: unset key: no stdout printed\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: unset key: unexpected stdout '%s'\n" "$result" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  rm -rf "$tmp_proj" "$tmp_xdg"
}

# ---------------------------------------------------------------------------
# test_resolve_function_exported
# AC-4: resolve_config_value and find_specialist available after sourcing common.sh
# ---------------------------------------------------------------------------
test_resolve_function_exported() {
  local exit_code=0
  sh -c "PROJECT_ROOT=/tmp XDG_CONFIG_HOME=/tmp . '$COMMON_SH' && command -v resolve_config_value > /dev/null" \
    || exit_code=$?
  assert_exit_code "resolve_config_value available after sourcing common.sh" 0 "$exit_code"

  exit_code=0
  sh -c "PROJECT_ROOT=/tmp XDG_CONFIG_HOME=/tmp . '$COMMON_SH' && command -v find_specialist > /dev/null" \
    || exit_code=$?
  assert_exit_code "find_specialist available after sourcing common.sh" 0 "$exit_code"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
run_test test_three_tier_precedence
run_test test_xdg_override
run_test test_unset_key_exits_1
run_test test_resolve_function_exported

print_summary
