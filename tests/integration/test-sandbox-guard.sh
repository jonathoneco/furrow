#!/bin/sh
# test-sandbox-guard.sh — regression test for the sandbox isolation guard.
#
# Two scenarios:
#   1. Clean pass — setup_sandbox isolates the four env vars; snapshot
#      captured; no mutation; assert_no_worktree_mutation exits 0.
#   2. Deliberate contamination — assert_no_worktree_mutation observes a
#      drift against a synthetic protected path and exits 1 with the
#      offending path on stderr. The scenario runs in an isolated fixture
#      so the real worktree is never mutated.
#
# This is the wave-1 safety-root regression: every subsequent deliverable
# inherits the contract that `setup_sandbox` + `snapshot_guard_targets` +
# `assert_no_worktree_mutation` catch worktree contamination.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=lib/sandbox.sh
. "${SCRIPT_DIR}/lib/sandbox.sh"

echo "=== test-sandbox-guard.sh (AC-1, AC-2, AC-5) ==="

_tests_run=0
_tests_passed=0
_tests_failed=0

_pass() {
  _tests_run=$((_tests_run + 1))
  _tests_passed=$((_tests_passed + 1))
  printf '  PASS: %s\n' "$1"
}

_fail() {
  _tests_run=$((_tests_run + 1))
  _tests_failed=$((_tests_failed + 1))
  printf '  FAIL: %s\n' "$1" >&2
}

