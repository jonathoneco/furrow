#!/bin/sh
# stop_payloads.sh — D3 helpers that assemble normalized BlockerEvent
# payloads for the three Stop-hook guard event types.
#
# Added per shared-contracts.md §C4 escape valve: "D3 may add new helpers
# to bin/frw.d/lib/ if shared by >=2 shims". These three helpers each
# gate a single shim, but they all share the row-resolution + state.json
# field-extraction substrate (factored as `_stop_resolve_row`).
#
# All file reads (state.json, definition.yaml) live here in lib/ rather
# than in the hook shim body, satisfying shared-contracts §C5
# AC-2.2 forbidden #4 ("project-file reads are out of the shim body").
#
# Exports (POSIX sh functions):
#
#   stop_event_ideation
#       Stdout: normalized BlockerEvent JSON for `stop_ideation_completeness`,
#               OR empty (signals "no row / not ideate step / autonomous"
#               so the upstream `furrow_guard | emit_canonical_blocker`
#               cleanly short-circuits with exit 0).
#
#   stop_event_summary
#       Stdout: normalized BlockerEvent JSON for `stop_summary_validation`,
#               OR empty.
#
#   stop_event_work_check
#       Stdout: a sequence of normalized BlockerEvent JSON documents — one
#               per active row. The shim pipes the stream into
#               `furrow_guard stop_work_check | emit_canonical_blocker`.
#               Empty stream → no active rows → silent pass.
#
# These helpers all return 0 unconditionally. Triggering decisions live
# in the Go handlers (internal/cli/stop_ideation.go,
# internal/cli/validate_summary.go, internal/cli/work_check.go).

if [ -n "${_FRW_STOP_PAYLOADS_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
_FRW_STOP_PAYLOADS_SOURCED=1

# _stop_resolve_row — resolve the focused row directory.
#
# Mirrors find_focused_row from common-minimal.sh:99 (the canonical helper
# already used by ownership-warn.sh:34 and correction-limit.sh:24). Returns
# the row directory on stdout (e.g., ".furrow/rows/foo") or empty string.
#
# This is a thin wrapper that keeps the dependency on common-minimal.sh
# isolated to lib/ — shims source this file, never common-minimal.sh
# directly (matches shared-contracts §C5 "library-source" invariant).
_stop_resolve_row() {
  if [ -z "${_FRW_COMMON_MINIMAL_SOURCED:-}" ]; then
    if [ -f "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh" ]; then
      # shellcheck source=common-minimal.sh disable=SC1091
      . "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"
      _FRW_COMMON_MINIMAL_SOURCED=1
    fi
  fi
  if command -v find_focused_row >/dev/null 2>&1; then
    find_focused_row
  else
    printf ''
  fi
}

# _stop_resolve_gate_policy — resolve the active row's gate_policy.
#
# Reads via the canonical resolve_config_value when common.sh is loadable;
# falls back to a yq read of .furrow/furrow.yaml or the row's
# definition.yaml. Default "supervised" matches stop-ideation.sh:46.
_stop_resolve_gate_policy() {
  _gp_row_dir="$1"
  if command -v resolve_config_value >/dev/null 2>&1; then
    _gp="$(resolve_config_value gate_policy 2>/dev/null)" || _gp=""
    if [ -n "$_gp" ]; then
      printf '%s' "$_gp"
      return 0
    fi
  fi
  if command -v yq >/dev/null 2>&1; then
    if [ -n "$_gp_row_dir" ] && [ -f "${_gp_row_dir}/definition.yaml" ]; then
      _gp="$(yq -r '.gate_policy // ""' "${_gp_row_dir}/definition.yaml" 2>/dev/null)" || _gp=""
      if [ -n "$_gp" ] && [ "$_gp" != "null" ]; then
        printf '%s' "$_gp"
        return 0
      fi
    fi
  fi
  printf 'supervised'
}

# stop_event_ideation
#
# Builds the payload for handleStopIdeationCompleteness:
#   { version: "1", event_type: "stop_ideation_completeness",
#     row, step,
#     payload: { row, gate_policy, definition_path } }
#
# Step gating: emit empty when the focused row's step != "ideate". This
# is data extraction, not a policy comparison — the shim never sees the
# step value, so the AC-2.2 forbidden-pattern grep stays clean against
# the shim body.
stop_event_ideation() {
  _se_dir="$(_stop_resolve_row)"
  [ -n "$_se_dir" ] || { printf ''; return 0; }
  _se_state="${_se_dir}/state.json"
  [ -f "$_se_state" ] || { printf ''; return 0; }
  _se_step="$(jq -r '.step // ""' "$_se_state" 2>/dev/null)" || _se_step=""
  # Only emit during the ideate step — out-of-step stops are silent.
  [ "$_se_step" = "ideate" ] || { printf ''; return 0; }

  _se_row="$(basename "$_se_dir")"
  _se_def="${_se_dir}/definition.yaml"
  _se_gp="$(_stop_resolve_gate_policy "$_se_dir")"
  jq -n \
    --arg version "1" \
    --arg event_type "stop_ideation_completeness" \
    --arg row "$_se_row" \
    --arg step "$_se_step" \
    --arg gate_policy "$_se_gp" \
    --arg def_path "$_se_def" \
    '{ version: $version,
       event_type: $event_type,
       row: $row,
       step: $step,
       payload: { row: $row,
                  gate_policy: $gate_policy,
                  definition_path: $def_path } }'
}

