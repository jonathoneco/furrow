#!/bin/sh
# regenerate-summary.sh — Regenerate summary.md preserving agent-written sections
#
#
# Usage: regenerate-summary.sh <name>
#   name — work unit name (kebab-case)
#
# Generates auto-generated skeleton sections from state.json and definition.yaml.
# Preserves agent-written sections (Key Findings, Open Questions, Recommendations)
# if they already exist; inserts placeholders otherwise.
#
# Triggered at every step boundary (after gate record, before step advance).
#
# Exit codes:
#   0 — success
#   1 — usage/argument error
#   2 — state.json not found

set -eu

# --- argument validation ---

if [ "$#" -lt 1 ]; then
  echo "Usage: regenerate-summary.sh <name>" >&2
  exit 1
fi

name="$1"

# --- locate files ---

work_dir=".work/${name}"
state_file="${work_dir}/state.json"
summary_file="${work_dir}/summary.md"
definition_file="${work_dir}/definition.yaml"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

# --- read state ---

title="$(jq -r '.title // .name' "${state_file}")"
step="$(jq -r '.step' "${state_file}")"
step_status="$(jq -r '.step_status' "${state_file}")"
mode="$(jq -r '.mode' "${state_file}")"

# Deliverable counts
total_deliverables="$(jq -r '.deliverables | length' "${state_file}")"
completed_deliverables="$(jq -r '[.deliverables | to_entries[] | select(.value.status == "completed")] | length' "${state_file}")"

# --- read objective from definition.yaml if available ---

objective=""
if [ -f "${definition_file}" ]; then
  if command -v yq > /dev/null 2>&1; then
    objective="$(yq -r '.objective // ""' "${definition_file}" 2>/dev/null)" || objective=""
  fi
fi

if [ -z "${objective}" ]; then
  objective="$(jq -r '.description' "${state_file}")"
fi

# --- extract settled decisions from gates ---

settled_decisions="$(jq -r '
  if (.gates | length) == 0 then "- No gates recorded yet"
  else
    [.gates[] | "- **\(.boundary)**: \(.outcome) — \(.evidence)"] | join("\n")
  end
' "${state_file}")"

# --- context budget ---

context_budget="Not measured"
script_dir="$(cd "$(dirname "$0")" && pwd)"
measure_script="${script_dir}/measure-context.sh"
if [ -x "${measure_script}" ]; then
  context_budget="$(${measure_script} 2>/dev/null)" || context_budget="Measurement unavailable"
fi

# --- artifact paths ---

artifacts="- definition.yaml: ${work_dir}/definition.yaml"
artifacts="${artifacts}
- state.json: ${work_dir}/state.json"

if [ -f "${work_dir}/plan.json" ]; then
  artifacts="${artifacts}
- plan.json: ${work_dir}/plan.json"
fi
if [ -f "${work_dir}/research.md" ]; then
  artifacts="${artifacts}
- research.md: ${work_dir}/research.md"
fi
if [ -d "${work_dir}/research" ]; then
  artifacts="${artifacts}
- research/: ${work_dir}/research/"
fi
if [ -f "${work_dir}/spec.md" ]; then
  artifacts="${artifacts}
- spec.md: ${work_dir}/spec.md"
fi
if [ -d "${work_dir}/specs" ]; then
  artifacts="${artifacts}
- specs/: ${work_dir}/specs/"
fi
if [ -f "${work_dir}/team-plan.md" ]; then
  artifacts="${artifacts}
- team-plan.md: ${work_dir}/team-plan.md"
fi

# --- preserve agent-written sections ---

key_findings=""
open_questions=""
recommendations=""

if [ -f "${summary_file}" ]; then
  # Extract agent-written sections by finding content between headers
  # Uses awk to capture content between specific ## headers
  key_findings="$(awk '/^## Key Findings/{found=1; next} /^## /{if(found) exit} found{print}' "${summary_file}")"
  open_questions="$(awk '/^## Open Questions/{found=1; next} /^## /{if(found) exit} found{print}' "${summary_file}")"
  recommendations="$(awk '/^## Recommendations/{found=1; next} /^## /{if(found) exit} found{print}' "${summary_file}")"
fi

# Trim whitespace and check minimum length (2 lines)
trim_section() {
  echo "$1" | sed '/^$/d' | sed 's/^[[:space:]]*//'
}

key_findings="$(trim_section "${key_findings}")"
open_questions="$(trim_section "${open_questions}")"
recommendations="$(trim_section "${recommendations}")"

# Use placeholder if section is missing or too short
kf_lines="$(echo "${key_findings}" | wc -l)"
oq_lines="$(echo "${open_questions}" | wc -l)"
rec_lines="$(echo "${recommendations}" | wc -l)"

if [ -z "${key_findings}" ] || [ "${kf_lines}" -lt 2 ]; then
  key_findings="Key Findings: To be written by step agent"
fi

if [ -z "${open_questions}" ] || [ "${oq_lines}" -lt 2 ]; then
  open_questions="Open Questions: To be written by step agent"
fi

if [ -z "${recommendations}" ] || [ "${rec_lines}" -lt 2 ]; then
  recommendations="Recommendations: To be written by step agent"
fi

# --- generate summary.md ---

tmp_file="${summary_file}.tmp.$$"

cat > "${tmp_file}" << ENDMD
# ${title} — Summary

## Task
${objective}

## Current State
Step: ${step} | Status: ${step_status}
Deliverables: ${completed_deliverables}/${total_deliverables}
Mode: ${mode}

## Artifact Paths
${artifacts}

## Settled Decisions
${settled_decisions}

## Context Budget
${context_budget}

## Key Findings
${key_findings}

## Open Questions
${open_questions}

## Recommendations
${recommendations}
ENDMD

# --- atomic write ---

mv "${tmp_file}" "${summary_file}"

# --- validation: check all required sections present ---

missing=""
for section in "Task" "Current State" "Artifact Paths" "Settled Decisions" "Context Budget" "Key Findings" "Open Questions" "Recommendations"; do
  if ! grep -q "^## ${section}" "${summary_file}"; then
    missing="${missing} ${section}"
  fi
done

if [ -n "${missing}" ]; then
  echo "Warning: summary.md missing sections:${missing}" >&2
fi

echo "Summary regenerated: ${summary_file}"
