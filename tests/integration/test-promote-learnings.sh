#!/bin/sh
# test-promote-learnings.sh — Regression test for commands/lib/promote-learnings.sh
#
# Verifies:
#   AC5  — promote-learnings.sh reads the new schema only
#   AC7  — 3 known new-schema learnings are each printed with populated
#          summary/kind/step/tags
#   AC6  — append-learning.sh hook refuses a malformed learning and accepts
#          a well-formed one
#   AC9  — the refusal stderr mentions the offending field in a schema-error
#          path (`kind` is required)
#
# Isolation: uses setup_sandbox from tests/integration/lib/sandbox.sh so the
# live worktree is never touched.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=lib/sandbox.sh
. "${SCRIPT_DIR}/lib/sandbox.sh"

echo "=== test-promote-learnings.sh (AC5, AC6, AC7, AC9) ==="

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
# Setup sandbox + fixture
# ---------------------------------------------------------------------------
unset TMP HOME XDG_CONFIG_HOME XDG_STATE_HOME FURROW_ROOT
setup_sandbox >/dev/null
snapshot_guard_targets

# Point FURROW_ROOT at the real project so the script can find jq-backed libs.
# But keep the fixture *rows* inside the sandbox.
export FURROW_ROOT="${PROJECT_ROOT}"

WORK_ROOT="${TMP}/work"
mkdir -p "${WORK_ROOT}/.furrow/rows/fixture-row"
LEARNINGS="${WORK_ROOT}/.furrow/rows/fixture-row/learnings.jsonl"

# Three known new-schema records. Each has a distinct kind and step so we can
# grep exact values below.
cat > "${LEARNINGS}" <<'EOF'
{"ts":"2026-04-23T10:00:00Z","step":"ideate","kind":"pattern","summary":"Surface lib/ patterns early in ideate","detail":"Caught during ideate scaffolding.","tags":["scaffold","lib"]}
{"ts":"2026-04-23T11:00:00Z","step":"plan","kind":"convention","summary":"Use kebab-case for row identifiers","detail":"Enforced by definition schema.","tags":["naming"]}
{"ts":"2026-04-23T12:00:00Z","step":"implement","kind":"pitfall","summary":"Remember to quote module references","detail":"Discovered during module wiring.","tags":["shell","quoting"]}
EOF

# ---------------------------------------------------------------------------
# AC5 + AC7 — promote-learnings.sh reads new schema and prints populated
# summary/kind/step/tags for every iterated learning.
# ---------------------------------------------------------------------------
test_promote_reads_new_schema() {
  cd "${WORK_ROOT}"
  _out_file="${TMP}/promote.out"
  # The command-lib script expects `name` as $1 relative to cwd .furrow/rows/<name>.
  if sh "${PROJECT_ROOT}/commands/lib/promote-learnings.sh" fixture-row \
       > "${_out_file}" 2> "${TMP}/promote.err"; then
    _pass "promote-learnings.sh exits 0 on new-schema fixture"
  else
    _fail "promote-learnings.sh exited non-zero (stderr: $(cat "${TMP}/promote.err"))"
    return 0
  fi

  _out="$(cat "${_out_file}")"

  # 3 kind= lines, 3 summary= lines, 3 step= lines, 3 tags= lines.
  _kc="$(printf '%s\n' "${_out}" | grep -c '^[[:space:]]*kind=' || true)"
  _sc="$(printf '%s\n' "${_out}" | grep -c '^[[:space:]]*summary=' || true)"
  _tc="$(printf '%s\n' "${_out}" | grep -c '^[[:space:]]*tags=' || true)"
  _ec="$(printf '%s\n' "${_out}" | grep -c '^[[:space:]]*step=' || true)"

  for _pair in "kind=${_kc}" "summary=${_sc}" "tags=${_tc}" "step=${_ec}"; do
    _name="${_pair%%=*}"; _val="${_pair#*=}"
    if [ "${_val}" = "3" ]; then
      _pass "output has 3 ${_name}= lines"
    else
      _fail "output has ${_val} ${_name}= lines (expected 3)"
    fi
  done

  # No empty summary / kind / step values (strict regression).
  if printf '%s\n' "${_out}" | grep -qE '^[[:space:]]*summary=[[:space:]]*$'; then
    _fail "output contains an empty summary= line"
  else
    _pass "no empty summary= line"
  fi
  if printf '%s\n' "${_out}" | grep -qE '^[[:space:]]*kind=[[:space:]]*$'; then
    _fail "output contains an empty kind= line"
  else
    _pass "no empty kind= line"
  fi

  # The three specific kinds must each appear exactly once.
  for _k in pattern convention pitfall; do
    _n="$(printf '%s\n' "${_out}" | grep -c "kind=${_k}$" || true)"
    if [ "${_n}" = "1" ]; then
      _pass "kind=${_k} printed once"
    else
      _fail "kind=${_k} printed ${_n} times (expected 1)"
    fi
  done

  # Guard: old-schema field names must not leak into output.
  if printf '%s\n' "${_out}" | grep -qE '(Category:|source_step|promoted|content=)'; then
    _fail "old-schema field names leaked into output"
  else
    _pass "output contains no old-schema field names"
  fi
}