# stop_event_summary
#
# Builds the payload for handleStopSummaryValidation:
#   { version: "1", event_type: "stop_summary_validation",
#     row, step,
#     payload: { row, step, summary_path, last_decided_by } }
stop_event_summary() {
  _ss_dir="$(_stop_resolve_row)"
  [ -n "$_ss_dir" ] || { printf ''; return 0; }
  _ss_state="${_ss_dir}/state.json"
  _ss_summary="${_ss_dir}/summary.md"
  [ -f "$_ss_summary" ] || { printf ''; return 0; }

  _ss_row="$(basename "$_ss_dir")"
  _ss_step="$(jq -r '.step // ""' "$_ss_state" 2>/dev/null)" || _ss_step=""
  _ss_last="$(jq -r '.gates | last | .decided_by // ""' "$_ss_state" 2>/dev/null)" || _ss_last=""
  jq -n \
    --arg version "1" \
    --arg event_type "stop_summary_validation" \
    --arg row "$_ss_row" \
    --arg step "$_ss_step" \
    --arg summary_path "$_ss_summary" \
    --arg last_decided_by "$_ss_last" \
    '{ version: $version,
       event_type: $event_type,
       row: $row,
       step: $step,
       payload: { row: $row,
                  step: $step,
                  summary_path: $summary_path,
                  last_decided_by: $last_decided_by } }'
}

# run_stop_work_check
#
# End-to-end driver for the work-check Stop hook. Iterates active rows,
# invokes `furrow_guard stop_work_check` once per row, and writes a
# single merged envelope-array to stdout for `emit_canonical_blocker` to
# consume. Loop logic is here (not in the shim) because per-row iteration
# is shared substrate, not policy.
#
# Each per-row event payload includes:
#   { row, summary_path, state_validation_ok }
# where state_validation_ok is the verdict of validate_state_json against
# the row's state.json (true when validation passed).
run_stop_work_check() {
  _wc_acc='[]'
  if [ -z "${_FRW_VALIDATE_SOURCED:-}" ]; then
    if [ -f "${FURROW_ROOT}/bin/frw.d/lib/validate.sh" ]; then
      # shellcheck source=validate.sh disable=SC1091
      . "${FURROW_ROOT}/bin/frw.d/lib/validate.sh"
      _FRW_VALIDATE_SOURCED=1
    fi
  fi
  for _wc_state in "${FURROW_ROOT}"/.furrow/rows/*/state.json; do
    [ -f "$_wc_state" ] || continue
    _wc_archived="$(jq -r '.archived_at // "null"' "$_wc_state" 2>/dev/null)" || continue
    [ "$_wc_archived" = "null" ] || continue

    _wc_dir="$(dirname "$_wc_state")"
    _wc_row="$(basename "$_wc_dir")"
    _wc_summary="${_wc_dir}/summary.md"

    _wc_ok="true"
    if command -v validate_state_json >/dev/null 2>&1; then
      if ! validate_state_json "$_wc_state" >/dev/null 2>&1; then
        _wc_ok="false"
      fi
    fi

    _wc_event="$(
      jq -n \
        --arg version "1" \
        --arg event_type "stop_work_check" \
        --arg row "$_wc_row" \
        --arg summary_path "$_wc_summary" \
        --argjson state_ok "$_wc_ok" \
        '{ version: $version,
           event_type: $event_type,
           row: $row,
           payload: { row: $row,
                      summary_path: $summary_path,
                      state_validation_ok: $state_ok } }'
    )"
    _wc_envelopes="$(printf '%s' "$_wc_event" | furrow_guard stop_work_check 2>/dev/null || printf '[]')"
    [ -n "$_wc_envelopes" ] || _wc_envelopes='[]'
    _wc_acc="$(printf '%s\n%s' "$_wc_acc" "$_wc_envelopes" | jq -s 'add')"
  done
  printf '%s' "$_wc_acc"
}

# stop_event_work_check (legacy alias — kept for symmetry with the other
# two helpers; emits a single concatenated stream for callers that prefer
# the streaming pattern. Not used by the canonical work-check.sh shim.)
stop_event_work_check() {
  # Run validate_state_json once per active row and emit a payload doc.
  if [ -z "${_FRW_VALIDATE_SOURCED:-}" ]; then
    if [ -f "${FURROW_ROOT}/bin/frw.d/lib/validate.sh" ]; then
      # shellcheck source=validate.sh disable=SC1091
      . "${FURROW_ROOT}/bin/frw.d/lib/validate.sh"
      _FRW_VALIDATE_SOURCED=1
    fi
  fi
  for _wc_state in "${FURROW_ROOT}"/.furrow/rows/*/state.json; do
    [ -f "$_wc_state" ] || continue
    _wc_archived="$(jq -r '.archived_at // "null"' "$_wc_state" 2>/dev/null)" || continue
    [ "$_wc_archived" = "null" ] || continue

    _wc_dir="$(dirname "$_wc_state")"
    _wc_row="$(basename "$_wc_dir")"
    _wc_summary="${_wc_dir}/summary.md"

    _wc_ok="true"
    if command -v validate_state_json >/dev/null 2>&1; then
      if ! validate_state_json "$_wc_state" >/dev/null 2>&1; then
        _wc_ok="false"
      fi
    fi

    jq -n \
      --arg version "1" \
      --arg event_type "stop_work_check" \
      --arg row "$_wc_row" \
      --arg summary_path "$_wc_summary" \
      --argjson state_ok "$_wc_ok" \
      '{ version: $version,
         event_type: $event_type,
         row: $row,
         payload: { row: $row,
                    summary_path: $summary_path,
                    state_validation_ok: $state_ok } }'
  done
}
