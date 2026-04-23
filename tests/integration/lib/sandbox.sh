#!/bin/sh
# sandbox.sh — POSIX sh sandbox library for integration tests.
#
# Source this file; do not execute directly.
#
# Exports three functions that together enforce the test-isolation contract:
#
#   setup_sandbox              — creates $TMP/{home,config,state,fixture},
#                                exports HOME, XDG_CONFIG_HOME, XDG_STATE_HOME,
#                                and FURROW_ROOT inside $TMP, prints the
#                                fixture dir on stdout.
#   snapshot_guard_targets     — writes sha256 sums for the protected path set
#                                to $TMP/guard.pre.sha256.
#   assert_no_worktree_mutation — recomputes sha256 sums and exits 1 with the
#                                 offending path on any drift.
#
# Contract (post-invocation): no code path inside the test may resolve any of
# HOME, XDG_CONFIG_HOME, XDG_STATE_HOME, FURROW_ROOT to a path outside $TMP.
#
# Protected-path set (AC-3):
#   (a) resolved targets of .claude/commands/specialist:*.md symlinks
#   (b) bin/alm, bin/rws, bin/sds
#   (c) .furrow/almanac/todos.yaml
#   (d) every file matching .claude/rules/*.md
#
# POSIX sh constraints: no [[, no arrays, no $'...'. sha256sum preferred;
# shasum -a 256 fallback for BSD environments.

# --- Resolve SANDBOX_PROJECT_ROOT (the live repo this file lives in) --------
# Used by snapshot functions to locate the protected path set. We resolve once
# at source time and export so subshells inherit a stable root even if tests
# cd elsewhere.
_sandbox_src_dir() {
  # Portable "dirname of this script". ${0} is unreliable when sourced; POSIX
  # has no BASH_SOURCE, so we rely on the PS4-free approach of requiring the
  # caller to have cd'd to the project root OR we walk up from $PWD to find
  # the nearest .git dir. Tests traditionally run from project root, but we
  # still search for robustness.
  _dir="${PWD}"
  while [ "${_dir}" != "/" ]; do
    if [ -d "${_dir}/.git" ] && [ -d "${_dir}/tests/integration/lib" ]; then
      printf '%s' "${_dir}"
      return 0
    fi
    _dir="$(dirname "${_dir}")"
  done
  # Fallback: assume cwd is project root.
  printf '%s' "${PWD}"
}

if [ -z "${SANDBOX_PROJECT_ROOT:-}" ]; then
  SANDBOX_PROJECT_ROOT="$(_sandbox_src_dir)"
  export SANDBOX_PROJECT_ROOT
fi

# --- sha256 shim -----------------------------------------------------------
_sandbox_sha256() {
  # Reads a file, prints "<hash>  <path>" on stdout.
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1"
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1"
  else
    printf 'sandbox.sh: neither sha256sum nor shasum found\n' >&2
    return 1
  fi
}

# --- setup_sandbox ---------------------------------------------------------
# Creates $TMP/{home,config,state,fixture}; exports HOME, XDG_CONFIG_HOME,
# XDG_STATE_HOME, FURROW_ROOT inside $TMP. Prints fixture dir on stdout.
# If $TMP is unset or empty, allocates a fresh mktemp -d.
setup_sandbox() {
  if [ -z "${TMP:-}" ]; then
    TMP="$(mktemp -d)"
    export TMP
  fi

  mkdir -p "${TMP}/home" "${TMP}/config" "${TMP}/state" "${TMP}/fixture" \
    || return 1

  HOME="${TMP}/home"
  XDG_CONFIG_HOME="${TMP}/config"
  XDG_STATE_HOME="${TMP}/state"
  FURROW_ROOT="${TMP}/fixture"
  export HOME XDG_CONFIG_HOME XDG_STATE_HOME FURROW_ROOT

  printf '%s\n' "${TMP}/fixture"
}

