#!/bin/bash
# test-precommit-bypass.sh — AC-D: escape-hatch audit trail verification
#
# Purpose: verify the hook BODY emits the correct warning when invoked directly,
# even though `git commit --no-verify` bypasses git's hook dispatch entirely.
# This tests the audit trail — not the git bypass itself.
#
# Per test-engineer guidance:
# - Set BOTH GIT_DIR and GIT_INDEX_FILE to isolated paths to avoid polluting caller state
# - Test the hook body directly (not via git commit)
# - Do NOT assert anything about `git commit --no-verify` stderr (git produces none)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-precommit-bypass.sh (AC-D / escape-hatch audit trail) ==="

PROJECT_ROOT_DIR="$PROJECT_ROOT"
_frwd="frw.d"
BAKFILES_HOOK="${PROJECT_ROOT_DIR}/bin/${_frwd}/hooks/pre-commit-bakfiles.sh"
TYPECHANGE_HOOK="${PROJECT_ROOT_DIR}/bin/${_frwd}/hooks/pre-commit-typechange.sh"

# ---------------------------------------------------------------------------
# test_bakfiles_hook_body_emits_warning
# ---------------------------------------------------------------------------
# Stage a contaminated .bak file in isolated git state, invoke hook body directly,
# assert: exit 1 + stderr contains the warning string.
test_bakfiles_hook_body_emits_warning() {
  local test_dir
  test_dir="$(mktemp -d)"
  trap 'rm -rf "$test_dir"' EXIT INT TERM

  # Initialize isolated git repo
  local isolated_git_dir="${test_dir}/.git"
  local isolated_index="${test_dir}/.git/index"

  (
    cd "$test_dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    mkdir -p bin &&
    printf 'init\n' > .gitkeep &&
    git add .gitkeep &&
    git commit -q -m "initial"
  )

  # Stage a contaminated .bak file in the isolated index
  (
    cd "$test_dir" &&
    printf 'install artifact\n' > bin/rws.bak &&
    GIT_DIR="$isolated_git_dir" \
    GIT_INDEX_FILE="$isolated_index" \
    git add -f bin/rws.bak
  )

  # Invoke hook body directly with isolated git state
  local stderr_out exit_code=0
  stderr_out="$(
    GIT_DIR="$isolated_git_dir" \
    GIT_INDEX_FILE="$isolated_index" \
    bash "$BAKFILES_HOOK" 2>&1
  )" || exit_code=$?

  assert_exit_code "bakfiles hook body exits 1 when .bak staged" 1 "$exit_code"
  assert_output_contains \
    "stderr contains refusing to stage install-artifact" \
    "$stderr_out" \
    "refusing to stage install-artifact"

  rm -rf "$test_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_typechange_hook_body_emits_warning
# ---------------------------------------------------------------------------
# Stage a typechange to symlink on bin/alm, invoke hook body directly,
# assert: exit 1 + stderr contains the warning string.
test_typechange_hook_body_emits_warning() {
  local test_dir
  test_dir="$(mktemp -d)"
  trap 'rm -rf "$test_dir"' EXIT INT TERM

  local isolated_git_dir="${test_dir}/.git"
  local isolated_index="${test_dir}/.git/index"

  # Set up a repo with bin/alm as a regular file
  (
    cd "$test_dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    mkdir -p bin &&
    printf '#!/bin/sh\necho alm\n' > bin/alm &&
    chmod +x bin/alm &&
    git add bin/alm &&
    git commit -q -m "initial"
  )

  # Replace regular file with symlink and stage it (typechange)
  (
    cd "$test_dir" &&
    rm bin/alm &&
    ln -s /tmp/fakex bin/alm &&
    GIT_DIR="$isolated_git_dir" \
    GIT_INDEX_FILE="$isolated_index" \
    git add bin/alm
  )

  # Invoke hook body directly
  local stderr_out exit_code=0
  stderr_out="$(
    GIT_DIR="$isolated_git_dir" \
    GIT_INDEX_FILE="$isolated_index" \
    bash "$TYPECHANGE_HOOK" 2>&1
  )" || exit_code=$?

  assert_exit_code "typechange hook body exits 1 when symlink staged on bin/alm" 1 "$exit_code"
  assert_output_contains \
    "stderr contains refusing type-change" \
    "$stderr_out" \
    "pre-commit: refusing type-change"

  rm -rf "$test_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_clean_index_passes_hook
# ---------------------------------------------------------------------------
# With a clean index (only normal file staged), hook body must exit 0.
test_clean_index_passes_hook() {
  local test_dir
  test_dir="$(mktemp -d)"
  trap 'rm -rf "$test_dir"' EXIT INT TERM

  local isolated_git_dir="${test_dir}/.git"
  local isolated_index="${test_dir}/.git/index"

  (
    cd "$test_dir" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    printf 'normal\n' > normal.txt &&
    GIT_DIR="$isolated_git_dir" \
    GIT_INDEX_FILE="$isolated_index" \
    git add normal.txt
  )

  local exit_code_bk=0
  GIT_DIR="$isolated_git_dir" \
  GIT_INDEX_FILE="$isolated_index" \
  bash "$BAKFILES_HOOK" > /dev/null 2>&1 || exit_code_bk=$?
  assert_exit_code "bakfiles hook exits 0 with clean index" 0 "$exit_code_bk"

  local exit_code_tc=0
  GIT_DIR="$isolated_git_dir" \
  GIT_INDEX_FILE="$isolated_index" \
  bash "$TYPECHANGE_HOOK" > /dev/null 2>&1 || exit_code_tc=$?
  assert_exit_code "typechange hook exits 0 with clean index" 0 "$exit_code_tc"

  rm -rf "$test_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
run_test test_bakfiles_hook_body_emits_warning
run_test test_typechange_hook_body_emits_warning
run_test test_clean_index_passes_hook

print_summary
