#!/bin/sh
# step-transition.sh — Two-phase step transition engine
#
# Usage:
#   step-transition.sh --request <name> <outcome> <decided_by> <evidence> [conditions_json]
#   step-transition.sh --confirm <name>
#   step-transition.sh <name> <outcome> <decided_by> <evidence> [conditions_json]   # legacy
#
# --request: Record gate, validate artifacts and summary, set pending_approval (supervised)
#            or fall through to complete inline (delegated/autonomous — no --confirm needed).
# --confirm: Validate policy, regenerate summary, advance step. Only needed in supervised mode.
# Legacy (no flag): Single-phase transition (backward compat for delegated/autonomous).
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — state.json not found
#   3 — cannot advance past review
#   4 — sub-command failed
#   5 — step_status is not pending_approval (--confirm without --request)
#   6 — decided_by violates gate_policy

set -eu

# --- flag parsing ---

phase=""
case "${1:-}" in
  --request)
    phase="request"
    shift
    ;;
  --confirm)
    phase="confirm"
    shift
    ;;
esac

# --- resolve paths ---

resolve_paths() {
  work_dir=".work/${name}"
  state_file="${work_dir}/state.json"
  definition_file="${work_dir}/definition.yaml"
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  furrow_root="$(cd "${script_dir}/../.." && pwd)"
  scripts_dir="${furrow_root}/scripts"
}

# --- read gate_policy from definition.yaml ---

read_gate_policy() {
  if [ -f "${definition_file}" ] && command -v yq > /dev/null 2>&1; then
    gate_policy="$(yq -r '.gate_policy // "supervised"' "${definition_file}" 2>/dev/null)" || gate_policy="supervised"
  else
    gate_policy="supervised"
  fi
}

# --- determine boundary ---

determine_boundary() {
  current_step="$(jq -r '.step' "${state_file}")"
  current_idx="$(jq -r --arg step "${current_step}" '.steps_sequence | to_entries[] | select(.value == $step) | .key' "${state_file}")"
  total_steps="$(jq -r '.steps_sequence | length' "${state_file}")"
  last_idx=$((total_steps - 1))
  next_idx=$((current_idx + 1))
  next_step="$(jq -r --argjson idx "${next_idx}" '.steps_sequence[$idx] // "review"' "${state_file}")"
  boundary="${current_step}->${next_step}"
}

# ============================================================
# --confirm phase
# ============================================================

if [ "${phase}" = "confirm" ]; then
  if [ "$#" -lt 1 ]; then
    echo "Usage: step-transition.sh --confirm <name>" >&2
    exit 1
  fi

  name="$1"
  resolve_paths

  if [ ! -f "${state_file}" ]; then
    echo "State file not found: ${state_file}" >&2
    exit 2
  fi

  # Verify pending_approval state
  step_status="$(jq -r '.step_status' "${state_file}")"
  if [ "${step_status}" != "pending_approval" ]; then
    echo "Cannot confirm: step_status is '${step_status}', expected 'pending_approval'." >&2
    echo "Call step-transition.sh --request first." >&2
    exit 5
  fi

  determine_boundary
  read_gate_policy

  # Read decided_by from the most recent gate record for this boundary
  decided_by="$(jq -r --arg b "${boundary}" '[.gates[] | select(.boundary == $b)] | last | .decided_by // ""' "${state_file}")"

  # Validate decided_by against gate_policy
  case "${gate_policy}" in
    supervised)
      if [ "${decided_by}" != "manual" ]; then
        echo "Policy violation: supervised mode requires decided_by=manual, got '${decided_by}'." >&2
        exit 6
      fi
      ;;
    delegated)
      case "${decided_by}" in
        manual|evaluated) ;;
        *)
          echo "Policy violation: delegated mode requires decided_by=manual or evaluated, got '${decided_by}'." >&2
          exit 6
          ;;
      esac
      ;;
    autonomous)
      # All decided_by values accepted
      ;;
  esac

  # Validate verdict file exists with matching nonce (if evaluator ran)
  if [ "${decided_by}" = "evaluated" ]; then
    # Check for post_step verdict first, then pre_step
    verdict_file=""
    for vtype in post_step pre_step; do
      vf="${work_dir}/gate-verdicts/${vtype}-${current_step}.json"
      if [ -f "$vf" ]; then
        verdict_file="$vf"
        break
      fi
    done

    if [ -z "${verdict_file}" ]; then
      echo "Verdict file not found in ${work_dir}/gate-verdicts/. Evaluator must write verdict before confirming." >&2
      exit 4
    fi

    # Validate nonce matches prompt file
    prompt_file=""
    for ptype in post_step pre_step; do
      pf="${work_dir}/gate-prompts/${ptype}-${current_step}.yaml"
      if [ -f "$pf" ]; then
        prompt_file="$pf"
        break
      fi
    done

    if [ -z "${prompt_file}" ]; then
      echo "Prompt file not found in ${work_dir}/gate-prompts/. Cannot validate verdict nonce." >&2
      exit 4
    fi

    prompt_nonce="$(grep '^nonce:' "${prompt_file}" | sed 's/^nonce: *//' | tr -d '[:space:]')" || prompt_nonce=""
    verdict_nonce="$(jq -r '.nonce // ""' "${verdict_file}" 2>/dev/null)" || verdict_nonce=""

    if [ -n "${prompt_nonce}" ] && [ "${prompt_nonce}" != "${verdict_nonce}" ]; then
      echo "Nonce mismatch: prompt='${prompt_nonce}' verdict='${verdict_nonce}'. Verdict may be stale or forged." >&2
      exit 4
    fi
  fi

  # Regenerate summary
  "${scripts_dir}/regenerate-summary.sh" "${name}" || {
    echo "Warning: summary regeneration failed" >&2
  }

  # Advance step
  "${scripts_dir}/advance-step.sh" "${name}" || {
    echo "Failed to advance step" >&2
    exit 4
  }

  echo "Transition complete: ${boundary} (confirmed)"
  exit 0
