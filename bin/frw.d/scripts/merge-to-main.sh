#!/bin/sh
# merge-to-main.sh — Merge archived row branch to main
#
# Usage: frw merge-to-main <name>
#   name — row name
#
# Verifies the row is archived, then merges with --no-ff.
# Does NOT push (user decides when to push).
#
# Return codes:
#   0 — success
#   1 — usage error
#   2 — state.json not found
#   3 — row not archived
#   4 — merge failed

frw_merge_to_main() {
  set -eu

  if [ "$#" -lt 1 ]; then
    echo "Usage: frw merge-to-main <name>" >&2
    return 1
  fi

  name="$1"
  branch_name="work/${name}"

  work_dir=".furrow/rows/${name}"
  state_file="${work_dir}/state.json"

  if [ ! -f "${state_file}" ]; then
    echo "State file not found: ${state_file}" >&2
    return 2
  fi

  # --- verify archived ---

  archived="$(jq -r '.archived_at // "null"' "${state_file}")"
  if [ "${archived}" = "null" ]; then
    echo "Cannot merge: row '${name}' is not archived. Complete the review step and archive first." >&2
    return 3
  fi

  # --- verify branch exists ---

  if ! git rev-parse --verify "${branch_name}" > /dev/null 2>&1; then
    echo "Branch '${branch_name}' does not exist." >&2
    return 4
  fi

  # --- extract deliverables list ---

  deliverables="$(jq -r '.deliverables | keys | join(", ")' "${state_file}" 2>/dev/null)" || deliverables="${name}"

  # --- merge ---

  git checkout main

  merge_msg="$(printf "merge: complete %s\n\nDeliverables: %s\nGate: review pass" "${name}" "${deliverables}")"

  if ! git merge --no-ff "${branch_name}" -m "${merge_msg}"; then
    echo "Merge failed. Resolve conflicts and commit manually." >&2
    return 4
  fi

  echo "Merged ${branch_name} to main (--no-ff). Push when ready."
}
