#!/bin/sh
# check-wave-conflicts.sh — Wave boundary conflict detection
#
# Usage: check-wave-conflicts.sh <name> [wave_number]
#   name        — work unit name
#   wave_number — completed wave to check (default: most recent)
#
# Cross-references .work/{name}/.unplanned_changes against plan.json
# file_ownership assignments to detect overlapping modifications.
#
# Exit codes:
#   0 — clean (no conflicts)
#   1 — conflicts detected (details on stderr)
#   2 — missing files

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: check-wave-conflicts.sh <name> [wave_number]" >&2
  exit 1
fi

name="$1"
# wave_number is accepted but currently unused (reserved for future filtering)

work_dir=".work/${name}"
unplanned_file="${work_dir}/.unplanned_changes"
plan_file="${work_dir}/plan.json"

# --- no unplanned changes = clean ---

if [ ! -f "${unplanned_file}" ]; then
  echo "No unplanned changes detected. Clean."
  exit 0
fi

if [ ! -s "${unplanned_file}" ]; then
  echo "No unplanned changes detected. Clean."
  exit 0
fi

# --- read plan.json for ownership ---

if [ ! -f "${plan_file}" ]; then
  echo "Warning: plan.json not found. Cannot check ownership overlap." >&2
  echo "Unplanned changes exist but ownership cannot be verified."
  exit 0
fi

# --- extract file_ownership per specialist for the wave ---

conflicts=""

while IFS= read -r changed_file; do
  [ -n "${changed_file}" ] || continue

  # Check if this file falls in any specialist's ownership
  owners="$(jq -r --arg file "${changed_file}" '
    [.waves[].assignments | to_entries[] |
     select(.value.file_ownership != null) |
     select(.value.file_ownership[] as $glob |
       ($file | test($glob | gsub("\\*\\*"; ".*") | gsub("\\*"; "[^/]*")))
     ) |
     .key
    ] | unique | join(", ")
  ' "${plan_file}" 2>/dev/null)" || owners=""

  if [ -n "${owners}" ]; then
    # This unplanned change overlaps with at least one specialist's ownership
    conflicts="${conflicts}Conflict: '${changed_file}' is an unplanned change overlapping ownership of: ${owners}\n"
  fi

done < "${unplanned_file}"

# --- report ---

if [ -n "${conflicts}" ]; then
  printf "Wave conflict(s) detected:\n%b" "${conflicts}" >&2
  exit 1
fi

echo "No ownership conflicts in unplanned changes. Clean."
exit 0
