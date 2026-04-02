#!/bin/sh
# auto-advance.sh — Auto-advance for trivially resolved steps
#
#
# Usage: auto-advance.sh <name> <evidence>
#   name     — work unit name (kebab-case)
#   evidence — explanation of why the step resolved trivially
#
# Rules:
#   - Creates gate record with decided_by: "auto-advance"
#   - MUST NOT apply to implement or review steps
#   - Disabled when gate_policy is "supervised"
#   - Enabled for "delegated" and "autonomous" on: ideate, research, plan, spec, decompose
#   - The auto-advance decision is signaled by the step agent, validated by the harness
#
# Exit codes:
#   0 — success
#   1 — usage/argument error
#   2 — state.json not found
#   3 — auto-advance not allowed (blocked step or policy)

set -eu

# --- argument validation ---

if [ "$#" -lt 2 ]; then
  echo "Usage: auto-advance.sh <name> <evidence>" >&2
  exit 1
fi

name="$1"
evidence="$2"

# --- locate state ---

work_dir=".work/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"

# --- read current state ---

current_step="$(jq -r '.step' "${state_file}")"

# --- check blocked steps ---

case "${current_step}" in
  implement|review)
    echo "Auto-advance not allowed for step '${current_step}'. Implement and review always require a gate." >&2
    exit 3
    ;;
esac

# --- check gate policy ---

definition_file="${work_dir}/definition.yaml"
gate_policy="delegated"  # default if definition.yaml not present

if [ -f "${definition_file}" ]; then
  if command -v yq > /dev/null 2>&1; then
    gate_policy="$(yq -r '.gate_policy // "delegated"' "${definition_file}" 2>/dev/null)" || gate_policy="delegated"
  fi
fi

if [ "${gate_policy}" = "supervised" ]; then
  echo "Auto-advance disabled: gate_policy is 'supervised' (all gates require human approval)." >&2
  exit 3
fi

# --- validate auto-advance is on an allowed step ---

case "${current_step}" in
  ideate|research|plan|spec|decompose) ;;
  *)
    echo "Auto-advance not allowed for step '${current_step}'." >&2
    exit 3
    ;;
esac

# --- find next step ---

next_step="$(jq -r --arg step "${current_step}" '
  .steps_sequence as $seq |
  ($seq | to_entries[] | select(.value == $step) | .key) as $idx |
  $seq[$idx + 1]
' "${state_file}")"

if [ -z "${next_step}" ] || [ "${next_step}" = "null" ]; then
  echo "Cannot auto-advance: no next step after '${current_step}'." >&2
  exit 3
fi

boundary="${current_step}->${next_step}"

# --- record gate with auto-advance ---

"${script_dir}/record-gate.sh" "${name}" "${boundary}" "pass" "auto-advance" "${evidence}"

# --- advance step ---

"${script_dir}/advance-step.sh" "${name}"

echo "Auto-advanced: ${boundary} (evidence: ${evidence})"
