#!/bin/sh
# merge-to-main.sh — Merge archived work unit branch to main
#
# Usage: merge-to-main.sh <name>
#   name — work unit name
#
# Verifies the work unit is archived, then merges with --no-ff.
# Does NOT push (user decides when to push).
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — state.json not found
#   3 — work unit not archived
#   4 — merge failed

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: merge-to-main.sh <name>" >&2
  exit 1
fi

name="$1"
branch_name="work/${name}"

work_dir=".work/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

# --- verify archived ---

archived="$(jq -r '.archived_at // "null"' "${state_file}")"
if [ "${archived}" = "null" ]; then
  echo "Cannot merge: work unit '${name}' is not archived. Complete the review step and archive first." >&2
  exit 3
fi

# --- verify branch exists ---

if ! git rev-parse --verify "${branch_name}" > /dev/null 2>&1; then
  echo "Branch '${branch_name}' does not exist." >&2
  exit 4
fi

# --- extract deliverables list ---

deliverables="$(jq -r '.deliverables | keys | join(", ")' "${state_file}" 2>/dev/null)" || deliverables="${name}"

# --- merge ---

git checkout main

merge_msg="$(printf "merge: complete %s\n\nDeliverables: %s\nGate: review pass" "${name}" "${deliverables}")"

if ! git merge --no-ff "${branch_name}" -m "${merge_msg}"; then
  echo "Merge failed. Resolve conflicts and commit manually." >&2
  exit 4
fi

echo "Merged ${branch_name} to main (--no-ff). Push when ready."