# ---------------------------------------------------------------------------
# AC6 + AC9 — append-learning hook
# ---------------------------------------------------------------------------
test_append_hook_refuses_invalid() {
  cd "${WORK_ROOT}"
  bad='{"ts":"2026-04-23T00:00:00Z","step":"ideate","summary":"short-bad","detail":"missing-kind","tags":[]}'
  _rc=0
  echo "${bad}" | sh "${PROJECT_ROOT}/bin/frw.d/hooks/append-learning.sh" \
    demo-row 2> "${TMP}/append.err" > /dev/null || _rc=$?
  if [ "${_rc}" -ne 0 ]; then
    _pass "append-learning refuses record missing 'kind' (exit ${_rc})"
  else
    _fail "append-learning accepted a malformed record"
  fi
  if grep -q "kind" "${TMP}/append.err"; then
    _pass "append-learning stderr mentions 'kind'"
  else
    _fail "append-learning stderr did not mention 'kind' (got: $(cat "${TMP}/append.err"))"
  fi
}

test_append_hook_accepts_valid() {
  cd "${WORK_ROOT}"
  good='{"ts":"2026-04-23T00:00:00Z","step":"ideate","kind":"pattern","summary":"valid summary one","detail":"surfaced in test","tags":["test"]}'
  _rc=0
  echo "${good}" | sh "${PROJECT_ROOT}/bin/frw.d/hooks/append-learning.sh" \
    demo-row 2> "${TMP}/append2.err" || _rc=$?
  if [ "${_rc}" -eq 0 ]; then
    _pass "append-learning accepts a valid record"
  else
    _fail "append-learning rejected a valid record (stderr: $(cat "${TMP}/append2.err"))"
    return 0
  fi
  if tail -n1 "${WORK_ROOT}/.furrow/rows/demo-row/learnings.jsonl" 2>/dev/null \
       | grep -q '"valid summary one"'; then
    _pass "valid record appended to demo-row/learnings.jsonl"
  else
    _fail "valid record not written to demo-row/learnings.jsonl"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
test_promote_reads_new_schema
test_append_hook_refuses_invalid
test_append_hook_accepts_valid

# Worktree guard — ensure we did not mutate the live repo.
if assert_no_worktree_mutation; then
  _pass "assert_no_worktree_mutation — no live-worktree drift"
else
  _fail "live worktree was mutated by this test"
fi

echo ""
echo "=========================================="
printf '  Results: %s passed, %s failed, %s total\n' \
  "${_tests_passed}" "${_tests_failed}" "${_tests_run}"
echo "=========================================="

if [ "${_tests_failed}" -gt 0 ]; then
  exit 1
fi
exit 0
