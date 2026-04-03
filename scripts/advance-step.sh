#!/bin/sh
# advance-step.sh — Step transition state machine
#
#
# Usage: advance-step.sh <name>
#   name — row name (kebab-case)
#
# Enforces:
#   - Sequential-only transitions (no skips, no backwards)
#   - Gate record must exist for the boundary before advancing
#   - Cannot advance past the final step (review)
#
# Exit codes:
#   0 — success
#   1 — usage/argument error
#   2 — state.json not found
#   3 — invalid transition (skip, backward, or past final)
#   4 — no gate record for boundary

set -eu

# --- argument validation ---

if [ "$#" -lt 1 ]; then
  echo "Usage: advance-step.sh <name>" >&2
  exit 1
fi

name="$1"

# --- locate state ---

work_dir=".furrow/rows/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

# --- read current state ---

current_step="$(jq -r '.step' "${state_file}")"

# --- find current index and next step ---

current_idx="$(jq -r --arg step "${current_step}" '.steps_sequence | to_entries[] | select(.value == $step) | .key' "${state_file}")"
total_steps="$(jq -r '.steps_sequence | length' "${state_file}")"

# Check if at final step
last_idx=$((total_steps - 1))
if [ "${current_idx}" -eq "${last_idx}" ]; then
  echo "Cannot advance past final step 'review'. Use archive to complete the row." >&2
  exit 3
fi

# Get next step
next_idx=$((current_idx + 1))
next_step="$(jq -r --argjson idx "${next_idx}" '.steps_sequence[$idx]' "${state_file}")"

# --- verify gate record exists for this boundary ---

boundary="${current_step}->${next_step}"

gate_pass="$(jq -r --arg boundary "${boundary}" '
  [.gates[] | select(.boundary == $boundary and (.outcome == "pass" or .outcome == "conditional"))] | length
' "${state_file}")"

if [ "${gate_pass}" -eq 0 ]; then
  echo "No passing gate record for boundary '${boundary}'. A gate with outcome 'pass' or 'conditional' is required." >&2
  exit 4
fi

# --- perform transition via update-state.sh ---

script_dir="$(cd "$(dirname "$0")" && pwd)"

"${script_dir}/update-state.sh" "${name}" \
  ".step = \"${next_step}\" | .step_status = \"not_started\""

# --- trigger branch creation at decompose->implement boundary ---

if [ "${current_step}" = "decompose" ] && [ "${next_step}" = "implement" ]; then
  existing_branch="$(jq -r '.branch // ""' "${state_file}")"
  if [ -z "${existing_branch}" ] || [ "${existing_branch}" = "null" ]; then
    "${script_dir}/create-work-branch.sh" "${name}" || {
      echo "Warning: branch creation failed" >&2
    }
  fi
fi

echo "Advanced: ${current_step} -> ${next_step}"
