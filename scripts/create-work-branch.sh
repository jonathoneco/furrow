#!/bin/sh
# create-work-branch.sh — Create and checkout work unit branch
#
# Usage: create-work-branch.sh <name>
#   name — work unit name (kebab-case)
#
# Creates branch work/{name} from current HEAD and switches to it.
# If branch already exists (e.g., correction cycle), checks it out.
# Records branch name in state.json.
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — state.json not found

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: create-work-branch.sh <name>" >&2
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

# --- detect if already on a work branch ---

current_branch="$(git branch --show-current 2>/dev/null || true)"

if [ -n "${current_branch}" ] && echo "${current_branch}" | grep -q '^work/'; then
  # Already on a work/* branch (e.g., inside a worktree) — use it
  branch_name="${current_branch}"
  echo "Already on work branch: ${branch_name}"
elif git rev-parse --verify "${branch_name}" > /dev/null 2>&1; then
  # Branch exists — check it out
  git checkout "${branch_name}"
  echo "Checked out existing branch: ${branch_name}"
else
  # Create new branch from HEAD
  git checkout -b "${branch_name}"
  echo "Created and checked out branch: ${branch_name}"
fi

# --- record branch in state.json ---

script_dir="$(cd "$(dirname "$0")" && pwd)"
"${script_dir}/update-state.sh" "${name}" ".branch = \"${branch_name}\""

echo "Branch recorded in state.json: ${branch_name}"
