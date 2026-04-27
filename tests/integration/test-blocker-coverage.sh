#!/bin/bash
# test-blocker-coverage.sh — D4 coverage assertion (per specs/shared-contracts.md §C7).
#
# For every code in schemas/blocker-taxonomy.yaml, asserts that
# tests/integration/fixtures/blocker-events/<code>/ exists with at least
# the four canonical fixture files {normalized.json, claude.json, pi.json,
# expected-envelope.json}. For codes whose fixture set is reachable
# through `furrow guard <event-type>` (i.e., a guard handler exists), the
# test additionally:
#
#   1. Pipes normalized.json into `go run ./cmd/furrow guard <event-type>`
#      after substituting any __FIXTURE_DIR__ placeholders with the
#      absolute path of the fixture directory (so fixtures that need
#      filesystem state can ship that state alongside).
#   2. Asserts the resulting JSON array contains an envelope matching
#      expected-envelope.json (jq -S byte-equal compare on .code,
#      .severity, .category, .confirmation_path, .message,
#      .remediation_hint).
#
# For codes with no guard event-type (Go-side codes emitted from
# row_workflow.go / definition validators / etc., not reachable via
# `furrow guard`), the fixture directory contains a SKIP_REASON file and
# the test logs a SKIP line — these codes are not yet wired through the
# guard CLI and per-code coverage is enforced via the existing Go tests
# (internal/cli/*_test.go), not this integration test.
#
# Failure modes (per spec AC-1, AC-2, AC-9):
#   - missing fixture dir            → FAIL: fixture missing for code <code>
#   - missing fixture file           → FAIL: <code> <file> (file not found...)
#   - guard envelope shape mismatch  → FAIL: <code> .<field> mismatch
#
# Auto-discovered by tests/integration/run-all.sh's test-*.sh glob.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-blocker-coverage.sh ==="

# --- Structural prerequisites -------------------------------------------
for _bin in jq yq go; do
  if ! command -v "$_bin" >/dev/null 2>&1; then
    printf '  FAIL: required command not on PATH: %s\n' "$_bin" >&2
    exit 1
  fi
done

TAXONOMY="${PROJECT_ROOT}/schemas/blocker-taxonomy.yaml"
EVENT_CATALOG="${PROJECT_ROOT}/schemas/blocker-event.yaml"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/blocker-events"

if [ ! -f "$TAXONOMY" ]; then
  printf '  FAIL: taxonomy file not readable: %s\n' "$TAXONOMY" >&2
  exit 1
fi
if [ ! -f "$EVENT_CATALOG" ]; then
  printf '  FAIL: event catalog not readable: %s\n' "$EVENT_CATALOG" >&2
  exit 1
fi
if [ ! -d "$FIXTURE_ROOT" ]; then
  printf '  FAIL: fixture root missing: %s\n' "$FIXTURE_ROOT" >&2
  exit 1
fi

# --- Skip lists ---------------------------------------------------------
# DEFERRED_CODES: codes deferred from migration per
# .furrow/rows/blocker-taxonomy-foundation/research/hook-audit-final.md §4.
# D3 deferred zero codes (all 10 hooks fully migrated). Empty list keeps
# the operational hook for future deferrals without a code change.
DEFERRED_CODES=""

# --- Build the guard-reachable code map (event-type per code) -----------
# Read schemas/blocker-event.yaml's emitted_codes[] across all 10 event
# types and produce a "code\tevent_type" mapping. For codes emitted by
# multiple event types (currently none), the first wins — sufficient for
# coverage assertion since both paths feed the same handler.
build_event_map() {
  yq -r '
    .event_types[] as $et
    | $et.emitted_codes[] | [., $et.name] | @tsv
  ' "$EVENT_CATALOG"
}

EVENT_MAP="$(build_event_map)"

event_type_for_code() {
  printf '%s\n' "$EVENT_MAP" | awk -F'\t' -v c="$1" '$1==c {print $2; exit}'
}

# --- Per-code assertion -------------------------------------------------
# Capture dir for normalized-event renders + guard outputs (per spec).
CAPTURE_DIR="$(mktemp -d)"
trap 'rm -rf "${CAPTURE_DIR:-}"' EXIT INT TERM

