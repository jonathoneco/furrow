#!/bin/sh
# record-gate.sh — Append a gate record to state.json gates array
#
#
# Usage: record-gate.sh <name> <boundary> <outcome> <decided_by> <evidence> [conditions_json]
#   name            — work unit name (kebab-case)
#   boundary        — format: "{from}->{to}" (e.g., "ideate->research")
#   outcome         — "pass" | "fail" | "conditional"
#   decided_by      — "manual" | "evaluated" | "prechecked"
#   evidence        — one-line summary of proof or path to gate file
#   conditions_json — JSON array of strings, required when outcome is "conditional"
#
# Gate records are append-only — existing entries are never modified.
#
# Exit codes:
#   0 — success
#   1 — usage/argument error
#   2 — state.json not found
#   3 — validation error (invalid boundary, outcome, decided_by, or conditions)

set -eu

# --- argument validation ---

if [ "$#" -lt 5 ]; then
  echo "Usage: record-gate.sh <name> <boundary> <outcome> <decided_by> <evidence> [conditions_json]" >&2
  exit 1
fi

name="$1"
boundary="$2"
outcome="$3"
decided_by="$4"
evidence="$5"
conditions_json="${6:-}"

# --- locate state ---

work_dir=".work/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

# --- validate boundary format ---

# Must be "{step}->{step}" with valid step names
valid_steps="ideate research plan spec decompose implement review"

from_step="$(echo "${boundary}" | sed -n 's/^\([a-z]*\)->.*/\1/p')"
to_step="$(echo "${boundary}" | sed -n 's/.*->\([a-z]*\)$/\1/p')"

if [ -z "${from_step}" ] || [ -z "${to_step}" ]; then
  echo "Invalid boundary format: '${boundary}'. Must be '{from}->{to}' (e.g., 'ideate->research')." >&2
  exit 3
fi

from_valid=false
to_valid=false
for s in ${valid_steps}; do
  if [ "${s}" = "${from_step}" ]; then from_valid=true; fi
  if [ "${s}" = "${to_step}" ]; then to_valid=true; fi
done

if [ "${from_valid}" = false ]; then
  echo "Invalid step in boundary: '${from_step}' is not a valid step name." >&2
  exit 3
fi

if [ "${to_valid}" = false ]; then
  echo "Invalid step in boundary: '${to_step}' is not a valid step name." >&2
  exit 3
fi

# --- validate outcome ---

case "${outcome}" in
  pass|fail|conditional) ;;
  *)
    echo "Invalid outcome: '${outcome}'. Must be 'pass', 'fail', or 'conditional'." >&2
    exit 3
    ;;
esac

# --- validate decided_by ---

case "${decided_by}" in
  manual|evaluated|prechecked) ;;
  *)
    echo "Invalid decided_by: '${decided_by}'. Must be 'manual', 'evaluated', or 'prechecked'." >&2
    exit 3
    ;;
esac

# --- validate conditions ---

if [ "${outcome}" = "conditional" ]; then
  if [ -z "${conditions_json}" ]; then
    echo "Conditional outcome requires conditions array" >&2
    exit 3
  fi
  # Validate it's a JSON array
  if ! echo "${conditions_json}" | jq -e 'type == "array"' > /dev/null 2>&1; then
    echo "Conditions must be a JSON array of strings." >&2
    exit 3
  fi
fi

if [ "${outcome}" != "conditional" ] && [ -n "${conditions_json}" ]; then
  echo "Conditions only valid for conditional outcome" >&2
  exit 3
fi

# --- build gate record ---

now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [ "${outcome}" = "conditional" ]; then
  gate_record="$(jq -n \
    --arg boundary "${boundary}" \
    --arg outcome "${outcome}" \
    --arg decided_by "${decided_by}" \
    --arg evidence "${evidence}" \
    --argjson conditions "${conditions_json}" \
    --arg timestamp "${now}" \
    '{
      boundary: $boundary,
      outcome: $outcome,
      decided_by: $decided_by,
      evidence: $evidence,
      conditions: $conditions,
      timestamp: $timestamp
    }'
  )"
else
  gate_record="$(jq -n \
    --arg boundary "${boundary}" \
    --arg outcome "${outcome}" \
    --arg decided_by "${decided_by}" \
    --arg evidence "${evidence}" \
    --arg timestamp "${now}" \
    '{
      boundary: $boundary,
      outcome: $outcome,
      decided_by: $decided_by,
      evidence: $evidence,
      timestamp: $timestamp
    }'
  )"
fi

# --- append gate record via update-state.sh ---

script_dir="$(cd "$(dirname "$0")" && pwd)"

"${script_dir}/update-state.sh" "${name}" \
  ".gates += [${gate_record}]"

echo "Gate recorded: ${boundary} (${outcome})"
