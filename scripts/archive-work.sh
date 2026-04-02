#!/bin/sh
# archive-work.sh — Archive a completed work unit
#
#
# Usage: archive-work.sh <name>
#   name — work unit name (kebab-case)
#
# Pre-conditions (all must be true):
#   - Current step is "review"
#   - Step status is "completed"
#   - All deliverables have status "completed"
#   - A passing gate record exists for the final boundary
#
# On success:
#   - Sets archived_at to current ISO 8601 timestamp
#   - Regenerates summary.md one final time
#   - Work unit directory remains on disk (not deleted)
#
# Exit codes:
#   0 — success
#   1 — usage/argument error
#   2 — state.json not found
#   3 — pre-condition failed

set -eu

# --- argument validation ---

if [ "$#" -lt 1 ]; then
  echo "Usage: archive-work.sh <name>" >&2
  exit 1
fi

name="$1"

# --- locate state ---

work_dir=".work/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"

# --- pre-condition checks ---

# 1. Current step must be "review"
current_step="$(jq -r '.step' "${state_file}")"
if [ "${current_step}" != "review" ]; then
  echo "Cannot archive: current step is '${current_step}', must be 'review'" >&2
  exit 3
fi

# 2. Step status must be "completed"
step_status="$(jq -r '.step_status' "${state_file}")"
if [ "${step_status}" != "completed" ]; then
  echo "Cannot archive: review step is not completed (status: '${step_status}')" >&2
  exit 3
fi

# 3. All deliverables must be "completed"
incomplete="$(jq -r '
  [.deliverables | to_entries[] | select(.value.status != "completed") |
    "\(.key):\(.value.status)"] | first // empty
' "${state_file}")"

if [ -n "${incomplete}" ]; then
  inc_name="$(echo "${incomplete}" | cut -d: -f1)"
  inc_status="$(echo "${incomplete}" | cut -d: -f2)"
  echo "Cannot archive: deliverable '${inc_name}' is not completed (status: '${inc_status}')" >&2
  exit 3
fi

# 4. Passing gate record for final boundary
# The final boundary is "implement->review" (the last step transition)
# We need a pass or conditional gate for this boundary
final_gate="$(jq -r '
  [.gates[] | select(.boundary == "implement->review" and (.outcome == "pass" or .outcome == "conditional"))] | length
' "${state_file}")"

if [ "${final_gate}" -eq 0 ]; then
  echo "Cannot archive: no passing gate record for final review" >&2
  exit 3
fi

# --- archive ---

"${script_dir}/update-state.sh" "${name}" \
  ".archived_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\" | .step_status = \"completed\""

# --- clear focus if archiving the focused unit ---

if [ -f ".work/.focused" ]; then
  focused_name="$(cat ".work/.focused")"
  if [ "$focused_name" = "$name" ]; then
    rm -f ".work/.focused"
  fi
fi

# --- regenerate summary one final time ---

"${script_dir}/regenerate-summary.sh" "${name}"

echo "Archived: ${name}"
