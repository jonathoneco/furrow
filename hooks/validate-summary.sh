#!/bin/sh
# validate-summary.sh — Validate summary.md at step boundaries
#
# Stop hook that checks summary.md has all required sections and
# agent-written sections have minimum content.
#
# Skips validation for auto-advanced steps.
#
# Exit codes:
#   0 — valid (or no active work unit, or auto-advanced)
#   1 — validation failure

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

state_file="${work_dir}/state.json"
summary_file="${work_dir}/summary.md"

# --- skip if no summary exists yet ---

if [ ! -f "${summary_file}" ]; then
  exit 0
fi

# --- skip if last gate was auto-advance ---

last_decided="$(jq -r '.gates | last | .decided_by // ""' "${state_file}" 2>/dev/null)" || last_decided=""
if [ "${last_decided}" = "auto-advance" ]; then
  exit 0
fi

# --- check required sections ---

errors=""

for section in "Task" "Current State" "Artifact Paths" "Settled Decisions" "Key Findings" "Open Questions" "Recommendations"; do
  if ! grep -q "^## ${section}" "${summary_file}"; then
    errors="${errors}Missing section: ${section}\n"
  fi
done

# --- check agent-written sections have >= 2 non-empty lines ---

for section in "Key Findings" "Open Questions" "Recommendations"; do
  content="$(awk -v sec="${section}" '
    $0 ~ "^## " sec { found=1; next }
    /^## / { if(found) exit }
    found && /[^ ]/ { count++ }
    END { print count+0 }
  ' "${summary_file}")"

  if [ "${content}" -lt 2 ]; then
    errors="${errors}Section '${section}' needs at least 2 non-empty lines (has ${content}).\n"
  fi
done

# --- report ---

if [ -n "${errors}" ]; then
  printf "summary.md validation failed:\n%b" "${errors}" >&2
  exit 1
fi

exit 0
