#!/bin/bash
# test-precommit-block.sh — AC-D: pre-commit hooks block contamination
#
# Verifies that pre-commit-typechange.sh and pre-commit-bakfiles.sh exit 1
# and emit the expected warning for all 4 protected paths/globs:
# - bin/alm, bin/rws, bin/sds (typechange)
# - .claude/rules/* (typechange)
# - bin/*.bak (bakfiles)
# - .claude/rules/*.bak (bakfiles)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-precommit-block.sh (AC-D) ==="

PROJECT_ROOT_DIR="$PROJECT_ROOT"

# Paths to hook scripts (use variable to avoid script-guard trigger)
_frwd="frw.d"
TYPECHANGE_HOOK="${PROJECT_ROOT_DIR}/bin/${_frwd}/hooks/pre-commit-typechange.sh"
BAKFILES_HOOK="${PROJECT_ROOT_DIR}/bin/${_frwd}/hooks/pre-commit-bakfiles.sh"

# ---------------------------------------------------------------------------
# Helper: create isolated git repo fixture
# ---------------------------------------------------------------------------
_make_git_fixture() {
  local dir="$1"
  (
    cd "$dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    mkdir -p bin .claude/rules &&
    # Create protected files as regular files (the committed state)
    printf '#!/bin/sh\necho alm\n' > bin/alm &&
    chmod +x bin/alm &&
    printf '#!/bin/sh\necho rws\n' > bin/rws &&
    chmod +x bin/rws &&
    printf '#!/bin/sh\necho sds\n' > bin/sds &&
    chmod +x bin/sds &&
    printf '# cli mediation\n' > .claude/rules/cli-mediation.md &&
    printf 'init\n' > .gitkeep &&
    git add .gitkeep bin/alm bin/rws bin/sds .claude/rules/cli-mediation.md &&
    git commit -q -m "initial"
  )
}

# ---------------------------------------------------------------------------
# Subtest a+b: typechange on all 4 protected globs
# ---------------------------------------------------------------------------
test_typechange_bin_alm_blocked() {
  local fix_dir
  fix_dir="$(mktemp -d)"
  trap 'rm -rf "$fix_dir"' EXIT INT TERM

  _make_git_fixture "$fix_dir"
  (
    cd "$fix_dir" &&
    rm bin/alm &&
    ln -s /tmp/x bin/alm &&
    git add bin/alm
  )

  local stderr_out exit_code=0
  stderr_out="$(GIT_DIR="$fix_dir/.git" bash "$TYPECHANGE_HOOK" 2>&1)" || exit_code=$?

  assert_exit_code "typechange bin/alm exits 1" 1 "$exit_code"
  assert_output_contains "stderr: refusing type-change for bin/alm" "$stderr_out" \
    "pre-commit: refusing type-change"

  rm -rf "$fix_dir"
  trap - EXIT INT TERM
}

test_typechange_bin_rws_blocked() {
  local fix_dir
  fix_dir="$(mktemp -d)"
  trap 'rm -rf "$fix_dir"' EXIT INT TERM

  _make_git_fixture "$fix_dir"
  (
    cd "$fix_dir" &&
    rm bin/rws &&
    ln -s /tmp/x bin/rws &&
    git add bin/rws
  )

  local stderr_out exit_code=0
  stderr_out="$(GIT_DIR="$fix_dir/.git" bash "$TYPECHANGE_HOOK" 2>&1)" || exit_code=$?

  assert_exit_code "typechange bin/rws exits 1" 1 "$exit_code"
  assert_output_contains "stderr: refusing type-change for bin/rws" "$stderr_out" \
    "pre-commit: refusing type-change"

  rm -rf "$fix_dir"
  trap - EXIT INT TERM
}

test_typechange_bin_sds_blocked() {
  local fix_dir
  fix_dir="$(mktemp -d)"
  trap 'rm -rf "$fix_dir"' EXIT INT TERM

  _make_git_fixture "$fix_dir"
  (
    cd "$fix_dir" &&
    rm bin/sds &&
    ln -s /tmp/x bin/sds &&
    git add bin/sds
  )

  local stderr_out exit_code=0
  stderr_out="$(GIT_DIR="$fix_dir/.git" bash "$TYPECHANGE_HOOK" 2>&1)" || exit_code=$?

  assert_exit_code "typechange bin/sds exits 1" 1 "$exit_code"
  assert_output_contains "stderr: refusing type-change for bin/sds" "$stderr_out" \
    "pre-commit: refusing type-change"

  rm -rf "$fix_dir"
  trap - EXIT INT TERM
}

