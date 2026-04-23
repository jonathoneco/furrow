#!/bin/sh
# merge-verify.sh — Phase 5 of /furrow:merge
#
# Usage: frw_merge_verify <merge_id>
#
# Runs post-merge invariant checks. Writes verify.json.
#
# Exit codes:
#   0  all checks pass
#   1  usage error
#   2  execute.json missing (merge not completed)
#   7  one or more post-merge regressions (see verify.json for detail)
#
# Checks performed:
#   1. frw doctor exits 0
#   2. No bin/* path deleted by the merge (diff against base_sha)
#   3. All bin/frw.d/**/*.sh parse cleanly (sh -n)
#   4. seeds.jsonl + todos.yaml satisfy sort invariant (rws validate-sort-invariant)
#   5. rescue.sh is callable (sh -n passes; invocation exits 0 or 1)
#   6. common-minimal.sh matches rescue.sh bundled baseline (rescue --baseline-check exits 0 or 1; exit 3 = drift)

set -eu

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
FURROW_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source shared merge library (policy validation + shared helpers)
. "${SCRIPT_DIR}/merge-lib.sh"

_die() { printf '[furrow:error] merge-verify: %s\n' "$1" >&2; exit "${2:-1}"; }
_info() { printf '[furrow:info] merge-verify: %s\n' "$*" >&2; }
_warn() { printf '[furrow:warning] merge-verify: %s\n' "$*" >&2; }

_get_state_dir() {
  _xdg="${XDG_STATE_HOME:-${HOME}/.local/state}"
  _repo_slug="$(basename "$FURROW_ROOT")"
  printf '%s/furrow/%s/merge-state' "$_xdg" "$_repo_slug"
}

# Run a single check and record result
# _check_result <check_name> <pass|fail> <evidence>
_check_result() {
  _cn="$1"; _pass="$2"; _evidence="$3"
  jq -n \
    --arg name "$_cn" \
    --arg pass "$_pass" \
    --arg evidence "$_evidence" \
    '{name: $name, pass: ($pass == "pass"), evidence: $evidence}'
}