assert_envelope_field() {
  _code="$1"; _captured="$2"; _expected="$3"; _field="$4"; _fix_dir="$5"
  TESTS_RUN=$((TESTS_RUN + 1))
  # Expected value: read from expected-envelope.json with __FIXTURE_DIR__
  # substituted to the absolute fixture directory (matches the same
  # substitution applied to normalized.json before piping to guard).
  _exp_raw="$(jq -r ".${_field}" "$_expected" 2>/dev/null || printf '__JQ_ERROR__')"
  _exp="$(printf '%s' "$_exp_raw" | sed "s|__FIXTURE_DIR__|${_fix_dir}|g")"
  # The guard CLI emits an array of zero or more envelopes. For codes
  # that emit multiple envelopes per invocation (e.g. summary_section_*
  # walks every required section), pick the FIRST envelope whose .code
  # matches and assert against it. The single-envelope cases pick the
  # only entry; multi-envelope cases pick the first ordered match,
  # which the expected fixture is authored against.
  _got="$(jq -r --arg c "$_code" \
            'first(.[] | select(.code == $c)) | .'"${_field}" \
            "$_captured" 2>/dev/null || printf '__JQ_ERROR__')"
  if [ "$_exp" = "$_got" ]; then
    printf "  PASS: %s envelope .%s matches expected\n" "$_code" "$_field"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    printf "  FAIL: %s envelope .%s mismatch (expected '%s', got '%s')\n" \
      "$_code" "$_field" "$_exp" "$_got" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

run_one_code() {
  _code="$1"
  _dir="${FIXTURE_ROOT}/${_code}"

  # AC-2 / AC-9: missing fixture dir surfaces the code name.
  if [ ! -d "$_dir" ]; then
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "  FAIL: fixture missing for code %s (dir not found: %s)\n" \
      "$_code" "$_dir" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Required four files.
  assert_file_exists "${_code} normalized.json"        "${_dir}/normalized.json"
  assert_file_exists "${_code} claude.json"            "${_dir}/claude.json"
  assert_file_exists "${_code} pi.json"                "${_dir}/pi.json"
  assert_file_exists "${_code} expected-envelope.json" "${_dir}/expected-envelope.json"

  # Skip rule 1: deferred codes (none in W4).
  case " $DEFERRED_CODES " in
    *" ${_code} "*)
      printf "  SKIP: %s (reason: deferred per audit)\n" "$_code"
      return 0
      ;;
  esac

  # Skip rule 2: guard handler not wired (Go-side codes only).
  if [ -f "${_dir}/SKIP_REASON" ]; then
    _reason="$(head -n1 "${_dir}/SKIP_REASON")"
    printf "  SKIP: %s (%s)\n" "$_code" "$_reason"
    return 0
  fi

  _event_type="$(event_type_for_code "$_code")"
  if [ -z "$_event_type" ]; then
    # Defensive: SKIP_REASON should have been set, but treat
    # missing-event-type as a skip with logged reason rather than a hard
    # failure so the inventory test (parity.sh) can carry the assertion.
    printf "  SKIP: %s (no guard event-type — Go-only emit-site)\n" "$_code"
    return 0
  fi

  # Render normalized.json with __FIXTURE_DIR__ resolved.
  _rendered="${CAPTURE_DIR}/${_code}.normalized.json"
  sed "s|__FIXTURE_DIR__|${_dir}|g" "${_dir}/normalized.json" > "$_rendered"

  # Run guard. Use FURROW_BIN if exported (test-suite speedup); else go run.
  _captured="${CAPTURE_DIR}/${_code}.envelope.json"
  _stderr="${CAPTURE_DIR}/${_code}.stderr"
  _ec=0
  if [ -n "${FURROW_BIN:-}" ]; then
    # shellcheck disable=SC2086
    "$FURROW_BIN" guard "$_event_type" < "$_rendered" \
      > "$_captured" 2> "$_stderr" || _ec=$?
  else
    ( cd "$PROJECT_ROOT" && go run ./cmd/furrow guard "$_event_type" \
        < "$_rendered" > "$_captured" 2> "$_stderr" ) || _ec=$?
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_ec" -ne 0 ]; then
    printf "  FAIL: %s guard exited %s (stderr: %s)\n" \
      "$_code" "$_ec" "$(tr '\n' ' ' < "$_stderr")" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Array must be non-empty and contain at least one envelope with .code == $_code.
  _len="$(jq -r 'length' "$_captured" 2>/dev/null || printf '0')"
  if [ "$_len" = "0" ]; then
    printf "  FAIL: %s guard returned empty array — no envelope emitted\n" \
      "$_code" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
  _has="$(jq -r --arg c "$_code" 'any(.[]; .code == $c)' "$_captured" 2>/dev/null || printf 'false')"
  if [ "$_has" != "true" ]; then
    _got_codes="$(jq -r '[.[].code] | join(",")' "$_captured" 2>/dev/null || printf '?')"
    printf "  FAIL: %s expected code in envelope array; got [%s]\n" \
      "$_code" "$_got_codes" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
  printf "  PASS: %s guard emitted envelope with matching code\n" "$_code"
  TESTS_PASSED=$((TESTS_PASSED + 1))

  # Field-by-field assertion against expected-envelope.json (per spec AC-1).
  # Pass the fixture dir so __FIXTURE_DIR__ in expected.message resolves.
  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "code"              "$_dir"
  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "category"          "$_dir"
  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "severity"          "$_dir"
  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "confirmation_path" "$_dir"
  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "message"           "$_dir"
  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "remediation_hint"  "$_dir"
}

# --- Walk every code ----------------------------------------------------
CODES="$(yq -r '.blockers[].code' "$TAXONOMY")"
TOTAL_CODES="$(printf '%s\n' "$CODES" | grep -c .)"
printf "  --- walking %s codes from %s ---\n" "$TOTAL_CODES" "$(basename "$TAXONOMY")"

# Stable iteration; bash IFS over newline.
while IFS= read -r _c; do
  [ -n "$_c" ] || continue
  run_one_code "$_c" || true   # accrue failures into TESTS_FAILED; never abort
done <<EOF
$CODES
EOF

print_summary
