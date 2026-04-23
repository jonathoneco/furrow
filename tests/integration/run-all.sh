#!/bin/sh
# run-all.sh — Central integration-test entrypoint with CI-level sandbox guard.
#
# Invariants (AC-4):
#   1. `git status --porcelain` is empty before any test runs; non-empty is a
#      hard failure with the offending output printed to stderr.
#   2. Every tests/integration/test-*.sh is executed in a subshell with
#      `set -e` semantics.
#   3. `git status --porcelain` is empty after the suite; non-empty is a hard
#      failure with the diff printed.
#
# Exit code 0 iff pre-check clean, every test exited 0, and post-check clean.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

# --- Pre-check: worktree must be clean ------------------------------------
_pre_dirt="$(git status --porcelain)"
if [ -n "${_pre_dirt}" ]; then
  printf 'run-all.sh: worktree is dirty before suite:\n%s\n' "${_pre_dirt}" >&2
  exit 1
fi

# --- Run every test-*.sh in its own subshell ------------------------------
_failures=0
_passed=0
_total=0

for _test in "${SCRIPT_DIR}"/test-*.sh; do
  [ -f "${_test}" ] || continue
  _total=$((_total + 1))
  _name="$(basename "${_test}")"
  printf '\n>>> %s\n' "${_name}"
  if ( set -e; "${_test}" ); then
    _passed=$((_passed + 1))
  else
    _rc=$?
    _failures=$((_failures + 1))
    printf 'run-all.sh: %s FAILED with exit %s\n' "${_name}" "${_rc}" >&2
  fi
done

printf '\n==========================================\n'
printf 'run-all.sh: %s passed / %s failed / %s total\n' \
  "${_passed}" "${_failures}" "${_total}"
printf '==========================================\n'

# --- Post-check: worktree must still be clean -----------------------------
_post_dirt="$(git status --porcelain)"
if [ -n "${_post_dirt}" ]; then
  printf 'run-all.sh: worktree mutated during suite:\n%s\n' "${_post_dirt}" >&2
  exit 1
fi

if [ "${_failures}" -gt 0 ]; then
  exit 1
fi
exit 0
