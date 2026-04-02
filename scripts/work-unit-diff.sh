#!/bin/sh
# work-unit-diff.sh — Diff from base_commit for plan completion audit
#
# Usage: work-unit-diff.sh <name>
#   name — work unit name
#
# Reads base_commit from state.json and produces a diff summary.
# Used by the review step (Phase A) to audit plan completion.
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — state.json not found

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: work-unit-diff.sh <name>" >&2
  exit 1
fi

name="$1"

work_dir=".work/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

base_commit="$(jq -r '.base_commit' "${state_file}")"

if [ -z "${base_commit}" ] || [ "${base_commit}" = "null" ] || [ "${base_commit}" = "unknown" ]; then
  echo "No valid base_commit in state.json." >&2
  exit 2
fi

echo "=== Work Unit Diff: ${name} ==="
echo "Base commit: ${base_commit}"
echo "Current HEAD: $(git rev-parse HEAD)"
echo ""

git diff --stat "${base_commit}..HEAD"
