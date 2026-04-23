#!/bin/sh
# test-migrate-learnings.sh — Regression test for
# bin/frw.d/scripts/migrate-learnings-schema.sh
#
# Verifies:
#   AC3 — migration rewrites a fixture row with old-schema entries; every
#         resulting line validates against schemas/learning.schema.json
#   AC4 — a record missing the `timestamp` field is logged to
#         .furrow/rows/<row>/migration-report.md (not silently dropped)
#         and the script exits non-zero
#   AC8 — schema-valid output, zero fields silently dropped, no old-schema
#         fields leak into the resulting file
#
# Isolation: uses setup_sandbox from tests/integration/lib/sandbox.sh.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=lib/sandbox.sh
. "${SCRIPT_DIR}/lib/sandbox.sh"

echo "=== test-migrate-learnings.sh (AC3, AC4, AC8) ==="

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
# Setup sandbox + fixture row with old-schema entries + one unmappable record
# ---------------------------------------------------------------------------
unset TMP HOME XDG_CONFIG_HOME XDG_STATE_HOME FURROW_ROOT
setup_sandbox >/dev/null
snapshot_guard_targets

WORK_ROOT="${TMP}/work"
ROW_DIR="${WORK_ROOT}/.furrow/rows/fixture-row"
mkdir -p "${ROW_DIR}"
LEARNINGS="${ROW_DIR}/learnings.jsonl"

# 3 old-schema entries + 1 record missing `timestamp` (unmappable).
cat > "${LEARNINGS}" <<'EOF'
{"id":"fixture-row-001","timestamp":"2026-04-02T08:00:00Z","category":"pitfall","content":"Old-schema fixture one with enough length for validator.","context":"Seeded for test; old->new map should rewrite this.","source_task":"fixture-row","source_step":"implement","promoted":false}
{"id":"fixture-row-002","timestamp":"2026-04-02T09:00:00Z","category":"pattern","content":"Second old-schema fixture with long enough summary.","context":"Part of round-trip validation fixture.","source_task":"fixture-row","source_step":"review","promoted":false}
{"id":"fixture-row-003","timestamp":"2026-04-02T10:00:00Z","category":"convention","content":"Third old-schema fixture; convention kind.","context":"Third record, distinct kind for kind-coverage.","source_task":"fixture-row","source_step":"plan","promoted":false}
{"id":"fixture-row-004","category":"pattern","content":"Fourth record — no timestamp field.","context":"Unmappable; must land in migration-report.md.","source_task":"fixture-row","source_step":"implement","promoted":false}
EOF

# ---------------------------------------------------------------------------
# Run the migration
# ---------------------------------------------------------------------------
test_migration_runs() {
  _rc=0
  sh "${PROJECT_ROOT}/bin/frw.d/scripts/migrate-learnings-schema.sh" \
    --root "${WORK_ROOT}" > "${TMP}/migrate.out" 2> "${TMP}/migrate.err" \
    || _rc=$?

  # AC-4: non-zero exit on unmappable record.
  if [ "${_rc}" -ne 0 ]; then
    _pass "migration exits non-zero when an unmappable record is present (exit ${_rc})"
  else
    _fail "expected non-zero exit; got 0 (stderr: $(cat "${TMP}/migrate.err"))"
  fi
}

test_migrated_file_is_schema_valid() {
  # AC-3/AC-8: every resulting line validates against the schema.
  _bad=0
  while IFS= read -r _line || [ -n "${_line}" ]; do
    [ -n "${_line}" ] || continue
    printf '%s' "${_line}" > "${TMP}/_rec.json"
    if ! python3 - "${PROJECT_ROOT}/schemas/learning.schema.json" \
         "${TMP}/_rec.json" <<'PY' 2>"${TMP}/_val.err"
import json, sys
from jsonschema import Draft202012Validator
schema = json.load(open(sys.argv[1]))
inst   = json.load(open(sys.argv[2]))
errs = list(Draft202012Validator(schema).iter_errors(inst))
if errs:
    for e in errs:
        path = '.'.join(str(p) for p in e.absolute_path) or '(root)'
        print(f'Schema error at {path}: {e.message}', file=sys.stderr)
    sys.exit(1)
PY
    then
      _bad=$((_bad + 1))
      printf '  invalid line: %s\n' "${_line}" >&2
      cat "${TMP}/_val.err" >&2 || true
    fi
  done < "${LEARNINGS}"

  if [ "${_bad}" -eq 0 ]; then
    _pass "every surviving line validates against schemas/learning.schema.json"
  else
    _fail "${_bad} record(s) failed schema validation after migration"
  fi

  # AC-3: correct number of records survived (3 of 4; one unmappable).
  _n="$(wc -l < "${LEARNINGS}" | tr -d ' ')"
  if [ "${_n}" = "3" ]; then
    _pass "3 of 4 old-schema records migrated (1 unmappable logged)"
  else
    _fail "expected 3 migrated records; got ${_n}"
  fi
}

test_unmappable_record_in_report() {
  # AC-4: the unmappable record appears in migration-report.md.
  _report="${ROW_DIR}/migration-report.md"
  if [ -f "${_report}" ]; then
    _pass "migration-report.md created for fixture-row"
  else
    _fail "migration-report.md missing"
    return 0
  fi

  if grep -q "fixture-row-004" "${_report}"; then
    _pass "migration-report.md lists the unmappable record (id=fixture-row-004)"
  else
    _fail "migration-report.md does not contain fixture-row-004"
  fi

  if grep -qE "missing.*timestamp" "${_report}"; then
    _pass "migration-report.md names the missing field (timestamp)"
  else
    _fail "migration-report.md does not cite 'timestamp' as the missing field"
  fi
}

test_no_old_schema_leakage() {
  # AC-8: no old-schema key leaks into the migrated file. Using quoted JSON
  # key patterns to avoid matching English words in summary/detail prose.
  if grep -qE '"(category|content|source_task|source_step|promoted|id)"[[:space:]]*:' \
       "${LEARNINGS}"; then
    _fail "old-schema field(s) leaked into migrated file"
  else
    _pass "no old-schema JSON keys remain in migrated file"
  fi
}

test_idempotency() {
  # Re-run migration; file should be unchanged (first record already has .ts).
  _sha_pre="$(sha256sum "${LEARNINGS}" | awk '{print $1}')"
  _rc=0
  sh "${PROJECT_ROOT}/bin/frw.d/scripts/migrate-learnings-schema.sh" \
    --root "${WORK_ROOT}" > /dev/null 2>&1 || _rc=$?
  _sha_post="$(sha256sum "${LEARNINGS}" | awk '{print $1}')"
  if [ "${_sha_pre}" = "${_sha_post}" ]; then
    _pass "migration is idempotent on an already-migrated file"
  else
    _fail "migration mutated an already-migrated file (sha drift)"
  fi
  # With the unmappable already moved out of the jsonl, rerun should be clean
  # exit 0 (no old-schema records remain in the file). This also documents the
  # idempotency contract.
  if [ "${_rc}" -eq 0 ]; then
    _pass "second migration pass exits 0 (no-op on new-schema file)"
  else
    _fail "second migration pass exited ${_rc}; expected 0"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
test_migration_runs
test_migrated_file_is_schema_valid
test_unmappable_record_in_report
test_no_old_schema_leakage
test_idempotency

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