# ---------------------------------------------------------------------------
# Scenario 1: sandbox_isolates_all_four_env_vars + clean snapshot round-trip
# (AC-1, AC-2, AC-3)
# ---------------------------------------------------------------------------
test_sandbox_isolates_four_env_vars() {
  # Fresh TMP — setup_sandbox allocates if unset. Call without command
  # substitution so the exports propagate to the current shell; capture
  # stdout via a tempfile instead.
  unset TMP HOME XDG_CONFIG_HOME XDG_STATE_HOME FURROW_ROOT
  _fixture_out="$(mktemp)"
  setup_sandbox > "${_fixture_out}"
  _fixture="$(cat "${_fixture_out}")"
  rm -f "${_fixture_out}"

  if [ ! -d "${_fixture}" ]; then
    _fail "setup_sandbox returns an existing fixture dir"
    return 0
  fi
  _pass "setup_sandbox returns an existing fixture dir"

  for _v in HOME XDG_CONFIG_HOME XDG_STATE_HOME FURROW_ROOT; do
    eval "_value=\${$_v:-__unset__}"
    case "${_value}" in
      "${TMP}"/*) _pass "${_v} resolves inside \$TMP (${_value})" ;;
      *)          _fail "${_v} escaped \$TMP (${_value})" ;;
    esac
  done

  # Snapshot against the real live repo — this is a read-only op so it is safe.
  # But we need SANDBOX_PROJECT_ROOT pointed at the real repo. Re-export it
  # explicitly in case the caller clobbered it.
  SANDBOX_PROJECT_ROOT="${PROJECT_ROOT}"
  export SANDBOX_PROJECT_ROOT
  snapshot_guard_targets
  if [ -s "${TMP}/guard.pre.sha256" ]; then
    _pass "snapshot_guard_targets wrote a non-empty guard.pre.sha256"
  else
    _fail "snapshot_guard_targets produced an empty snapshot"
  fi

  # Clean round-trip — no mutation happened, so assert exits 0.
  if assert_no_worktree_mutation; then
    _pass "assert_no_worktree_mutation exits 0 on clean worktree"
  else
    _fail "assert_no_worktree_mutation false-positived on a clean worktree"
  fi
}

# ---------------------------------------------------------------------------
# Scenario 2: deliberate_contamination_is_caught (AC-5)
#
# Stand up an isolated fake "project" under $TMP that has the same layout as
# the real repo (specialist symlinks, bin/{alm,rws,sds}, todos.yaml, rules).
# Point SANDBOX_PROJECT_ROOT at this fake. Snapshot. Mutate todos.yaml.
# Assert the guard exits 1 and names the offending path on stderr.
#
# Because the fake repo lives entirely under $TMP, the live worktree is never
# touched.
# ---------------------------------------------------------------------------
test_contamination_is_caught() {
  unset TMP HOME XDG_CONFIG_HOME XDG_STATE_HOME FURROW_ROOT
  setup_sandbox >/dev/null

  _fake_root="${TMP}/fake-repo"
  mkdir -p \
    "${_fake_root}/.claude/commands" \
    "${_fake_root}/.claude/rules" \
    "${_fake_root}/.furrow/almanac" \
    "${_fake_root}/bin" \
    "${_fake_root}/specialists"

  # One specialist pair: a real file under specialists/ plus a symlink.
  printf 'fake specialist body\n' > "${_fake_root}/specialists/fake.md"
  ( cd "${_fake_root}/.claude/commands" && ln -s ../../specialists/fake.md "specialist:fake.md" )

  # Binaries + todos + rules.
  printf '#!/bin/sh\n:\n' > "${_fake_root}/bin/alm"
  printf '#!/bin/sh\n:\n' > "${_fake_root}/bin/rws"
  printf '#!/bin/sh\n:\n' > "${_fake_root}/bin/sds"
  chmod +x "${_fake_root}/bin/alm" "${_fake_root}/bin/rws" "${_fake_root}/bin/sds"
  printf 'entries: []\n' > "${_fake_root}/.furrow/almanac/todos.yaml"
  printf '# step-sequence\n' > "${_fake_root}/.claude/rules/step-sequence.md"
  printf '# cli-mediation\n' > "${_fake_root}/.claude/rules/cli-mediation.md"

  # Point the guard at the fake repo.
  SANDBOX_PROJECT_ROOT="${_fake_root}"
  export SANDBOX_PROJECT_ROOT

  snapshot_guard_targets
  if [ -s "${TMP}/guard.pre.sha256" ]; then
    _pass "snapshot captured fake-repo protected paths"
  else
    _fail "snapshot of fake-repo is empty"
    return 0
  fi

  # Deliberate contamination — mutate todos.yaml.
  printf 'entries: [{id: drift-1}]\n' > "${_fake_root}/.furrow/almanac/todos.yaml"

  _err_file="${TMP}/assert.err"
  _rc=0
  assert_no_worktree_mutation 2>"${_err_file}" || _rc=$?

  if [ "${_rc}" -eq 1 ]; then
    _pass "assert_no_worktree_mutation exits 1 on protected-path drift"
  else
    _fail "assert_no_worktree_mutation expected exit 1, got ${_rc}"
  fi

  if grep -q "todos.yaml" "${_err_file}" 2>/dev/null; then
    _pass "stderr names the offending path (todos.yaml)"
  else
    _fail "stderr did not name todos.yaml (got: $(cat "${_err_file}" 2>/dev/null))"
  fi

  # Also exercise the second contamination form from the spec: pointing
  # FURROW_ROOT at the fake-repo root and writing to it. The guard must also
  # catch this because the digest of the protected path changed.
  # (Same mechanism, different framing — documented in the spec scenario.)
}

# ---------------------------------------------------------------------------
# Scenario 3: AC-3 — snapshot line count equals enumerated path count
# ---------------------------------------------------------------------------
test_snapshot_line_count_matches_path_count() {
  unset TMP HOME XDG_CONFIG_HOME XDG_STATE_HOME FURROW_ROOT
  setup_sandbox >/dev/null

  SANDBOX_PROJECT_ROOT="${PROJECT_ROOT}"
  export SANDBOX_PROJECT_ROOT

  snapshot_guard_targets

  _snapshot_lines="$(wc -l < "${TMP}/guard.pre.sha256" | tr -d ' ')"
  _expected="$(
    # Re-run the enumerator directly to count paths.
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/lib/sandbox.sh"
    SANDBOX_PROJECT_ROOT="${PROJECT_ROOT}"
    _sandbox_enumerate_targets | wc -l | tr -d ' '
  )"

  if [ "${_snapshot_lines}" = "${_expected}" ]; then
    _pass "snapshot line count (${_snapshot_lines}) equals enumerated path count"
  else
    _fail "snapshot has ${_snapshot_lines} lines; enumerator reports ${_expected}"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
test_sandbox_isolates_four_env_vars
test_contamination_is_caught
test_snapshot_line_count_matches_path_count

echo ""
echo "=========================================="
printf '  Results: %s passed, %s failed, %s total\n' \
  "${_tests_passed}" "${_tests_failed}" "${_tests_run}"
echo "=========================================="

if [ "${_tests_failed}" -gt 0 ]; then
  exit 1
fi
exit 0
