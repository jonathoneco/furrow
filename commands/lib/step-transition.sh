#!/bin/sh
# step-transition.sh — Atomic step transition engine
#
# Usage: step-transition.sh <name> <outcome> <decided_by> <evidence> [conditions_json]
#   name            — work unit name
#   outcome         — "pass" | "fail" | "conditional"
#   decided_by      — "manual" | "evaluated" | "prechecked"
#   evidence        — one-line proof summary
#   conditions_json — JSON array (required for conditional)
#
# On pass/conditional:
#   1. Record gate
#   2. Regenerate summary.md
#   3. Advance step
#   4. Update timestamp
#
# On fail:
#   Record gate, reset step_status to in_progress, do NOT advance.
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — state.json not found
#   3 — cannot advance past review
#   4 — sub-command failed

set -eu

if [ "$#" -lt 4 ]; then
  echo "Usage: step-transition.sh <name> <outcome> <decided_by> <evidence> [conditions_json]" >&2
  exit 1
fi

name="$1"
outcome="$2"
decided_by="$3"
evidence="$4"
conditions_json="${5:-}"

work_dir=".work/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

# --- determine boundary ---

current_step="$(jq -r '.step' "${state_file}")"
current_idx="$(jq -r --arg step "${current_step}" '.steps_sequence | to_entries[] | select(.value == $step) | .key' "${state_file}")"
total_steps="$(jq -r '.steps_sequence | length' "${state_file}")"

last_idx=$((total_steps - 1))
next_idx=$((current_idx + 1))

if [ "${outcome}" != "fail" ] && [ "${current_idx}" -eq "${last_idx}" ]; then
  echo "Cannot advance past final step 'review'." >&2
  exit 3
fi

next_step="$(jq -r --argjson idx "${next_idx}" '.steps_sequence[$idx] // "review"' "${state_file}")"
boundary="${current_step}->${next_step}"

# --- resolve script paths ---

script_dir="$(cd "$(dirname "$0")" && pwd)"
harness_root="$(cd "${script_dir}/../.." && pwd)"
scripts_dir="${harness_root}/scripts"

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
  # Increment correction count for in-progress deliverables during implement/review
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
