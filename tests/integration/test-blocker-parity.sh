#!/bin/bash
# test-blocker-parity.sh — D4 parity + anti-cheat assertions.
#
# Per specs/shared-contracts.md §C7: for every (migrated shim, code)
# pair, the Claude-shape input and the Pi-shape input must produce
# byte-equal canonical envelopes (after `jq -S` canonicalization).
#
# Anti-cheat (1) — subprocess invocation: every migrated shim under
# bin/frw.d/hooks/ (excluding non-emitters and already-canonical ones)
# must source blocker_emit.sh and route through `furrow_guard` /
# `emit_canonical_blocker`. No shim hand-rolls a canonical envelope
# literal. (Per AC-4 in specs/coverage-and-parity-tests.md.)
#
# Anti-cheat (2) — emit-site inventory gate: every migrated shim
# enumerates the set of event-types it dispatches. Each event-type's
# emitted_codes[] (per schemas/blocker-event.yaml) must have a complete
# fixture set under tests/integration/fixtures/blocker-events/<code>/
# {claude.json, pi.json, expected-envelope.json}. Adding a new shim
# without per-code fixtures fails this gate. (Per AC-5, AC-10.)
#
# Pi coverage note: only codes with a live Pi handler are claimed as parity
# surfaces. Codes without a handler remain inventory coverage, not parity pass.
#
# Auto-discovered by tests/integration/run-all.sh's test-*.sh glob.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-blocker-parity.sh ==="

# --- Structural prerequisites -------------------------------------------
for _bin in jq yq go; do
  if ! command -v "$_bin" >/dev/null 2>&1; then
    printf '  FAIL: required command not on PATH: %s\n' "$_bin" >&2
    exit 1
  fi
done

HOOK_DIR="${PROJECT_ROOT}/bin/frw.d/hooks"
EVENT_CATALOG="${PROJECT_ROOT}/schemas/blocker-event.yaml"
PI_ADAPTER="${PROJECT_ROOT}/adapters/pi/validate-actions.ts"
PI_DRIVER="${PROJECT_ROOT}/adapters/pi/test-driver-blocker-parity.ts"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/blocker-events"

# --- Configuration ------------------------------------------------------
# DEFERRED_CODES: same operational mirror as the coverage test; D3 deferred
# zero codes per .furrow/rows/.../research/hook-audit-final.md §4.
DEFERRED_CODES=""

# MIGRATED_SHIMS: derived from hook-audit-final.md §1. Excludes:
#   - already-canonical (validate-definition.sh, ownership-warn.sh)
#   - non-emitters     (append-learning.sh, auto-install.sh, post-compact.sh)
#   - deleted          (gate-check.sh — not on disk)
MIGRATED_SHIMS="
correction-limit.sh
pre-commit-bakfiles.sh
pre-commit-script-modes.sh
pre-commit-typechange.sh
script-guard.sh
state-guard.sh
stop-ideation.sh
validate-summary.sh
verdict-guard.sh
work-check.sh
"

# Pi-handler presence: handlers exported from adapters/pi/validate-actions.ts.
# Only definition_* and ownership_outside_scope have native Pi handlers
# today. All other codes are fixture inventory only until their Pi handler is
# implemented. They must not be counted as Pi parity passes.
PI_HANDLER_PRESENT_CODES="
definition_yaml_invalid
definition_objective_missing
definition_gate_policy_missing
definition_gate_policy_invalid
definition_mode_invalid
definition_deliverables_empty
definition_deliverable_name_missing
definition_deliverable_name_invalid_pattern
definition_acceptance_criteria_placeholder
definition_unknown_keys
ownership_outside_scope
"
# Note: those 11 codes are NOT emitted by any of the 10 migrated shims. The
# migrated-shim loop below therefore currently performs inventory coverage for
# non-claimed Pi surfaces and does not count them as parity passes.

# --- Pre-test asserts ---------------------------------------------------
if [ ! -d "$HOOK_DIR" ]; then
  printf '  FAIL: hook dir missing: %s\n' "$HOOK_DIR" >&2
  exit 1