# --- _sandbox_enumerate_targets -------------------------------------------
# Prints the protected path set (one absolute path per line) to stdout.
# Resolves specialist symlinks to their targets; plain files printed as-is.
# Silent when a category has no matches (glob fails) — absence is not drift.
_sandbox_enumerate_targets() {
  _root="${SANDBOX_PROJECT_ROOT}"

  # (a) specialist symlink targets
  for _link in "${_root}/.claude/commands/"specialist:*.md; do
    [ -e "${_link}" ] || continue
    # Resolve symlink to its target. readlink -f works on Linux (coreutils)
    # and on BSD only with readlink from coreutils-like tools. Fall back to
    # manual resolution: if it's a symlink, use `readlink` (POSIX) and join.
    if _target="$(readlink -f "${_link}" 2>/dev/null)" && [ -n "${_target}" ]; then
      printf '%s\n' "${_target}"
    else
      # Manual resolution for BSD readlink (no -f): join against link dir.
      _raw="$(readlink "${_link}" 2>/dev/null)" || continue
      case "${_raw}" in
        /*) printf '%s\n' "${_raw}" ;;
        *)  printf '%s\n' "$(cd "$(dirname "${_link}")" && cd "$(dirname "${_raw}")" && pwd)/$(basename "${_raw}")" ;;
      esac
    fi
  done

  # (b) binaries
  for _bin in alm rws sds; do
    _p="${_root}/bin/${_bin}"
    [ -e "${_p}" ] && printf '%s\n' "${_p}"
  done

  # (c) todos
  _t="${_root}/.furrow/almanac/todos.yaml"
  [ -e "${_t}" ] && printf '%s\n' "${_t}"

  # (d) rules
  for _rule in "${_root}/.claude/rules/"*.md; do
    [ -e "${_rule}" ] || continue
    printf '%s\n' "${_rule}"
  done
}

# --- snapshot_guard_targets ------------------------------------------------
# Writes sha256 sums for the protected set to $TMP/guard.pre.sha256.
# Line count equals the number of matching paths at invocation time (AC-3).
snapshot_guard_targets() {
  if [ -z "${TMP:-}" ]; then
    printf 'snapshot_guard_targets: TMP is unset — call setup_sandbox first\n' >&2
    return 1
  fi

  _out="${TMP}/guard.pre.sha256"
  : > "${_out}" || return 1

  _sandbox_enumerate_targets | while IFS= read -r _path; do
    [ -n "${_path}" ] || continue
    _sandbox_sha256 "${_path}" >> "${_out}" || return 1
  done
}

# --- assert_no_worktree_mutation ------------------------------------------
# Recomputes sha256 sums for the same paths, diffs against
# $TMP/guard.pre.sha256. Prints offending path(s) + pre/post digests to
# stderr and exits 1 on any drift. Exit 0 on clean match.
assert_no_worktree_mutation() {
  if [ -z "${TMP:-}" ]; then
    printf 'assert_no_worktree_mutation: TMP is unset\n' >&2
    return 1
  fi

  _pre="${TMP}/guard.pre.sha256"
  _post="${TMP}/guard.post.sha256"

  if [ ! -f "${_pre}" ]; then
    printf 'assert_no_worktree_mutation: no pre-snapshot at %s — did you call snapshot_guard_targets?\n' \
      "${_pre}" >&2
    return 1
  fi

  : > "${_post}" || return 1
  _sandbox_enumerate_targets | while IFS= read -r _path; do
    [ -n "${_path}" ] || continue
    _sandbox_sha256 "${_path}" >> "${_post}" || return 1
  done

  if diff -u "${_pre}" "${_post}" >/dev/null 2>&1; then
    return 0
  fi

  # Drift detected — surface every differing path with pre/post digests.
  printf 'assert_no_worktree_mutation: protected paths mutated:\n' >&2
  # Join on path (second column); print lines that differ.
  diff "${_pre}" "${_post}" >&2 || true
  return 1
}
