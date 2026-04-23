#!/bin/bash
# test-config-resolution.sh — xdg-config-consumer-wiring AC-7 (+ legacy AC-4/AC-5)
#
# Verifies resolve_config_value three-tier chain for three runtime consumers:
#   - gate_policy  (wired in bin/rws::read_gate_policy + stop-ideation.sh)
#   - preferred_specialists.<role>  (first runtime consumer per AD-7/R3)
#   - cross_model.provider  (legacy coverage; wave-3 adopts the call sites)
#
# For each field asserts:
#   (a) project-local override wins,
#   (b) XDG value wins when no project file,
#   (c) compiled-in default returned when neither project nor XDG set the field.
#
# Sandbox contract: setup_sandbox() creates $TMP/{home,config,state,fixture}
# and exports HOME/XDG_CONFIG_HOME/XDG_STATE_HOME/FURROW_ROOT inside $TMP.
# FURROW_ROOT is kept inside $TMP — we populate $TMP/fixture/.furrow/furrow.yaml
# with tier-3 fixture yaml. bin/rws is invoked via its absolute path in the
# live checkout (SANDBOX_PROJECT_ROOT); that path is read-only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-config-resolution.sh (xdg-config-consumer-wiring AC-7) ==="

# --- Sandbox setup ----------------------------------------------------------
TMP="$(mktemp -d)"
export TMP
# Must call setup_sandbox WITHOUT command substitution — $(...) spawns a
# subshell and the export of FURROW_ROOT etc. wouldn't reach the parent shell.
setup_sandbox >/dev/null
FIXTURE_DIR="${TMP}/fixture"

# Absolute path to the live checkout (read-only from here on).
LIVE_ROOT="$SANDBOX_PROJECT_ROOT"
# common.sh sources common-minimal.sh via ${FURROW_ROOT}/bin/frw.d/lib/
# and find_specialist resolves ${FURROW_ROOT}/specialists. Symlink the live
# checkout's bin/ and specialists/ into the sandbox fixture root so FURROW_ROOT
# stays inside $TMP while code can still locate its deps. Only the sandbox
# tier-3 yaml lives at ${TMP}/fixture/.furrow/furrow.yaml and is writable.
ln -s "${LIVE_ROOT}/bin" "${TMP}/fixture/bin"
ln -s "${LIVE_ROOT}/specialists" "${TMP}/fixture/specialists" 2>/dev/null || true

COMMON_SH="${LIVE_ROOT}/bin/frw.d/lib/common.sh"
RWS_BIN="${LIVE_ROOT}/bin/rws"

# --- Helpers ----------------------------------------------------------------
_write_yaml() {
  local path="$1" content="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
}

# Reset per-test mutations. Each scenario rebuilds $TMP/proj (project tier),
# $TMP/config/furrow (XDG tier), and $TMP/fixture/.furrow (tier-3 fixture).
_reset_tiers() {
  rm -rf "${TMP}/proj" "${TMP}/config/furrow" "${TMP}/fixture/.furrow"
  mkdir -p "${TMP}/proj" "${TMP}/config" "${TMP}/fixture/.furrow"
  export PROJECT_ROOT="${TMP}/proj"
  export XDG_CONFIG_HOME="${TMP}/config"
  # FURROW_ROOT stays at ${TMP}/fixture (set by setup_sandbox)
}

T3_YAML="${TMP}/fixture/.furrow/furrow.yaml"

# Invoke resolve_config_value in a clean subshell with the current
# PROJECT_ROOT/XDG_CONFIG_HOME/FURROW_ROOT.
_resolve() {
  local key="$1"
  PROJECT_ROOT="$PROJECT_ROOT" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    FURROW_ROOT="$FURROW_ROOT" \
    sh -c ". '$COMMON_SH' && resolve_config_value '$key'" 2>/dev/null
}

trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# Scenario: gate_policy — three-tier precedence (AC2, AC3, AC7)
# ---------------------------------------------------------------------------
test_gate_policy_chain() {
  _reset_tiers
  _write_yaml "$T3_YAML" "gate_policy: autonomous"
  _write_yaml "${PROJECT_ROOT}/.furrow/furrow.yaml" "gate_policy: strict"
  _write_yaml "${XDG_CONFIG_HOME}/furrow/config.yaml" "gate_policy: supervised"

  local result
  result="$(_resolve gate_policy)"
  assert_output_contains "gate_policy: project override wins" "$result" "strict"

  rm "${PROJECT_ROOT}/.furrow/furrow.yaml"
  result="$(_resolve gate_policy)"
  assert_output_contains "gate_policy: XDG fallback when no project file" "$result" "supervised"

  rm "${XDG_CONFIG_HOME}/furrow/config.yaml"
  result="$(_resolve gate_policy)"
  assert_output_contains "gate_policy: compiled-in default used when neither overrides set" "$result" "autonomous"
}

