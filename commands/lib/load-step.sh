#!/bin/sh
# load-step.sh — Load the appropriate skill for the current step
#
# Usage: load-step.sh <name>
#   name — row name
#
# Outputs Read instructions for the current step's skill file.
# If the step was entered via conditional pass, appends conditions.
#
# Exit codes:
#   0 — success (instructions on stdout)
#   1 — usage error
#   2 — state.json not found
#   3 — skill file not found

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: load-step.sh <name>" >&2
  exit 1
fi

name="$1"

work_dir=".furrow/rows/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

step="$(jq -r '.step' "${state_file}")"

# --- locate skill file ---

script_dir="$(cd "$(dirname "$0")" && pwd)"
furrow_root="$(cd "${script_dir}/../.." && pwd)"
skill_file="${furrow_root}/skills/${step}.md"

if [ ! -f "${skill_file}" ]; then
  echo "Skill file not found: skills/${step}.md" >&2
  exit 3
fi

# --- emit Read instructions ---

echo "Read and follow skills/${step}.md"
echo "Read ${work_dir}/summary.md for context from previous steps."

# --- check for conditions from conditional pass ---

conditions="$(jq -r '
  .gates | last |
  if .outcome == "conditional" and .conditions != null then
    .conditions | join("\n- ")
  else
    ""
  end
' "${state_file}" 2>/dev/null)" || conditions=""

if [ -n "${conditions}" ]; then
  echo ""
  echo "CONDITIONAL PASS: The following conditions must be addressed this step:"
  echo "- ${conditions}"
fi
