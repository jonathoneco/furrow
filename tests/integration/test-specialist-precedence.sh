#!/bin/bash
# test-specialist-precedence.sh — AC-2
# Verifies find_specialist three-tier precedence:
#   (i)   project specialist wins when present
#   (ii)  XDG specialist wins when project is absent
#   (iii) compiled-in specialist wins when both above absent
#   (iv)  exit 1 + [furrow:error] when all three absent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-specialist-precedence.sh (AC-2) ==="

FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT

_D="frw.d"
COMMON_SH="${PROJECT_ROOT}/bin/$_D/lib/common.sh"

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
# _call_find_specialist <proj_root> <xdg_config_home> <specialist_name>
# Returns: path to specialist (stdout), exit code
# ---------------------------------------------------------------------------
_call_find_specialist() {
  local proj="$1" xdg="$2" name="$3"
  PROJECT_ROOT="$proj" XDG_CONFIG_HOME="$xdg" \
    sh -c ". '$COMMON_SH' && find_specialist '$name'"
}

# ---------------------------------------------------------------------------
# test_tier1_project_wins
# (i) tier-1 project specialist is returned when present
# ---------------------------------------------------------------------------
test_tier1_project_wins() {
  local tmp_proj tmp_xdg
  tmp_proj="$(_make_tmp_dir)"
  tmp_xdg="$(_make_tmp_dir)"

  # Create all three tiers
  mkdir -p "${tmp_proj}/specialists"
  printf '# project specialist\n' > "${tmp_proj}/specialists/harness-engineer.md"
  mkdir -p "${tmp_xdg}/furrow/specialists"
  printf '# xdg specialist\n' > "${tmp_xdg}/furrow/specialists/harness-engineer.md"
  mkdir -p "${FURROW_ROOT}/specialists"
  # compiled-in tier already exists in FURROW_ROOT/specialists/

  local result exit_code=0
  result="$(_call_find_specialist "$tmp_proj" "$tmp_xdg" "harness-engineer")" || exit_code=$?

  assert_exit_code "(i) tier-1: exits 0" 0 "$exit_code"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$result" = "${tmp_proj}/specialists/harness-engineer.md" ]; then
    printf "  PASS: (i) tier-1 (project) path returned: %s\n" "$result"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (i) tier-1: expected '%s', got '%s'\n" \
      "${tmp_proj}/specialists/harness-engineer.md" "$result" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_tier2_xdg_wins
# (ii) XDG wins when project specialist absent
# ---------------------------------------------------------------------------
test_tier2_xdg_wins() {
  local tmp_proj tmp_xdg
  tmp_proj="$(_make_tmp_dir)"
  tmp_xdg="$(_make_tmp_dir)"

  # No project tier
  mkdir -p "${tmp_proj}/specialists"
  # XDG tier present
  mkdir -p "${tmp_xdg}/furrow/specialists"
  printf '# xdg specialist\n' > "${tmp_xdg}/furrow/specialists/test-specialist.md"
  # No compiled-in for this name (harness-engineer exists but test-specialist doesn't)

  local result exit_code=0
  result="$(_call_find_specialist "$tmp_proj" "$tmp_xdg" "test-specialist")" || exit_code=$?

  assert_exit_code "(ii) tier-2: exits 0" 0 "$exit_code"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$result" = "${tmp_xdg}/furrow/specialists/test-specialist.md" ]; then
    printf "  PASS: (ii) tier-2 (XDG) path returned: %s\n" "$result"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (ii) tier-2: expected '%s', got '%s'\n" \
      "${tmp_xdg}/furrow/specialists/test-specialist.md" "$result" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_tier3_compiled_in_wins
# (iii) compiled-in wins when project and XDG absent
# ---------------------------------------------------------------------------
test_tier3_compiled_in_wins() {
  local tmp_proj tmp_xdg
  tmp_proj="$(_make_tmp_dir)"
  tmp_xdg="$(_make_tmp_dir)"

  # No project or XDG tiers for harness-engineer
  # harness-engineer.md should exist in FURROW_ROOT/specialists/
  if [ ! -f "${FURROW_ROOT}/specialists/harness-engineer.md" ]; then
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "  SKIP: (iii) harness-engineer.md not in FURROW_ROOT/specialists/ — skip\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  fi

  local result exit_code=0
  result="$(_call_find_specialist "$tmp_proj" "$tmp_xdg" "harness-engineer")" || exit_code=$?

  assert_exit_code "(iii) tier-3: exits 0" 0 "$exit_code"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$result" = "${FURROW_ROOT}/specialists/harness-engineer.md" ]; then
    printf "  PASS: (iii) tier-3 (compiled-in) path returned: %s\n" "$result"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (iii) tier-3: expected '%s', got '%s'\n" \
      "${FURROW_ROOT}/specialists/harness-engineer.md" "$result" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_not_found_exit1
# (iv) all three absent → exit 1, empty stdout, [furrow:error] on stderr
# ---------------------------------------------------------------------------
test_not_found_exit1() {
  local tmp_proj tmp_xdg
  tmp_proj="$(_make_tmp_dir)"
  tmp_xdg="$(_make_tmp_dir)"

  local result exit_code=0 stderr_out
  stderr_out="$(
    PROJECT_ROOT="$tmp_proj" XDG_CONFIG_HOME="$tmp_xdg" \
      sh -c ". '$COMMON_SH' && find_specialist 'nonexistent-specialist-xyz'" 2>&1 >/dev/null
  )" || exit_code=$?

  assert_exit_code "(iv) not-found: exits 1" 1 "$exit_code"

  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s' "$stderr_out" | grep -q "\[furrow:error\]"; then
    printf "  PASS: (iv) not-found: [furrow:error] emitted on stderr\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (iv) not-found: expected [furrow:error] on stderr, got: '%s'\n" \
      "$stderr_out" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # stdout must be empty
  local stdout_out
  stdout_out="$(
    PROJECT_ROOT="$tmp_proj" XDG_CONFIG_HOME="$tmp_xdg" \
      sh -c ". '$COMMON_SH' && find_specialist 'nonexistent-specialist-xyz'" 2>/dev/null
  )" || true

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -z "$stdout_out" ]; then
    printf "  PASS: (iv) not-found: no stdout\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: (iv) not-found: unexpected stdout '%s'\n" "$stdout_out" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
run_test test_tier1_project_wins
run_test test_tier2_xdg_wins
run_test test_tier3_compiled_in_wins
run_test test_not_found_exit1

print_summary
