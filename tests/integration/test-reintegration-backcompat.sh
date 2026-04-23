#!/bin/sh
# test-reintegration-backcompat.sh — Regression coverage for the
# forward-looking migration script.
#
# Covers:
#   AC-6 (migration script is idempotent and tested)
#   AC-8 (regression test exists, uses setup_sandbox)
#
# Strategy: construct a synthetic pre-migration reintegration.json missing
# test_results.evidence_path, run migrate-reintegration-evidence-path.sh
# twice, assert:
#   - First run fixes the file and it validates against the updated schema.
#   - Second run is a no-op (file bytes unchanged) and exits 0.
#   - An unfixable malformed file exits 1.
#
# POSIX sh. Uses setup_sandbox (test-isolation-guard contract).
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export PROJECT_ROOT

# shellcheck source=tests/integration/helpers.sh
. "${SCRIPT_DIR}/helpers.sh"

MIGRATE_SCRIPT="${PROJECT_ROOT}/bin/frw.d/scripts/migrate-reintegration-evidence-path.sh"
VALIDATOR_LIB="${PROJECT_ROOT}/bin/frw.d/lib/validate-json.sh"
SCHEMA_FILE="${PROJECT_ROOT}/schemas/reintegration.schema.json"

# --- Fixture builder --------------------------------------------------------
# Produce a schema-valid-minus-evidence_path JSON blob (i.e., what an
# in-flight row might have archived before this deliverable merges).
synthesize_pre_migration() {
  _spm_out="$1"
  jq -n '{
    schema_version: "1.0",
    row_name: "fixture-row",
    branch: "work/fixture-row",
    base_sha: "abc1234",
    head_sha: "def5678",
    generated_at: "2026-01-02T00:00:00Z",
    commits: [
      {sha: "abc1234", subject: "feat: x", conventional_type: "feat"}
    ],
    files_changed: [],
    decisions: [],
    open_items: [],
    test_results: { pass: true },
    merge_hints: { expected_conflicts: [], rescue_likely_needed: false }
  }' > "$_spm_out"
}

_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# --- Test 1: first run migrates, result validates --------------------------
test_migrate_first_run() {
  printf '\n[Test 1: first migration run makes file schema-valid]\n'

  unset TMP
  setup_sandbox >/dev/null
  _fixture="${TMP}/fixture"
  mkdir -p "$_fixture"
  # The migration script discovers FURROW_ROOT by walking up to a dir with
  # schemas/<file>; we point it at PROJECT_ROOT explicitly via env to avoid
  # cross-test coupling to file layout under $TMP.
  export FURROW_ROOT="$PROJECT_ROOT"

  _file="${_fixture}/reintegration.json"
  synthesize_pre_migration "$_file"

  # Pre-condition: the file is NOT schema-valid today (required field
  # test_results.evidence_path is missing).
  # shellcheck source=/dev/null
  . "$VALIDATOR_LIB"
  _exit=0
  validate_json "$SCHEMA_FILE" "$_file" >/dev/null 2>&1 || _exit=$?
  assert_exit_code "pre-migration file fails schema validation" 1 "$_exit"

  # Run migration.
  _exit=0
  sh "$MIGRATE_SCRIPT" "$_file" >/dev/null 2>&1 || _exit=$?
  assert_exit_code "migration exits 0" 0 "$_exit"

  # Post-condition: file has evidence_path and validates.
  TESTS_RUN=$((TESTS_RUN + 1))
  _ev="$(jq -r '.test_results.evidence_path // empty' "$_file")"
  if [ -n "$_ev" ]; then
    printf '  PASS: test_results.evidence_path populated (%s)\n' "$_ev"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: test_results.evidence_path still missing\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  _exit=0
  validate_json "$SCHEMA_FILE" "$_file" >/dev/null 2>&1 || _exit=$?
  assert_exit_code "post-migration file validates" 0 "$_exit"
}

# --- Test 2: second run is a no-op (idempotent) ----------------------------
test_migrate_idempotent() {
  printf '\n[Test 2: second migration run is a no-op]\n'

  unset TMP
  setup_sandbox >/dev/null
  _fixture="${TMP}/fixture"
  mkdir -p "$_fixture"
  export FURROW_ROOT="$PROJECT_ROOT"

  _file="${_fixture}/reintegration.json"
  synthesize_pre_migration "$_file"

  # First run.
  sh "$MIGRATE_SCRIPT" "$_file" >/dev/null 2>&1
  _before="$(_sha256 "$_file")"

  # Second run.
  _exit=0
  sh "$MIGRATE_SCRIPT" "$_file" >/dev/null 2>&1 || _exit=$?
  assert_exit_code "second migration exits 0" 0 "$_exit"

  _after="$(_sha256 "$_file")"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_before" = "$_after" ]; then
    printf '  PASS: file bytes unchanged across second migration run\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: second run mutated the file (pre=%s post=%s)\n' \
      "$_before" "$_after" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# --- Test 3: unfixable malformed input exits 1 -----------------------------
test_migrate_unfixable() {
  printf '\n[Test 3: unfixable malformed file exits 1]\n'

  unset TMP
  setup_sandbox >/dev/null
  _fixture="${TMP}/fixture"
  mkdir -p "$_fixture"
  export FURROW_ROOT="$PROJECT_ROOT"

  _file="${_fixture}/reintegration.json"
  # Valid JSON, but violates multiple schema rules that migration cannot
  # fix (e.g., schema_version wrong, commits empty). The migration script
  # must refuse rather than silently write a broken file.
  cat > "$_file" <<'JSON'
{
  "schema_version": "0.9",
  "row_name": "fixture-row",
  "branch": "work/fixture-row",
  "base_sha": "abc1234",
  "head_sha": "def5678",
  "generated_at": "2026-01-02T00:00:00Z",
  "commits": [],
  "files_changed": [],
  "decisions": [],
  "open_items": [],
  "test_results": { "pass": true },
  "merge_hints": {}
}
JSON

  _exit=0
  sh "$MIGRATE_SCRIPT" "$_file" >/dev/null 2>&1 || _exit=$?
  assert_exit_code "migration rejects unfixable input with exit 1" 1 "$_exit"
}

# --- Driver -----------------------------------------------------------------
printf '=== test-reintegration-backcompat.sh ===\n'

for _bin in jq python3; do
  command -v "$_bin" >/dev/null 2>&1 || {
    printf 'SKIP: %s not available\n' "$_bin" >&2
    exit 0
  }
done

test_migrate_first_run
test_migrate_idempotent
test_migrate_unfixable

print_summary