frw_merge_verify() {
  [ $# -ge 1 ] || { printf 'Usage: frw merge-verify <merge_id>\n' >&2; exit 1; }

  _merge_id="$1"
  _state_base="$(_get_state_dir)"
  _merge_dir="${_state_base}/${_merge_id}"
  _audit_json="${_merge_dir}/audit.json"
  _execute_json="${_merge_dir}/execute.json"

  command -v jq >/dev/null 2>&1 || _die "jq is required" 2

  [ -f "$_execute_json" ] || _die "execute.json not found — run merge-execute first" 2
  [ -f "$_audit_json" ] || _die "audit.json not found" 2

  # Validate merge-policy shape (belt-and-suspenders — all phases validate)
  _policy_path="$(jq -r '.policy_path // ""' "$_audit_json" 2>/dev/null || true)"
  if [ -n "$_policy_path" ]; then
    merge_validate_policy "$_policy_path" "merge-verify"
  fi

  _base_sha="$(jq -r '.base_sha' "$_audit_json")"
  _branch="$(jq -r '.branch' "$_audit_json")"

  _info "running post-merge verification for merge_id=$_merge_id"

  _checks="[]"
  _overall_pass=1

  # ---------------------------------------------------------------------------
  # Check 1: frw doctor exits 0
  # ---------------------------------------------------------------------------
  _c1_pass="fail"
  _c1_evidence="frw doctor did not run or failed"
  _c1_exit=0
  "$FURROW_ROOT/bin/frw" doctor 2>/tmp/frw_doctor_output || _c1_exit=$?
  if [ "$_c1_exit" -eq 0 ]; then
    _c1_pass="pass"
    _c1_evidence="frw doctor exited 0"
  else
    _c1_evidence="frw doctor exited $_c1_exit: $(cat /tmp/frw_doctor_output 2>/dev/null | head -5 | tr '\n' ' ')"
    _overall_pass=0
  fi
  rm -f /tmp/frw_doctor_output
  _checks="$(printf '%s' "$_checks" | jq --argjson e "$(_check_result "frw_doctor" "$_c1_pass" "$_c1_evidence")" '. + [$e]')"

  # ---------------------------------------------------------------------------
  # Check 2: No bin/* path deleted by the merge
  # ---------------------------------------------------------------------------
  _c2_pass="fail"
  _c2_evidence="check not run"
  _deleted_bins="$(git -C "$PROJECT_ROOT" diff --diff-filter=D --name-only "${_base_sha}" HEAD -- 'bin/*' 2>/dev/null || true)"
  if [ -z "$_deleted_bins" ]; then
    _c2_pass="pass"
    _c2_evidence="No bin/* paths deleted by merge"
  else
    _c2_evidence="bin/ paths deleted: $(printf '%s' "$_deleted_bins" | tr '\n' ' ')"
    _overall_pass=0
  fi
  _checks="$(printf '%s' "$_checks" | jq --argjson e "$(_check_result "no_bin_deletions" "$_c2_pass" "$_c2_evidence")" '. + [$e]')"

  # ---------------------------------------------------------------------------
  # Check 3: All bin/frw.d/**/*.sh parse cleanly
  # ---------------------------------------------------------------------------
  _c3_pass="pass"
  _c3_evidence="All bin/frw.d/**/*.sh pass sh -n"
  _c3_fails=""
  _frwd_dir="${PROJECT_ROOT}/bin/frw.d"
  if [ -d "$_frwd_dir" ]; then
    find "$_frwd_dir" -name '*.sh' -type f | while IFS= read -r _sh; do
      if ! sh -n "$_sh" 2>/dev/null; then
        printf '%s\n' "$_sh"
      fi
    done > /tmp/frw_syntax_fails || true
    _c3_fails="$(cat /tmp/frw_syntax_fails 2>/dev/null || true)"
    rm -f /tmp/frw_syntax_fails
    if [ -n "$_c3_fails" ]; then
      _c3_pass="fail"
      _c3_evidence="Syntax errors in: $(printf '%s' "$_c3_fails" | tr '\n' ' ')"
      _overall_pass=0
    fi
  fi
  _checks="$(printf '%s' "$_checks" | jq --argjson e "$(_check_result "shell_syntax" "$_c3_pass" "$_c3_evidence")" '. + [$e]')"

  # ---------------------------------------------------------------------------
  # Check 4: Sort invariant (rws validate-sort-invariant)
  # ---------------------------------------------------------------------------
  _c4_pass="fail"
  _c4_evidence="rws validate-sort-invariant not run"
  _seeds_file="${PROJECT_ROOT}/.furrow/seeds/seeds.jsonl"
  _todos_file="${PROJECT_ROOT}/.furrow/almanac/todos.yaml"
  _c4_exit=0

  if [ -f "$_seeds_file" ] || [ -f "$_todos_file" ]; then
    rws validate-sort-invariant 2>/tmp/rws_sort_output || _c4_exit=$?
    if [ "$_c4_exit" -eq 0 ]; then
      _c4_pass="pass"
      _c4_evidence="rws validate-sort-invariant exited 0 — sort invariant holds"
    else
      _c4_evidence="rws validate-sort-invariant exited $_c4_exit: $(cat /tmp/rws_sort_output 2>/dev/null | head -3 | tr '\n' ' ')"
      _overall_pass=0
    fi
    rm -f /tmp/rws_sort_output
  else
    _c4_pass="pass"
    _c4_evidence="No seeds.jsonl or todos.yaml to check"
  fi
  _checks="$(printf '%s' "$_checks" | jq --argjson e "$(_check_result "sort_invariant" "$_c4_pass" "$_c4_evidence")" '. + [$e]')"

  # ---------------------------------------------------------------------------
  # Check 5: rescue.sh is callable (sh -n + diagnose-only invocation)
  # ---------------------------------------------------------------------------
  _c5_pass="fail"
  _c5_evidence="rescue.sh not callable"
  _rescue_path="${FURROW_ROOT}/bin/frw.d/scripts/rescue.sh"

  if [ ! -f "$_rescue_path" ]; then
    _c5_evidence="rescue.sh not found at $_rescue_path"
    _overall_pass=0
  elif ! sh -n "$_rescue_path" 2>/dev/null; then
    _c5_evidence="rescue.sh fails sh -n syntax check"
    _overall_pass=0
  else
    # Invoke rescue.sh WITHOUT --apply (diagnose-only mode)
    _rescue_exit=0
    sh "$_rescue_path" 2>/dev/null || _rescue_exit=$?
    # Exit 0 or 1 are acceptable (nothing to do / diagnosed)
    if [ "$_rescue_exit" -eq 0 ] || [ "$_rescue_exit" -eq 1 ]; then
      _c5_pass="pass"
      _c5_evidence="rescue.sh callable; diagnose-only exited $_rescue_exit (acceptable)"
    else
      _c5_evidence="rescue.sh diagnose-only exited $_rescue_exit (expected 0 or 1)"
      _overall_pass=0
    fi
  fi
  _checks="$(printf '%s' "$_checks" | jq --argjson e "$(_check_result "rescue_callable" "$_c5_pass" "$_c5_evidence")" '. + [$e]')"

  # ---------------------------------------------------------------------------
  # Check 6: common-minimal.sh matches rescue.sh bundled baseline
  # ---------------------------------------------------------------------------
  _c6_pass="fail"
  _c6_evidence="rescue --baseline-check not run"
  _c6_exit=0

  if [ -f "$_rescue_path" ]; then
    sh "$_rescue_path" --baseline-check 2>/tmp/rescue_baseline_output || _c6_exit=$?
    if [ "$_c6_exit" -eq 0 ] || [ "$_c6_exit" -eq 1 ]; then
      _c6_pass="pass"
      _c6_evidence="rescue.sh --baseline-check exited $_c6_exit — no drift detected"
    elif [ "$_c6_exit" -eq 3 ]; then
      _c6_evidence="rescue.sh --baseline-check exit 3 — common-minimal.sh has drifted from bundled baseline"
      _overall_pass=0
    else
      _c6_evidence="rescue.sh --baseline-check exited $_c6_exit (unexpected)"
      _overall_pass=0
    fi
    rm -f /tmp/rescue_baseline_output
  else
    _c6_evidence="rescue.sh not found — cannot run baseline-check"
    _overall_pass=0
  fi
  _checks="$(printf '%s' "$_checks" | jq --argjson e "$(_check_result "baseline_drift" "$_c6_pass" "$_c6_evidence")" '. + [$e]')"

  # ---------------------------------------------------------------------------
  # Write verify.json
  # ---------------------------------------------------------------------------
  _overall_label="$([ "$_overall_pass" -eq 1 ] && echo 'pass' || echo 'fail')"

  jq -n \
    --arg schema_version "1.0" \
    --arg merge_id "$_merge_id" \
    --arg overall "$_overall_label" \
    --argjson checks "$_checks" \
    '{
      schema_version: $schema_version,
      merge_id: $merge_id,
      overall: $overall,
      checks: $checks
    }' > "${_merge_dir}/verify.json"

  if [ "$_overall_pass" -eq 1 ]; then
    _info "all checks passed — verify complete"
    exit 0
  else
    _n_fails="$(printf '%s' "$_checks" | jq '[.[] | select(.pass == false)] | length')"
    _warn "$_n_fails check(s) failed — see ${_merge_dir}/verify.json"
    exit 7
  fi
}

frw_merge_verify "$@"
