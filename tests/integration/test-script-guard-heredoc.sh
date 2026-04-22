#!/bin/bash
# test-script-guard-heredoc.sh — Regression tests for script-guard heredoc tokenizer (AC-8)
#
# Tests that script-guard.sh correctly:
# - BLOCKS direct execution of frw.d/ paths in shell tokens
# - ALLOWS frw.d/ references inside single-quoted strings
# - ALLOWS frw.d/ references inside double-quoted strings
# - ALLOWS frw.d/ references inside heredoc bodies
# - ALLOWS frw.d/ references in shell comments

set -eu
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${TESTS_DIR}/helpers.sh"

# ─── Setup ──────────────────────────────────────────────────────────────────

setup_sg_env() {
  # Source the script-guard using the project's copy
  export FURROW_ROOT="${PROJECT_ROOT}"
  # Source minimal lib for log_error
  # shellcheck source=../../bin/frw.d/lib/common-minimal.sh
  d=frw.d
  . "${PROJECT_ROOT}/bin/${d}/lib/common-minimal.sh"
  . "${PROJECT_ROOT}/bin/${d}/hooks/script-guard.sh"
}

# Helper: invoke hook_script_guard with a synthetic JSON input
# Returns exit code of hook_script_guard
run_guard() {
  local cmd="$1"
  # Build JSON with jq to properly escape the command
  local json
  json="$(jq -n --arg cmd "$cmd" '{"tool_input":{"command":$cmd}}')"
  printf '%s' "$json" | hook_script_guard 2>/dev/null
  return $?
}

# ─── Test cases ─────────────────────────────────────────────────────────────

test_direct_execution_blocked() {
  printf '  --- test_direct_execution_blocked ---\n'
  local FD=frw.d

  # Case 4: ./frw.d/scripts/merge-execute.sh foo → block
  local exit_code=0
  run_guard "./${FD}/scripts/merge-execute.sh foo" || exit_code=$?
  assert_exit_code "direct ./ execution blocked" 2 "$exit_code"

  # Case 5: frw.d/scripts/merge-execute.sh; echo hi → block
  exit_code=0
  run_guard "${FD}/scripts/merge-execute.sh; echo hi" || exit_code=$?
  assert_exit_code "direct path before semicolon blocked" 2 "$exit_code"

  # Plain execution without qualifier → block
  exit_code=0
  run_guard "bash ${FD}/scripts/merge-execute.sh" || exit_code=$?
  assert_exit_code "bash direct execution blocked" 2 "$exit_code"
}

test_single_quoted_allowed() {
  printf '  --- test_single_quoted_allowed ---\n'
  local FD=frw.d

  # Case 1 variant: path inside single-quoted arg
  local exit_code=0
  run_guard "echo 'note: ${FD}/scripts/merge-execute.sh'" || exit_code=$?
  assert_exit_code "single-quoted reference allowed" 0 "$exit_code"

  # git commit -m 'fix: ...' with path in single-quoted message
  exit_code=0
  run_guard "git commit -m 'fix: tweak ${FD}/scripts/merge-execute.sh typo'" || exit_code=$?
  assert_exit_code "single-quoted commit message allowed" 0 "$exit_code"
}

test_double_quoted_allowed() {
  printf '  --- test_double_quoted_allowed ---\n'
  local FD=frw.d

  # Case 2: git commit -m "refactor: ..." with path in double-quoted message
  local exit_code=0
  run_guard 'git commit -m "refactor: tweak '"${FD}"'/hooks/script-guard.sh"' || exit_code=$?
  assert_exit_code "double-quoted commit message allowed" 0 "$exit_code"

  # Double-quoted string in echo
  exit_code=0
  run_guard "echo \"path is ${FD}/lib/common.sh\"" || exit_code=$?
  assert_exit_code "double-quoted echo allowed" 0 "$exit_code"
}

test_heredoc_body_allowed() {
  printf '  --- test_heredoc_body_allowed ---\n'
  local FD=frw.d

  # Case 3: heredoc containing path
  local heredoc_cmd
  heredoc_cmd="$(printf 'cat <<EOF\n%s/scripts/merge-execute.sh\nEOF' "${FD}")"
  local exit_code=0
  run_guard "$heredoc_cmd" || exit_code=$?
  assert_exit_code "heredoc body with path allowed" 0 "$exit_code"

  # Quoted heredoc
  heredoc_cmd="$(printf "cat <<'EOF'\n%s/scripts/merge-execute.sh\nEOF" "${FD}")"
  exit_code=0
  run_guard "$heredoc_cmd" || exit_code=$?
  assert_exit_code "quoted heredoc body with path allowed" 0 "$exit_code"
}

test_comment_allowed() {
  printf '  --- test_comment_allowed ---\n'
  local FD=frw.d

  # Comment containing path
  local exit_code=0
  run_guard "echo hi # note: ${FD}/ is protected" || exit_code=$?
  assert_exit_code "comment with path allowed" 0 "$exit_code"

  # Pure comment line
  exit_code=0
  run_guard "# ${FD}/scripts/some-script.sh" || exit_code=$?
  assert_exit_code "pure comment with path allowed" 0 "$exit_code"
}

test_read_only_verbs_allowed() {
  printf '  --- test_read_only_verbs_allowed ---\n'
  local FD=frw.d

  # cat, grep, etc. should still be allowed (existing behavior preserved)
  local exit_code=0
  run_guard "cat ${FD}/lib/common.sh" || exit_code=$?
  assert_exit_code "cat is allowed" 0 "$exit_code"

  exit_code=0
  run_guard "grep -n 'pattern' ${FD}/hooks/script-guard.sh" || exit_code=$?
  assert_exit_code "grep is allowed" 0 "$exit_code"
}

test_no_frwd_reference() {
  printf '  --- test_no_frwd_reference ---\n'

  # Commands with no frw.d/ reference at all → always allow
  local exit_code=0
  run_guard "git status" || exit_code=$?
  assert_exit_code "git status allowed" 0 "$exit_code"

  exit_code=0
  run_guard "ls -la bin/" || exit_code=$?
  assert_exit_code "ls bin/ allowed" 0 "$exit_code"
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
  printf 'test-script-guard-heredoc.sh\n'
  printf '==============================\n'

  setup_sg_env

  run_test test_direct_execution_blocked
  run_test test_single_quoted_allowed
  run_test test_double_quoted_allowed
  run_test test_heredoc_body_allowed
  run_test test_comment_allowed
  run_test test_read_only_verbs_allowed
  run_test test_no_frwd_reference

  print_summary
}

main "$@"
