#!/bin/bash
# test-resolver-exports.sh — AC-4
# Verifies:
#   (a) docs/architecture/config-resolution.md exists and contains PROJECT_ROOT,
#       XDG_CONFIG_HOME, FURROW_ROOT in that order
#   (b) sourcing common.sh makes resolve_config_value and find_specialist available

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-resolver-exports.sh (AC-4) ==="

FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT

_D="frw.d"
COMMON_SH="${PROJECT_ROOT}/bin/$_D/lib/common.sh"
CONFIG_DOC="${PROJECT_ROOT}/docs/architecture/config-resolution.md"

# ---------------------------------------------------------------------------
# test_doc_exists_with_required_terms
# AC-4a: config-resolution.md exists and contains the three tier names in order
# ---------------------------------------------------------------------------
test_doc_exists_with_required_terms() {
  assert_file_exists "docs/architecture/config-resolution.md exists" "$CONFIG_DOC"

  # Check each term is present
  for term in "PROJECT_ROOT" "XDG_CONFIG_HOME" "FURROW_ROOT"; do
    TESTS_RUN=$((TESTS_RUN + 1))
    if grep -qF "$term" "$CONFIG_DOC" 2>/dev/null; then
      printf "  PASS: doc contains '%s'\n" "$term"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      printf "  FAIL: doc missing '%s'\n" "$term" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  done

  # Verify order: the chain line "PROJECT_ROOT → XDG_CONFIG_HOME → FURROW_ROOT"
  # appears in the doc (the actual chain description, not just mentions)
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "PROJECT_ROOT.*XDG_CONFIG_HOME.*FURROW_ROOT" "$CONFIG_DOC" 2>/dev/null; then
    printf "  PASS: doc contains chain 'PROJECT_ROOT → XDG_CONFIG_HOME → FURROW_ROOT'\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: doc missing chain 'PROJECT_ROOT → XDG_CONFIG_HOME → FURROW_ROOT'\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_functions_exported_after_sourcing
# AC-4b: resolve_config_value and find_specialist are available after sourcing common.sh
# ---------------------------------------------------------------------------
test_functions_exported_after_sourcing() {
  local exit_code=0
  sh -c "PROJECT_ROOT=/tmp XDG_CONFIG_HOME=/tmp . '$COMMON_SH' && command -v resolve_config_value > /dev/null" \
    || exit_code=$?
  assert_exit_code "resolve_config_value available (command -v exits 0)" 0 "$exit_code"

  exit_code=0
  sh -c "PROJECT_ROOT=/tmp XDG_CONFIG_HOME=/tmp . '$COMMON_SH' && command -v find_specialist > /dev/null" \
    || exit_code=$?
  assert_exit_code "find_specialist available (command -v exits 0)" 0 "$exit_code"
}

# ---------------------------------------------------------------------------
# test_common_sh_not_common_minimal
# AC-4: functions are in common.sh, NOT in common-minimal.sh
# ---------------------------------------------------------------------------
test_common_sh_not_common_minimal() {
  local min_sh="${PROJECT_ROOT}/bin/$_D/lib/common-minimal.sh"

  # resolve_config_value must NOT be in common-minimal.sh
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! grep -q "resolve_config_value" "$min_sh" 2>/dev/null; then
    printf "  PASS: resolve_config_value not in common-minimal.sh\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: resolve_config_value found in common-minimal.sh (should not be hook-safe)\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if ! grep -q "find_specialist" "$min_sh" 2>/dev/null; then
    printf "  PASS: find_specialist not in common-minimal.sh\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: find_specialist found in common-minimal.sh (should not be hook-safe)\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Both functions MUST be in common.sh
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "resolve_config_value()" "$COMMON_SH" 2>/dev/null; then
    printf "  PASS: resolve_config_value defined in common.sh\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: resolve_config_value not found in common.sh\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "find_specialist()" "$COMMON_SH" 2>/dev/null; then
    printf "  PASS: find_specialist defined in common.sh\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: find_specialist not found in common.sh\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
run_test test_doc_exists_with_required_terms
run_test test_functions_exported_after_sourcing
run_test test_common_sh_not_common_minimal

print_summary
