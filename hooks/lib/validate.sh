#!/bin/sh
# validate.sh — Structural validation functions for V2 harness schemas
#
# Sourced by hook scripts; not executed directly.
# Dependencies: jq, yq
#
# Each validate_* function prints errors to stderr and returns 0 on valid, 1 on invalid.

set -eu

# --- validate_definition_yaml ---
# AC-1.1a: Rejects files missing required fields (objective, deliverables, context_pointers, gate_policy).
# Rejects duplicate deliverable names. Rejects dangling depends_on references.
validate_definition_yaml() {
  _def_path="$1"
  _errors=""

  if [ ! -f "$_def_path" ]; then
    echo "File not found: $_def_path" >&2
    return 1
  fi

  if ! command -v yq > /dev/null 2>&1; then
    echo "yq not available; skipping definition.yaml validation" >&2
    return 0
  fi

  # Check required fields
  _objective="$(yq -r '.objective // ""' "$_def_path" 2>/dev/null)" || _objective=""
  if [ -z "$_objective" ]; then
    _errors="${_errors}Missing required field: objective\n"
  fi

  _del_count="$(yq -r '.deliverables | length' "$_def_path" 2>/dev/null)" || _del_count="0"
  if [ "$_del_count" -eq 0 ]; then
    _errors="${_errors}Missing or empty required field: deliverables (min 1)\n"
  fi

  _ctx_count="$(yq -r '.context_pointers | length' "$_def_path" 2>/dev/null)" || _ctx_count="0"
  if [ "$_ctx_count" -eq 0 ]; then
    _errors="${_errors}Missing or empty required field: context_pointers (min 1)\n"
  fi

  _gate_policy="$(yq -r '.gate_policy // ""' "$_def_path" 2>/dev/null)" || _gate_policy=""
  if [ -z "$_gate_policy" ]; then
    _errors="${_errors}Missing required field: gate_policy\n"
  else
    case "$_gate_policy" in
      supervised|delegated|autonomous) ;;
      *) _errors="${_errors}Invalid gate_policy: $_gate_policy (must be supervised, delegated, or autonomous)\n" ;;
    esac
  fi

  # Check deliverable name uniqueness
  if [ "$_del_count" -gt 0 ]; then
    _names="$(yq -r '.deliverables[].name' "$_def_path" 2>/dev/null)" || _names=""
    if [ -n "$_names" ]; then
      _dupes="$(echo "$_names" | sort | uniq -d)"
      if [ -n "$_dupes" ]; then
        for _dupe in $_dupes; do
          _errors="${_errors}Duplicate deliverable name: $_dupe\n"
        done
      fi

      # Check dangling depends_on
      _deps="$(yq -r '.deliverables[].depends_on[]? // empty' "$_def_path" 2>/dev/null)" || _deps=""
      for _dep in $_deps; do
        if ! echo "$_names" | grep -qx "$_dep"; then
          _errors="${_errors}Dangling depends_on reference: $_dep\n"
        fi
      done
    fi
  fi

  if [ -n "$_errors" ]; then
    printf "%b" "$_errors" >&2
    return 1
  fi
  return 0
}

# --- validate_state_json ---
# AC-1.1b: Rejects files with step values not in steps_sequence, invalid step_status enums,
# or missing required fields.
validate_state_json() {
  _state_path="$1"
  _errors=""

  if [ ! -f "$_state_path" ]; then
    echo "File not found: $_state_path" >&2
    return 1
  fi

  # Check required fields
  for _field in name step step_status steps_sequence created_at; do
    _val="$(jq -r ".$_field // \"__MISSING__\"" "$_state_path" 2>/dev/null)" || _val="__MISSING__"
    if [ "$_val" = "__MISSING__" ] || [ "$_val" = "null" ]; then
      _errors="${_errors}Missing required field: $_field\n"
    fi
  done

  # Validate step_status enum
  _status="$(jq -r '.step_status // ""' "$_state_path" 2>/dev/null)" || _status=""
  if [ -n "$_status" ]; then
    case "$_status" in
      not_started|in_progress|completed|blocked) ;;
      *) _errors="${_errors}Invalid step_status: $_status (must be not_started, in_progress, completed, or blocked)\n" ;;
    esac
  fi

  # Validate step is in steps_sequence
  _step="$(jq -r '.step // ""' "$_state_path" 2>/dev/null)" || _step=""
  if [ -n "$_step" ]; then
    _in_seq="$(jq -r --arg s "$_step" '
      if (.steps_sequence // []) | map(select(. == $s)) | length > 0 then "yes" else "no" end
    ' "$_state_path" 2>/dev/null)" || _in_seq="no"
    if [ "$_in_seq" = "no" ]; then
      _errors="${_errors}Step '$_step' is not in steps_sequence\n"
    fi
  fi

  # Validate steps_sequence is an array
  _seq_type="$(jq -r '.steps_sequence | type' "$_state_path" 2>/dev/null)" || _seq_type=""
  if [ "$_seq_type" != "array" ] && [ -n "$_seq_type" ]; then
    _errors="${_errors}steps_sequence must be an array, got: $_seq_type\n"
  fi

  # Validate gates is an array
  _gates_type="$(jq -r '.gates | type' "$_state_path" 2>/dev/null)" || _gates_type=""
  if [ "$_gates_type" != "array" ] && [ -n "$_gates_type" ]; then
    _errors="${_errors}gates must be an array, got: $_gates_type\n"
  fi

  if [ -n "$_errors" ]; then
    printf "%b" "$_errors" >&2
    return 1
  fi
  return 0
}

