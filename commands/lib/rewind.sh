#!/bin/sh
# rewind.sh — Rewind to a previous step
#
# Usage: rewind.sh <name> <target_step>
#   name        — work unit name
#   target_step — step to rewind to (must be at or before current step)
#
# Creates a fail gate record and resets to target step.
# Does NOT delete any artifacts (all preserved for reference).
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — state.json not found
#   3 — invalid target step
#   4 — target is after current step

set -eu

if [ "$#" -lt 2 ]; then
  echo "Usage: rewind.sh <name> <target_step>" >&2
  exit 1
fi

name="$1"
target_step="$2"

work_dir=".work/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

# --- validate target step is in sequence ---

target_idx="$(jq -r --arg step "${target_step}" '
  .steps_sequence | to_entries[] | select(.value == $step) | .key
' "${state_file}" 2>/dev/null)" || target_idx=""

if [ -z "${target_idx}" ]; then
  echo "Invalid step: '${target_step}' is not in steps_sequence." >&2
  exit 3
fi

# --- check target is at or before current step ---

current_step="$(jq -r '.step' "${state_file}")"
current_idx="$(jq -r --arg step "${current_step}" '
  .steps_sequence | to_entries[] | select(.value == $step) | .key
' "${state_file}")"

if [ "${target_idx}" -gt "${current_idx}" ]; then
  echo "Cannot rewind forward: '${target_step}' is after current step '${current_step}'." >&2
  exit 4
fi

# --- record fail gate ---

script_dir="$(cd "$(dirname "$0")" && pwd)"
harness_root="$(cd "${script_dir}/../.." && pwd)"
scripts_dir="${harness_root}/scripts"

boundary="${current_step}->${target_step}"

"${scripts_dir}/record-gate.sh" "${name}" "${boundary}" "fail" "human" \
  "User rewound: auto-advance was incorrect or step needs rework"

# --- reset step ---

"${scripts_dir}/update-state.sh" "${name}" \
  ".step = \"${target_step}\" | .step_status = \"not_started\""

echo "Rewound: ${current_step} -> ${target_step}. Artifacts preserved."
