#!/bin/sh
# test-script-modes.sh — Regression test for script-modes-fix.
#
# Asserts:
#   AC-1 / AC-5: every tracked bin/frw.d/scripts/*.sh is committed at mode
#                100755. Any file at 100644 fails the test and prints the
#                offending path.
#   AC-3:        bin/frw.d/hooks/pre-commit-script-modes.sh exists, has
#                shebang `#!/bin/sh`, is committed at mode 100755, and
#                (smoke check) rejects a synthetic 100644 stage of a
#                bin/frw.d/scripts/*.sh file with the expected error message.
#   AC-7:        bin/frw's exec path for the `rescue` subcommand has the same
#                shape as every other `exec "$FURROW_ROOT/bin/frw.d/scripts/...`
#                exec-style dispatch entry. No rescue-specific branch.
#
# Runs inside setup_sandbox (from the wave-1 test-isolation-guard deliverable)
# even though all checks are read-only: this enforces the project-wide test
# contract that no test escapes $TMP under any failure mode.
#
# Usage: sh tests/integration/test-script-modes.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=lib/sandbox.sh
. "${SCRIPT_DIR}/lib/sandbox.sh"

echo "=== test-script-modes.sh (script-modes-fix AC-1, AC-3, AC-5, AC-7) ==="

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

# Fresh sandbox. No worktree mutation — every check runs `git ls-files` or
# reads files read-only from PROJECT_ROOT.
unset TMP HOME XDG_CONFIG_HOME XDG_STATE_HOME FURROW_ROOT
setup_sandbox >/dev/null

# --- AC-1 / AC-5: every bin/frw.d/scripts/*.sh is 100755 --------------------
test_all_scripts_are_executable() {
  _offenders="$(
    cd "${PROJECT_ROOT}" && \
    git ls-files -s bin/frw.d/scripts/ | \
    awk '$4 ~ /\.sh$/ && $1 != "100755" { print $4 }'
  )"

  if [ -z "${_offenders}" ]; then
    _pass "every bin/frw.d/scripts/*.sh is committed at mode 100755"
  else
    _fail "the following bin/frw.d/scripts/*.sh files are not 100755:"
    printf '%s\n' "${_offenders}" | sed 's/^/    /' >&2
  fi
}

# --- AC-3: pre-commit-script-modes.sh exists, shebang, mode, rejects 100644 -
test_hook_exists_and_well_formed() {
  _hook="${PROJECT_ROOT}/bin/frw.d/hooks/pre-commit-script-modes.sh"

  if [ -f "${_hook}" ]; then
    _pass "hook file exists at bin/frw.d/hooks/pre-commit-script-modes.sh"
  else
    _fail "hook file missing at bin/frw.d/hooks/pre-commit-script-modes.sh"
    return 0
  fi

  _first_line="$(head -n1 "${_hook}")"
  if [ "${_first_line}" = "#!/bin/sh" ]; then
    _pass "hook shebang is #!/bin/sh"
  else
    _fail "hook shebang is not #!/bin/sh (got: ${_first_line})"
  fi

  _hook_mode="$(
    cd "${PROJECT_ROOT}" && \
    git ls-files -s -- bin/frw.d/hooks/pre-commit-script-modes.sh | awk '{print $1}'
  )"
  if [ "${_hook_mode}" = "100755" ]; then
    _pass "hook is committed at mode 100755"
  else
    _fail "hook is not at 100755 (got: ${_hook_mode})"
  fi

  # sh -n parse check
  if sh -n "${_hook}" 2>/dev/null; then
    _pass "hook passes sh -n parse check"
  else
    _fail "hook fails sh -n"
  fi
}