# --- validate_plan_json ---
# AC-1.1c: Rejects plans where deliverables are missing, dependency ordering violated,
# wave numbers non-contiguous, or file_ownership globs overlap within a wave.
validate_plan_json() {
  _plan_path="$1"
  _def_path="${2:-}"
  _errors=""

  if [ ! -f "$_plan_path" ]; then
    echo "File not found: $_plan_path" >&2
    return 1
  fi

  # Validate wave number contiguity (must start at 1, be sequential)
  _wave_valid="$(jq -r '
    [.waves[].wave] | sort |
    if length == 0 then "empty"
    elif .[0] != 1 then "must start at 1"
    else
      [range(length - 1) | . as $i | if .[$i + 1] - .[$i] != 1 then "non-contiguous" else empty end] |
      if length > 0 then .[0] else "ok" end
    end
  ' "$_plan_path" 2>/dev/null)" || _wave_valid="error"

  case "$_wave_valid" in
    ok) ;;
    empty) _errors="${_errors}Plan has no waves\n" ;;
    *) _errors="${_errors}Wave numbers: $_wave_valid\n" ;;
  esac

  # Check all definition deliverables are covered (if definition path provided)
  if [ -n "$_def_path" ] && [ -f "$_def_path" ] && command -v yq > /dev/null 2>&1; then
    _def_names="$(yq -r '.deliverables[].name' "$_def_path" 2>/dev/null | sort)" || _def_names=""
    _plan_names="$(jq -r '[.waves[].deliverables[]] | .[]' "$_plan_path" 2>/dev/null | sort)" || _plan_names=""

    if [ -n "$_def_names" ]; then
      for _name in $_def_names; do
        if ! echo "$_plan_names" | grep -qx "$_name"; then
          _errors="${_errors}Deliverable missing from plan: $_name\n"
        fi
      done
    fi

    # Check dependency ordering: deliverable must not appear in earlier wave than its deps
    _dep_errors="$(jq -r --argjson def_json "$(yq -o=json '.' "$_def_path" 2>/dev/null)" '
      . as $plan |
      # Build deliverable->wave map
      [.waves[] | .wave as $w | .deliverables[] | {name: ., wave: $w}] |
      from_entries as $wave_map |
      # Check each dependency
      [$def_json.deliverables[] | select(.depends_on != null) |
        .name as $name | .depends_on[] |
        . as $dep |
        if ($wave_map[$name] // 0) <= ($wave_map[$dep] // 0) then
          "Dependency violation: \($name) (wave \($wave_map[$name])) depends on \($dep) (wave \($wave_map[$dep]))"
        else empty end
      ] | .[]
    ' "$_plan_path" 2>/dev/null)" || _dep_errors=""
    if [ -n "$_dep_errors" ]; then
      _errors="${_errors}${_dep_errors}\n"
    fi
  fi

  # Check file_ownership non-overlap within a wave
  _overlap_errors="$(jq -r '
    .waves[] | .wave as $w |
    [.assignments | to_entries[] | .value.file_ownership // [] | .[]] |
    group_by(.) | map(select(length > 1) | .[0]) |
    if length > 0 then
      "Overlapping file_ownership in wave \($w): \(join(", "))"
    else empty end
  ' "$_plan_path" 2>/dev/null)" || _overlap_errors=""
  if [ -n "$_overlap_errors" ]; then
    _errors="${_errors}${_overlap_errors}\n"
  fi

  if [ -n "$_errors" ]; then
    printf "%b" "$_errors" >&2
    return 1
  fi
  return 0
}

# --- validate_step_boundary ---
# AC-1.1d: Rejects step advancement when no passing gate record exists.
validate_step_boundary() {
  _state_path="$1"
  _errors=""

  if [ ! -f "$_state_path" ]; then
    echo "File not found: $_state_path" >&2
    return 1
  fi

  _current="$(jq -r '.step' "$_state_path" 2>/dev/null)" || _current=""
  _seq="$(jq -r '.steps_sequence | join(",")' "$_state_path" 2>/dev/null)" || _seq=""

  if [ -z "$_current" ] || [ -z "$_seq" ]; then
    echo "Cannot determine step boundary: missing step or steps_sequence" >&2
    return 1
  fi

  # Find next step
  _next=""
  _found_current=0
  IFS=","
  for _s in $_seq; do
    if [ "$_found_current" -eq 1 ]; then
      _next="$_s"
      break
    fi
    if [ "$_s" = "$_current" ]; then
      _found_current=1
    fi
  done
  unset IFS

  if [ -z "$_next" ]; then
    echo "Already at final step: $_current" >&2
    return 1
  fi

  _boundary="${_current}->${_next}"

  # Source common.sh for has_passing_gate if not already sourced
  _lib_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || _lib_dir=""
  if [ -n "$_lib_dir" ] && [ -f "$_lib_dir/common.sh" ]; then
    # shellcheck source=common.sh
    . "$_lib_dir/common.sh" 2>/dev/null || true
  fi

  # Check for passing gate
  _gate_count="$(jq -r --arg b "$_boundary" '
    [.gates[] | select(.boundary == $b and (.outcome == "pass" or .outcome == "conditional"))] | length
  ' "$_state_path" 2>/dev/null)" || _gate_count="0"

  if [ "$_gate_count" -eq 0 ]; then
    echo "Gate required: $_boundary. No passing gate record found." >&2
    return 1
  fi

  return 0
}
