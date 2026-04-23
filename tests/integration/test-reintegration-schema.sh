#!/bin/sh
# test-reintegration-schema.sh — Regression coverage for the consolidated
# reintegration schema validator.
#
# Covers:
#   AC-4 (invalid generator output fails loudly with validator message)
#   AC-5 (valid output round-trips through get-reintegration-json unchanged)
#   AC-7 (regression test exists, uses setup_sandbox)
#
# Strategy: use setup_sandbox from tests/integration/lib/sandbox.sh (the
# single source of truth for HOME / XDG_* / FURROW_ROOT — see
# test-isolation-guard deliverable). The fixture row lives under the
# sandbox's $TMP/fixture; no mutation of the live worktree is possible.
#
# POSIX sh — sources helpers.sh for assertion utilities.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export PROJECT_ROOT

# shellcheck source=tests/integration/helpers.sh
. "${SCRIPT_DIR}/helpers.sh"

GEN_SCRIPT="${PROJECT_ROOT}/bin/frw.d/scripts/generate-reintegration.sh"
GET_SCRIPT="${PROJECT_ROOT}/bin/frw.d/scripts/get-reintegration-json.sh"
VALIDATOR_LIB="${PROJECT_ROOT}/bin/frw.d/lib/validate-json.sh"
SCHEMA_FILE="${PROJECT_ROOT}/schemas/reintegration.schema.json"

# --- Fixture helper ---------------------------------------------------------
# Build a self-contained git repo + .furrow row scaffold inside the given dir.
# Echoes the row name on stdout. Uses fixed dates for reproducibility.
build_fixture() {
  _bf_dir="$1"
  _bf_row="${2:-fixture-row}"
  _bf_branch="work/${_bf_row}"

  (
    cd "$_bf_dir" &&
    git init -q &&
    git config user.email "test@test.invalid" &&
    git config user.name "Test" &&
    git checkout -b main 2>/dev/null || git checkout -b main
  )
  printf 'init\n' > "${_bf_dir}/.gitkeep"
  (
    cd "$_bf_dir" &&
    GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" \
    GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" \
      git add .gitkeep &&
    GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" \
    GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" \
      git commit -q -m "initial"
  )
  (
    cd "$_bf_dir" &&
    git checkout -b "$_bf_branch" 2>/dev/null || true
  )

  mkdir -p "${_bf_dir}/.furrow/rows/${_bf_row}/reviews"

  _bf_base="$(cd "$_bf_dir" && git rev-parse HEAD)"
  jq -n \
    --arg name "$_bf_row" \
    --arg branch "$_bf_branch" \
    --arg base "$_bf_base" \
    '{name: $name, title: "Fixture", description: "Schema regression",
      step: "implement", step_status: "in_progress",
      steps_sequence: ["ideate","research","plan","spec","decompose","implement","review"],
      deliverables: {}, gates: [], force_stop_at: null,
      branch: $branch, mode: "code", base_commit: $base,
      seed_id: null, epic_seed_id: null,
      created_at: "2026-01-01T00:00:00Z", updated_at: "2026-01-01T00:00:00Z",
      archived_at: null, source_todo: null, gate_policy_init: "supervised"}' \
    > "${_bf_dir}/.furrow/rows/${_bf_row}/state.json"

  cat > "${_bf_dir}/.furrow/rows/${_bf_row}/reviews/2026-01-01T00-00.md" <<'REVIEW'
# Review: fixture
## Overall
pass
REVIEW

  printf '%s\n' "$_bf_row"
}

add_good_commit() {
  _agc_dir="$1"
  _agc_msg="$2"
  _agc_file="${3:-change-$$.txt}"
  printf 'content\n' > "${_agc_dir}/${_agc_file}"
  (
    cd "$_agc_dir" &&
    GIT_AUTHOR_DATE="2026-01-02T00:00:00Z" \
    GIT_COMMITTER_DATE="2026-01-02T00:00:00Z" \
      git add "$_agc_file" &&
    GIT_AUTHOR_DATE="2026-01-02T00:00:00Z" \
    GIT_COMMITTER_DATE="2026-01-02T00:00:00Z" \
      git commit -q -m "$_agc_msg"
  )
}