fi

# ============================================================
# --request phase (or legacy single-phase)
# ============================================================

if [ "$#" -lt 4 ]; then
  echo "Usage: step-transition.sh [--request] <name> <outcome> <decided_by> <evidence> [conditions_json]" >&2
  exit 1
fi

name="$1"
outcome="$2"
decided_by="$3"
evidence="$4"
conditions_json="${5:-}"

resolve_paths

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

determine_boundary

if [ "${outcome}" != "fail" ] && [ "${current_idx}" -eq "${last_idx}" ]; then
  echo "Cannot advance past final step 'review'." >&2
  exit 3
fi

# --- 1. Record gate ---

if [ -n "${conditions_json}" ]; then
  "${scripts_dir}/record-gate.sh" "${name}" "${boundary}" "${outcome}" "${decided_by}" "${evidence}" "${conditions_json}" || {
    echo "Failed to record gate" >&2
    exit 4
  }
else
  "${scripts_dir}/record-gate.sh" "${name}" "${boundary}" "${outcome}" "${decided_by}" "${evidence}" || {
    echo "Failed to record gate" >&2
    exit 4
  }
fi

# --- 1b. Validate step artifacts (only on pass/conditional) ---

if [ "${outcome}" != "fail" ]; then
  "${scripts_dir}/validate-step-artifacts.sh" "${name}" "${boundary}" || {
    echo "Artifact validation failed for ${boundary}. Gate recorded but advancement blocked." >&2
    exit 4
  }
fi

# --- handle fail: do not advance ---

if [ "${outcome}" = "fail" ]; then
  "${scripts_dir}/update-state.sh" "${name}" '.step_status = "in_progress"'
  case "${current_step}" in
    implement|review)
      "${scripts_dir}/update-state.sh" "${name}" \
        '.deliverables |= with_entries(if .value.status == "in_progress" then .value.corrections = ((.value.corrections // 0) + 1) else . end)' \
        2>/dev/null || true
      ;;
  esac
  echo "Gate failed: ${boundary}. Step remains at ${current_step}."
  exit 0
fi

# --- 1c. Wave conflict check at implement->review boundary (code mode only) ---

if [ "${current_step}" = "implement" ] && [ "${next_step}" = "review" ]; then
  _mode="$(jq -r '.mode // "code"' "${state_file}" 2>/dev/null)" || _mode="code"
  if [ "${_mode}" = "code" ]; then
    "${scripts_dir}/check-wave-conflicts.sh" "${name}" 2>&1 || {
      echo "Warning: wave conflicts detected (non-blocking)" >&2
    }
  fi
fi

# --- 1d. Validate summary sections (before regeneration) ---

if [ "${outcome}" != "fail" ]; then
  validate_summary="${furrow_root}/hooks/validate-summary.sh"
  if [ -x "${validate_summary}" ]; then
    "${validate_summary}" "${current_step}" || {
      echo "Summary validation failed. Populate Key Findings, Open Questions, and Recommendations in summary.md before advancing." >&2
      echo "See skills/shared/summary-protocol.md for step-specific requirements." >&2
      exit 4
    }
  fi
fi

# --- Phase split: --request stops here, legacy continues ---

if [ "${phase}" = "request" ]; then
  read_gate_policy
  if [ "${gate_policy}" = "supervised" ]; then
    "${scripts_dir}/update-state.sh" "${name}" '.step_status = "pending_approval"'
    echo "Gate recorded: ${boundary} (${outcome}). Awaiting user approval."
    echo "Call step-transition.sh --confirm ${name} after user approves."
    exit 0
  fi
  # For delegated/autonomous, fall through to complete inline
fi

# --- 2. Regenerate summary ---

"${scripts_dir}/regenerate-summary.sh" "${name}" || {
  echo "Warning: summary regeneration failed" >&2
}

# --- 3. Advance step ---

"${scripts_dir}/advance-step.sh" "${name}" || {
  echo "Failed to advance step" >&2
  exit 4
}

echo "Transition complete: ${boundary} (${outcome})"
