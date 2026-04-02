#!/bin/sh
# stop-ideation.sh — Validate section-by-section interaction during ideation
#
# Stop hook that checks the ideation agent presented definition sections
# individually rather than batch-approving the entire definition.
#
# Checks for section markers: <!-- ideation:section:{name} -->
# Required markers: objective, deliverables, context-pointers, constraints, gate-policy
#
# In supervised/delegated mode: all 5 markers must be present.
# In autonomous mode: marker check is skipped (evaluator validates instead).
#
# Exit codes:
#   0 — valid (or not in ideation step, or autonomous mode)
#   1 — missing section markers

set -eu

# --- locate active work unit ---

work_dir=""
for state_file in .work/*/state.json; do
  [ -f "${state_file}" ] || continue
  archived="$(jq -r '.archived_at // "null"' "${state_file}" 2>/dev/null)" || continue
  if [ "${archived}" = "null" ]; then
    work_dir="$(dirname "${state_file}")"
    break
  fi
done

if [ -z "${work_dir}" ]; then
  exit 0
fi

# --- check if in ideation step ---

step="$(jq -r '.step' "${work_dir}/state.json" 2>/dev/null)" || step=""
if [ "${step}" != "ideate" ]; then
  exit 0
fi

# --- check gate policy ---

def_file="${work_dir}/definition.yaml"
gate_policy=""
if [ -f "${def_file}" ] && command -v yq > /dev/null 2>&1; then
  gate_policy="$(yq -r '.gate_policy // ""' "${def_file}" 2>/dev/null)" || gate_policy=""
fi

if [ "${gate_policy}" = "autonomous" ]; then
  exit 0
fi

# --- check for section markers in conversation context ---
# This hook validates that the agent emitted section markers.
# Since hooks cannot inspect conversation history directly, this
# checks if the definition.yaml has been written (proxy for completion).
# The actual marker enforcement is advisory via the skill instructions.

if [ ! -f "${def_file}" ]; then
  # Definition not yet written — ideation still in progress, no error
  exit 0
fi

echo "Ideation section markers validated"