# --- AC-3 smoke: hook rejects a synthetic 100644 stage ---------------------
# Build an isolated throwaway git repo entirely under $TMP that mimics the
# bin/frw.d/scripts/ layout; stage a fake script at mode 100644 via
# update-index --add --cacheinfo; run the hook from that repo's root; assert
# non-zero exit and that stderr names the offending path.
test_hook_rejects_100644_stage() {
  _fake_repo="${TMP}/fake-repo"
  mkdir -p "${_fake_repo}/bin/frw.d/scripts"
  (
    cd "${_fake_repo}" && \
    git init -q && \
    git config user.email "test@test.com" && \
    git config user.name "Test"
  )

  # Create a blob and stage it at 100644 under bin/frw.d/scripts/fake.sh.
  _blob_file="${_fake_repo}/_blob_src.sh"
  printf '#!/bin/sh\necho fake\n' > "${_blob_file}"
  _sha="$(cd "${_fake_repo}" && git hash-object -w "${_blob_file}")"
  (
    cd "${_fake_repo}" && \
    git update-index --add --cacheinfo "100644,${_sha},bin/frw.d/scripts/fake.sh"
  )

  # Invoke the hook from the fake repo root. Copy the hook in so its
  # fallback-log path finds a plausible common-minimal.sh (or uses the
  # inline fallback).
  _err_file="${TMP}/hook.err"
  _rc=0
  (
    cd "${_fake_repo}" && \
    sh "${PROJECT_ROOT}/bin/frw.d/hooks/pre-commit-script-modes.sh"
  ) 2> "${_err_file}" || _rc=$?

  if [ "${_rc}" -ne 0 ]; then
    _pass "hook exits non-zero when a bin/frw.d/scripts/*.sh is staged at 100644 (exit=${_rc})"
  else
    _fail "hook exited 0 when it should have rejected the 100644 stage"
  fi

  if grep -q "must be 100755" "${_err_file}" 2>/dev/null; then
    _pass "hook stderr contains 'must be 100755'"
  else
    _fail "hook stderr missing expected message (got: $(cat "${_err_file}" 2>/dev/null))"
  fi

  if grep -q "bin/frw.d/scripts/fake.sh" "${_err_file}" 2>/dev/null; then
    _pass "hook stderr names the offending path"
  else
    _fail "hook stderr did not name bin/frw.d/scripts/fake.sh"
  fi
}

# --- AC-7: no dispatcher special-case for rescue ---------------------------
# Every `exec "$FURROW_ROOT/bin/frw.d/scripts/<name>.sh" "$@"` entry in bin/frw
# shares the same textual shape. Extract them, strip the script name, and
# confirm every line (including rescue) has the identical surrounding shape.
test_no_dispatcher_special_case() {
  _frw="${PROJECT_ROOT}/bin/frw"

  # Extract the shape of each exec-style dispatch to bin/frw.d/scripts. Replace
  # the script base name with <NAME> so all entries normalize to the same
  # string if they share shape.
  _shapes="$(
    grep -nE '^[[:space:]]*exec "\$FURROW_ROOT/bin/frw\.d/scripts/' "${_frw}" \
      | sed -E 's|/scripts/[a-zA-Z0-9_.-]+\.sh|/scripts/<NAME>.sh|'
  )"

  if [ -z "${_shapes}" ]; then
    _fail "no exec-style dispatch lines found in bin/frw (unexpected)"
    return 0
  fi

  # Normalize away the leading "LINE:" from grep -n output, then count unique
  # shapes. Exactly 1 unique shape means every exec entry is identical.
  _unique_shapes="$(
    printf '%s\n' "${_shapes}" | sed -E 's/^[0-9]+://' | sort -u
  )"
  _unique_count="$(printf '%s\n' "${_unique_shapes}" | wc -l | tr -d ' ')"

  if [ "${_unique_count}" = "1" ]; then
    _pass "all exec-style dispatches in bin/frw share the same shape (count=${_unique_count})"
  else
    _fail "bin/frw has ${_unique_count} distinct exec-dispatch shapes (expected 1):"
    printf '%s\n' "${_unique_shapes}" | sed 's/^/    /' >&2
  fi

  # Explicitly confirm the rescue line is present with the normalized shape.
  if printf '%s\n' "${_shapes}" | grep -q 'scripts/<NAME>.sh" "$@"'; then
    _pass "rescue dispatch line matches the generic exec shape"
  else
    _fail "rescue dispatch does not match the generic exec shape"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
test_all_scripts_are_executable
test_hook_exists_and_well_formed
test_hook_rejects_100644_stage
test_no_dispatcher_special_case

echo ""
echo "=========================================="
printf '  Results: %s passed, %s failed, %s total\n' \
  "${_tests_passed}" "${_tests_failed}" "${_tests_run}"
echo "=========================================="

if [ "${_tests_failed}" -gt 0 ]; then
  exit 1
fi
exit 0
