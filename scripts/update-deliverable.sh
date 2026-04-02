#!/bin/sh
# update-deliverable.sh — Deliverable status tracking and corrections management
#
#
# Usage:
#   update-deliverable.sh <name> <deliverable> <status> [--assigned-to <specialist>]
#   update-deliverable.sh <name> <deliverable> --increment-corrections
#   update-deliverable.sh <name> --populate
#
# Modes:
#   Status update:   Set deliverable status (not_started|in_progress|completed|blocked)
#   Corrections:     Increment the corrections counter for a deliverable
#   Populate:        Initialize deliverables map from definition.yaml (at ideate->research gate)
#
# Exit codes:
#   0 — success
#   1 — usage/argument error
#   2 — state.json or definition.yaml not found
#   3 — validation error

set -eu

# --- argument validation ---

if [ "$#" -lt 2 ]; then
  echo "Usage: update-deliverable.sh <name> <deliverable> <status> [--assigned-to <specialist>]" >&2
  echo "       update-deliverable.sh <name> <deliverable> --increment-corrections" >&2
  echo "       update-deliverable.sh <name> --populate" >&2
  exit 1
fi

name="$1"
shift

# --- locate state ---

work_dir=".work/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"

# --- populate mode ---

if [ "$1" = "--populate" ]; then
  definition_file="${work_dir}/definition.yaml"

  if [ ! -f "${definition_file}" ]; then
    echo "Definition file not found: ${definition_file}" >&2
    exit 2
  fi

  # Extract deliverables from definition.yaml using yq or a YAML-to-JSON approach
  # We use a portable approach: parse YAML deliverables with sed/awk
  # But since the spec assumes jq is available, we'll rely on yq if available,
  # or fall back to a simpler parsing approach

  # Build deliverables map from definition.yaml
  # Each deliverable gets: status: "not_started", assigned_to: null, wave: 0, corrections: 0
  # If specialist is specified in definition.yaml, assigned_to gets that value

  # Try yq first, fall back to a basic parser
  if command -v yq > /dev/null 2>&1; then
    deliverables_json="$(yq -o=json '.deliverables' "${definition_file}" 2>/dev/null)" || {
      echo "Failed to parse definition.yaml deliverables." >&2
      exit 3
    }
  else
    echo "yq is required to parse definition.yaml. Install with: mise install yq" >&2
    exit 1
  fi

  # Build the deliverables map for state.json
  deliv_map="$(echo "${deliverables_json}" | jq '
    [.[] | {
      key: .name,
      value: {
        status: "not_started",
        assigned_to: (.specialist // null),
        wave: 0,
        corrections: 0
      }
    }] | from_entries
  ')"

  "${script_dir}/update-state.sh" "${name}" \
    ".deliverables = ${deliv_map}"

  echo "Deliverables populated from definition.yaml"
  exit 0
fi

# --- deliverable name ---

deliverable="$1"
shift

# --- validate deliverable exists ---

deliv_exists="$(jq -r --arg d "${deliverable}" '.deliverables | has($d)' "${state_file}")"

if [ "${deliv_exists}" != "true" ]; then
  echo "Unknown deliverable: '${deliverable}'" >&2
  exit 3
fi

# --- increment corrections mode ---

if [ "$#" -ge 1 ] && [ "$1" = "--increment-corrections" ]; then
  "${script_dir}/update-state.sh" "${name}" \
    ".deliverables.\"${deliverable}\".corrections += 1"

  echo "Corrections incremented for deliverable '${deliverable}'"
  exit 0
fi

# --- status update mode ---

if [ "$#" -lt 1 ]; then
  echo "Usage: update-deliverable.sh <name> <deliverable> <status> [--assigned-to <specialist>]" >&2
  exit 1
fi

status="$1"
shift

# Validate status enum
case "${status}" in
  not_started|in_progress|completed|blocked) ;;
  *)
    echo "Invalid status: '${status}'. Must be 'not_started', 'in_progress', 'completed', or 'blocked'." >&2
    exit 3
    ;;
esac

# Check for optional --assigned-to flag
assigned_to=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --assigned-to)
      if [ "$#" -lt 2 ]; then
        echo "--assigned-to requires a specialist type argument" >&2
        exit 1
      fi
      assigned_to="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Build jq expression
if [ -n "${assigned_to}" ]; then
  "${script_dir}/update-state.sh" "${name}" \
    ".deliverables.\"${deliverable}\".status = \"${status}\" | .deliverables.\"${deliverable}\".assigned_to = \"${assigned_to}\""
else
  "${script_dir}/update-state.sh" "${name}" \
    ".deliverables.\"${deliverable}\".status = \"${status}\""
fi

echo "Deliverable '${deliverable}' status updated to '${status}'"