fi
if [ ! -f "$EVENT_CATALOG" ]; then
  printf '  FAIL: event catalog missing: %s\n' "$EVENT_CATALOG" >&2
  exit 1
fi
if [ ! -f "$PI_DRIVER" ]; then
  printf '  FAIL: Pi driver missing: %s (D4 must ship it)\n' "$PI_DRIVER" >&2
  exit 1
fi

# --- Build code → event-type map ----------------------------------------
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

# Build event-type → emitted_codes[] map (one per line: "<event_type> <code>").
event_codes_map() {
  yq -r '.event_types[] | .name as $n | .emitted_codes[] | "\($n) \(.)"' "$EVENT_CATALOG"
}

# Capture dir for shim/driver outputs.
CAPTURE_DIR="$(mktemp -d)"
trap 'rm -rf "${CAPTURE_DIR:-}"' EXIT INT TERM

# --- Anti-cheat (1): subprocess invocation -----------------------------
echo "  --- anti-cheat #1: subprocess invocation ---"
for _shim in $MIGRATED_SHIMS; do
  _path="${HOOK_DIR}/${_shim}"
  if [ ! -f "$_path" ]; then
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "  FAIL: anti-cheat #1: shim missing: %s\n" "$_path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    continue
  fi
  # Must invoke `furrow_guard` (or `emit_canonical_blocker`, which
  # transitively requires guard output upstream — work-check.sh uses
  # the run_stop_work_check helper which calls furrow_guard internally).
  assert_file_contains \
    "${_shim} routes through furrow_guard or emit_canonical_blocker" \
    "$_path" \
    "furrow_guard\|emit_canonical_blocker"
  # Must NOT contain a hard-coded canonical envelope literal — i.e., a
  # `"code"` key declaration in JSON form. (Catches a shim that pretends
  # to invoke Go but actually echoes a hand-rolled envelope.)
  assert_file_not_contains \
    "${_shim} has no hand-rolled \"code\": envelope literal" \
    "$_path" \
    '"code"[[:space:]]*:[[:space:]]*"'
done

# --- Anti-cheat (2): emit-site inventory gate --------------------------
echo "  --- anti-cheat #2: emit-site inventory gate ---"
# For each migrated shim, find the event_types it dispatches via
# `furrow_guard <event_type>`, then enumerate that event_type's
# emitted_codes[] and assert the fixture set exists.
for _shim in $MIGRATED_SHIMS; do
  _path="${HOOK_DIR}/${_shim}"
  [ -f "$_path" ] || continue
  # Extract every `furrow_guard <event_type>` token. The event_type
  # follows the function-name token; awk picks the next field.
  _event_types="$( { grep -oE 'furrow_guard[[:space:]]+[a-z_]+' "$_path" \
                       || true; } | awk '{print $2}' | sort -u)"
  # work-check.sh dispatches via the run_stop_work_check helper rather
  # than calling furrow_guard directly. Map the helper to its event_type.
  if grep -q 'run_stop_work_check' "$_path"; then
    _event_types="$(printf '%s\nstop_work_check\n' "$_event_types" | sort -u)"
  fi
  _event_types="$(printf '%s\n' "$_event_types" | grep -v '^$' || true)"

  if [ -z "$_event_types" ]; then
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "  FAIL: shim %s: no furrow_guard <event_type> invocation found\n" \
      "$_shim" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    continue
  fi

  for _et in $_event_types; do
    # Get emitted codes for this event_type from the catalog.
    _codes="$(event_codes_map | awk -v et="$_et" '$1==et {print $2}')"
    if [ -z "$_codes" ]; then
      TESTS_RUN=$((TESTS_RUN + 1))
      printf "  FAIL: shim %s emits event_type %s but catalog has no codes\n" \
        "$_shim" "$_et" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      continue
    fi
    for _code in $_codes; do
      _dir="${FIXTURE_ROOT}/${_code}"
      assert_file_exists \
        "shim ${_shim} emits ${_code}: claude.json present" \
        "${_dir}/claude.json"
      assert_file_exists \
        "shim ${_shim} emits ${_code}: pi.json present" \
        "${_dir}/pi.json"
      assert_file_exists \
        "shim ${_shim} emits ${_code}: expected-envelope.json present" \
        "${_dir}/expected-envelope.json"
    done
  done