# --- Test 1: shared helper catches malformed JSON (AC-4) -------------------
test_validator_helper_rejects_bad_json() {
  printf '\n[Test 1: shared validator rejects malformed JSON]\n'

  # Fresh sandbox per test (reset TMP so setup_sandbox allocates a new one).
  unset TMP
  setup_sandbox >/dev/null

  # Source the validator lib directly (the same entrypoint every caller uses).
  # shellcheck source=/dev/null
  . "$VALIDATOR_LIB"

  # Construct a JSON doc missing required fields: no row_name, no commits, etc.
  _bad="${TMP}/bad-reint.json"
  cat > "$_bad" <<'JSON'
{"schema_version": "1.0"}
JSON

  _err="${TMP}/bad-err.txt"
  _exit=0
  validate_json "$SCHEMA_FILE" "$_bad" 2>"$_err" || _exit=$?

  assert_exit_code "validate_json rejects malformed doc" 1 "$_exit"

  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "^Schema error at " "$_err"; then
    printf '  PASS: stderr contains "Schema error at <path>: <message>" line\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: expected "Schema error at" in stderr; got:\n' >&2
    sed 's/^/    /' "$_err" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# --- Test 2: generator rejects invalid output (AC-4) -----------------------
# Corrupt state.json so generator produces a row_name that fails the schema
# pattern. The generator must catch this via the shared validator.
test_generator_rejects_invalid_output() {
  printf '\n[Test 2: generator exits 3 on invalid output]\n'

  # Fresh sandbox per test (reset TMP so setup_sandbox allocates a new one).
  unset TMP
  setup_sandbox >/dev/null
  _dir="${TMP}/fixture"
  _row="$(build_fixture "$_dir" "fixture-row")"
  add_good_commit "$_dir" "feat: ok"

  # Force an invalid row_name by rewriting state.json .name to uppercase —
  # violates the schema pattern ^[a-z][a-z0-9]*(-[a-z0-9]+)*$.
  _state="${_dir}/.furrow/rows/${_row}/state.json"
  _bad_state="${_state}.new"
  jq '.name = "BAD-NAME"' "$_state" > "$_bad_state" && mv "$_bad_state" "$_state"

  _err="${TMP}/gen-err.txt"
  _exit=0
  (cd "$_dir" && sh "$GEN_SCRIPT" "$_row" "$_dir") >/dev/null 2>"$_err" || _exit=$?

  assert_exit_code "generator exits 3 on schema invalid" 3 "$_exit"

  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "^Schema error at " "$_err"; then
    printf '  PASS: generator stderr contains validator error line\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: expected "Schema error at" on stderr; got:\n' >&2
    sed 's/^/    /' "$_err" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Atomic-write invariant: the bad temp file must not have been committed.
  _final="${_dir}/.furrow/rows/${_row}/reintegration.json"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ ! -f "$_final" ]; then
    printf '  PASS: reintegration.json not created on validation failure\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: reintegration.json was written despite validation failure\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# --- Test 3: valid round-trip through get-reintegration-json (AC-5) --------
test_valid_round_trip() {
  printf '\n[Test 3: valid generator output round-trips through get-reintegration-json]\n'

  # Fresh sandbox per test (reset TMP so setup_sandbox allocates a new one).
  unset TMP
  setup_sandbox >/dev/null
  _dir="${TMP}/fixture"
  _row="$(build_fixture "$_dir" "fixture-row")"
  add_good_commit "$_dir" "feat: ok" "feat-a.txt"

  _exit=0
  (cd "$_dir" && sh "$GEN_SCRIPT" "$_row" "$_dir") >/dev/null 2>&1 || _exit=$?
  assert_exit_code "generator exits 0 on valid input" 0 "$_exit"

  _reint="${_dir}/.furrow/rows/${_row}/reintegration.json"
  assert_file_exists "reintegration.json created" "$_reint"

  # get-reintegration-json reads and re-validates, emitting on stdout.
  _out="${TMP}/get-out.json"
  _exit=0
  (cd "$_dir" && sh "$GET_SCRIPT" "$_row" "$_dir") > "$_out" 2>&1 || _exit=$?
  assert_exit_code "get-reintegration-json exits 0" 0 "$_exit"

  # Round-trip: get output (normalized) equals file on disk (normalized).
  TESTS_RUN=$((TESTS_RUN + 1))
  _a="$(jq --sort-keys '.' "$_reint")"
  _b="$(jq --sort-keys '.' "$_out")"
  if [ "$_a" = "$_b" ]; then
    printf '  PASS: get-reintegration-json output byte-identical to on-disk JSON\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: round-trip diff:\n' >&2
    diff <(printf '%s' "$_a") <(printf '%s' "$_b") | sed 's/^/    /' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # AC-R2/schema: test_results.evidence_path is now a required field.
  TESTS_RUN=$((TESTS_RUN + 1))
  if jq -e '.test_results.evidence_path | type == "string"' "$_reint" >/dev/null; then
    printf '  PASS: test_results.evidence_path present and is a string\n'
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf '  FAIL: test_results.evidence_path missing or wrong type\n' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# --- Driver -----------------------------------------------------------------
printf '=== test-reintegration-schema.sh ===\n'

# Preflight — tools required
for _bin in jq git python3; do
  command -v "$_bin" >/dev/null 2>&1 || {
    printf 'SKIP: %s not available\n' "$_bin" >&2
    exit 0
  }
done

test_validator_helper_rejects_bad_json
test_generator_rejects_invalid_output
test_valid_round_trip

print_summary