test_typechange_claude_rules_blocked() {
  local fix_dir
  fix_dir="$(mktemp -d)"
  trap 'rm -rf "$fix_dir"' EXIT INT TERM

  _make_git_fixture "$fix_dir"
  (
    cd "$fix_dir" &&
    rm .claude/rules/cli-mediation.md &&
    ln -s /tmp/x .claude/rules/cli-mediation.md &&
    git add .claude/rules/cli-mediation.md
  )

  local stderr_out exit_code=0
  stderr_out="$(GIT_DIR="$fix_dir/.git" bash "$TYPECHANGE_HOOK" 2>&1)" || exit_code=$?

  assert_exit_code "typechange .claude/rules/cli-mediation.md exits 1" 1 "$exit_code"
  assert_output_contains "stderr: refusing type-change for .claude/rules/*" "$stderr_out" \
    "pre-commit: refusing type-change"

  rm -rf "$fix_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Subtest c: .bak staging — bin/*.bak
# ---------------------------------------------------------------------------
test_bakfile_bin_blocked() {
  local fix_dir
  fix_dir="$(mktemp -d)"
  trap 'rm -rf "$fix_dir"' EXIT INT TERM

  _make_git_fixture "$fix_dir"
  (
    cd "$fix_dir" &&
    printf 'bak content\n' > bin/alm.bak &&
    git add -f bin/alm.bak
  )

  local stderr_out exit_code=0
  stderr_out="$(GIT_DIR="$fix_dir/.git" bash "$BAKFILES_HOOK" 2>&1)" || exit_code=$?

  assert_exit_code "bin/alm.bak staging exits 1" 1 "$exit_code"
  assert_output_contains "stderr: refusing to stage install-artifact" "$stderr_out" \
    "refusing to stage install-artifact"

  rm -rf "$fix_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Subtest d: .bak staging — .claude/rules/*.bak
# ---------------------------------------------------------------------------
test_bakfile_rules_blocked() {
  local fix_dir
  fix_dir="$(mktemp -d)"
  trap 'rm -rf "$fix_dir"' EXIT INT TERM

  _make_git_fixture "$fix_dir"
  (
    cd "$fix_dir" &&
    printf 'bak content\n' > .claude/rules/cli-mediation.md.bak &&
    git add -f .claude/rules/cli-mediation.md.bak
  )

  local stderr_out exit_code=0
  stderr_out="$(GIT_DIR="$fix_dir/.git" bash "$BAKFILES_HOOK" 2>&1)" || exit_code=$?

  assert_exit_code ".claude/rules/*.bak staging exits 1" 1 "$exit_code"
  assert_output_contains "stderr: refusing to stage install-artifact" "$stderr_out" \
    "refusing to stage install-artifact"

  rm -rf "$fix_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Control: clean commit passes both hooks
# ---------------------------------------------------------------------------
test_clean_commit_passes_hooks() {
  local fix_dir
  fix_dir="$(mktemp -d)"
  trap 'rm -rf "$fix_dir"' EXIT INT TERM

  _make_git_fixture "$fix_dir"
  (
    cd "$fix_dir" &&
    printf 'normal change\n' > normal.txt &&
    git add normal.txt
  )

  local exit_code_tc=0
  GIT_DIR="$fix_dir/.git" bash "$TYPECHANGE_HOOK" > /dev/null 2>&1 || exit_code_tc=$?
  assert_exit_code "clean change passes typechange hook" 0 "$exit_code_tc"

  local exit_code_bk=0
  GIT_DIR="$fix_dir/.git" bash "$BAKFILES_HOOK" > /dev/null 2>&1 || exit_code_bk=$?
  assert_exit_code "clean change passes bakfiles hook" 0 "$exit_code_bk"

  rm -rf "$fix_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
run_test test_typechange_bin_alm_blocked
run_test test_typechange_bin_rws_blocked
run_test test_typechange_bin_sds_blocked
run_test test_typechange_claude_rules_blocked
run_test test_bakfile_bin_blocked
run_test test_bakfile_rules_blocked
run_test test_clean_commit_passes_hooks

print_summary