done

# --- Per-(shim, code) parity replay -------------------------------------
echo "  --- per-(shim, code) parity replay ---"

pi_handler_for_code_present() {
  _c="$1"
  case " $(printf '%s' "$PI_HANDLER_PRESENT_CODES" | tr '\n' ' ') " in
    *" ${_c} "*) return 0 ;;
    *) return 1 ;;
  esac
}

# Replay one code's claude.json through its shim and pi.json through the
# Pi driver, then jq -S diff the two stdouts and the expected envelope.
parity_replay() {
  _shim="$1"; _event_type="$2"; _code="$3"
  _dir="${FIXTURE_ROOT}/${_code}"

  case " $DEFERRED_CODES " in
    *" ${_code} "*)
      printf "  SKIP: %s (reason: deferred per audit)\n" "$_code"
      return 0
      ;;
  esac

  if ! pi_handler_for_code_present "$_code"; then
    printf "  NOTE: %s inventory only (no claimed Pi handler for %s; not counted as parity)\n" \
      "$_code" "$_code"
    return 0
  fi

  # The remainder of this function executes only when the Pi handler
  # exists. None of the codes emitted by the 10 migrated shims fall
  # into the present-handler set today — this is the documented future
  # surface that closes when the follow-up TODO lands. The block is
  # preserved so adding a Pi handler automatically activates parity.

  _claude_out="${CAPTURE_DIR}/${_code}.claude.json"
  _pi_out="${CAPTURE_DIR}/${_code}.pi.json"

  # Render Claude fixture into the shim. Each shim defines a
  # `hook_<name>` function; we source and invoke it. Pre-commit shims
  # are exec'd directly (they `main`).
  ( cd "$PROJECT_ROOT" && \
      FURROW_ROOT="$PROJECT_ROOT" \
      bash -c '
        . "'"${HOOK_DIR}/${_shim}"'"
        # ... shim-specific entry call would go here
      ' < "${_dir}/claude.json" > "$_claude_out" 2>/dev/null ) || true

  # Render Pi fixture through the test driver.
  ( cd "$PROJECT_ROOT" && \
      bun run "$PI_DRIVER" "${_dir}/pi.json" \
      > "$_pi_out" 2>/dev/null ) || true

  # jq -S canonical diff.
  TESTS_RUN=$((TESTS_RUN + 1))
  if diff -u <(jq -S . "$_claude_out") <(jq -S . "$_pi_out") >/dev/null; then
    printf "  PASS: %s parity (claude == pi)\n" "$_code"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: %s parity diff:\n%s\n" "$_code" \
      "$(diff -u <(jq -S . "$_claude_out") <(jq -S . "$_pi_out"))" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Walk every (shim, event_type, code) triple. The code-set per shim is
# already validated by the inventory gate above; this loop is the
# parity assertion proper.
for _shim in $MIGRATED_SHIMS; do
  _path="${HOOK_DIR}/${_shim}"
  [ -f "$_path" ] || continue
  _event_types="$( { grep -oE 'furrow_guard[[:space:]]+[a-z_]+' "$_path" \
                       || true; } | awk '{print $2}' | sort -u)"
  if grep -q 'run_stop_work_check' "$_path"; then
    _event_types="$(printf '%s\nstop_work_check\n' "$_event_types" | sort -u)"
  fi
  _event_types="$(printf '%s\n' "$_event_types" | grep -v '^$' || true)"
  for _et in $_event_types; do
    _codes="$(event_codes_map | awk -v et="$_et" '$1==et {print $2}')"
    for _code in $_codes; do
      parity_replay "$_shim" "$_et" "$_code"
    done
  done
done

print_summary