# ---------------------------------------------------------------------------
# Scenario: bin/rws gate-policy subcommand uses the resolver (AC2)
# ---------------------------------------------------------------------------
test_rws_gate_policy_subcommand() {
  _reset_tiers
  _write_yaml "$T3_YAML" "gate_policy: autonomous"
  _write_yaml "${PROJECT_ROOT}/.furrow/furrow.yaml" "gate_policy: strict"

  local result
  # rws re-derives FURROW_ROOT from its own path, so we must point it at the
  # live checkout. We pass PROJECT_ROOT explicitly to override the cwd-based
  # default rws otherwise computes.
  result="$(cd "$PROJECT_ROOT" && \
    PROJECT_ROOT="$PROJECT_ROOT" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    FURROW_ROOT="$LIVE_ROOT" \
    "$RWS_BIN" gate-policy demo-row 2>/dev/null)"
  assert_output_contains "bin/rws gate-policy honors project override" "$result" "strict"

  # Remove project file → rws sees XDG/tier-3 via resolver; tier-3 in
  # live checkout is "supervised" (default yaml), so the hardcoded fallback
  # path is not the thing being verified here; we assert that bin/rws
  # returns SOME value and the invocation does not error.
  rm "${PROJECT_ROOT}/.furrow/furrow.yaml"
  _write_yaml "${XDG_CONFIG_HOME}/furrow/config.yaml" "gate_policy: delegated"
  result="$(cd "$PROJECT_ROOT" && \
    PROJECT_ROOT="$PROJECT_ROOT" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    FURROW_ROOT="$LIVE_ROOT" \
    "$RWS_BIN" gate-policy demo-row 2>/dev/null)"
  assert_output_contains "bin/rws gate-policy picks up XDG tier when project absent" "$result" "delegated"
}

# ---------------------------------------------------------------------------
# Scenario: preferred_specialists.<role> — three-tier (AC4, AC7)
# ---------------------------------------------------------------------------
test_preferred_specialists_chain() {
  _reset_tiers
  _write_yaml "$T3_YAML" "preferred_specialists:
  harness: harness-engineer-compiled"
  _write_yaml "${PROJECT_ROOT}/.furrow/furrow.yaml" "preferred_specialists:
  harness: harness-engineer-beta"
  _write_yaml "${XDG_CONFIG_HOME}/furrow/config.yaml" "preferred_specialists:
  harness: harness-engineer-xdg"

  local result
  result="$(_resolve preferred_specialists.harness)"
  assert_output_contains "preferred_specialists: project override wins" \
    "$result" "harness-engineer-beta"

  rm "${PROJECT_ROOT}/.furrow/furrow.yaml"
  result="$(_resolve preferred_specialists.harness)"
  assert_output_contains "preferred_specialists: XDG fallback when no project" \
    "$result" "harness-engineer-xdg"

  rm "${XDG_CONFIG_HOME}/furrow/config.yaml"
  result="$(_resolve preferred_specialists.harness)"
  assert_output_contains "preferred_specialists: compiled-in default used" \
    "$result" "harness-engineer-compiled"
}

# ---------------------------------------------------------------------------
# Scenario: preferred_specialists unset → resolver exits 1 (AC4 fallback branch)
# ---------------------------------------------------------------------------
test_preferred_specialists_unset_exits_1() {
  _reset_tiers
  _write_yaml "$T3_YAML" "preferred_specialists:
  harness: harness-engineer-compiled"

  local exit_code=0
  PROJECT_ROOT="$PROJECT_ROOT" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    FURROW_ROOT="$FURROW_ROOT" \
    sh -c ". '$COMMON_SH' && resolve_config_value preferred_specialists.foo >/dev/null" \
    || exit_code=$?
  assert_exit_code "unset preferred_specialists.<role> → exit 1" 1 "$exit_code"
}

# ---------------------------------------------------------------------------
# Scenario: cross_model.provider three-tier (AC1 test coverage)
# ---------------------------------------------------------------------------
test_cross_model_provider_chain() {
  _reset_tiers
  _write_yaml "$T3_YAML" "cross_model:
  provider: gamma"
  _write_yaml "${PROJECT_ROOT}/.furrow/furrow.yaml" "cross_model:
  provider: alpha"
  _write_yaml "${XDG_CONFIG_HOME}/furrow/config.yaml" "cross_model:
  provider: beta"

  local result
  result="$(_resolve cross_model.provider)"
  assert_output_contains "cross_model.provider: project wins" "$result" "alpha"

  rm "${PROJECT_ROOT}/.furrow/furrow.yaml"
  result="$(_resolve cross_model.provider)"
  assert_output_contains "cross_model.provider: XDG fallback" "$result" "beta"

  rm "${XDG_CONFIG_HOME}/furrow/config.yaml"
  result="$(_resolve cross_model.provider)"
  assert_output_contains "cross_model.provider: compiled-in default" "$result" "gamma"
}

# ---------------------------------------------------------------------------
# Scenario: no duplicate helper introduced (AC5)
# ---------------------------------------------------------------------------
test_no_duplicate_helper() {
  local count
  count="$(grep -rn '^resolve_config_value()' "${LIVE_ROOT}/bin" 2>/dev/null | wc -l | tr -d ' ')"
  assert_output_contains "exactly one definition of resolve_config_value in bin/" \
    "$count" "1"

  TESTS_RUN=$((TESTS_RUN + 1))
  if ! grep -rn 'get_config_field()\|resolve_with_default()' "${LIVE_ROOT}/bin" 2>/dev/null; then
    printf "  PASS: no forbidden duplicate helper names (get_config_field/resolve_with_default)\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: forbidden duplicate helper name found\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# Scenario: doctor-config-audit.sh exists, runs, exits 0
# ---------------------------------------------------------------------------
test_doctor_config_audit_runs() {
  local audit="${LIVE_ROOT}/bin/frw.d/scripts/doctor-config-audit.sh"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -x "$audit" ]; then
    printf "  PASS: doctor-config-audit.sh is executable (100755)\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: doctor-config-audit.sh missing or not executable\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  local exit_code=0
  "$audit" >/dev/null 2>&1 || exit_code=$?
  assert_exit_code "doctor-config-audit.sh exits 0" 0 "$exit_code"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
run_test test_gate_policy_chain
run_test test_rws_gate_policy_subcommand
run_test test_preferred_specialists_chain
run_test test_preferred_specialists_unset_exits_1
run_test test_cross_model_provider_chain
run_test test_no_duplicate_helper
run_test test_doctor_config_audit_runs

print_summary
