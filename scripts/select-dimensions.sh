#!/bin/sh
# select-dimensions.sh — Return the correct eval dimension file path by mode and step
#
# Usage: select-dimensions.sh <name>
#   Outputs absolute path to evals/dimensions/{file}.yaml on stdout.
#
# Routing logic (from references/research-mode.md):
#   research mode + implement step → research-implement.yaml
#   research mode + spec step     → research-spec.yaml
#   all other combinations        → {step}.yaml
#
# Exit codes:
#   0 — success (path on stdout)
#   2 — state.json not found
#   3 — dimension file not found
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -lt 1 ]; then
  echo "Usage: select-dimensions.sh <name>" >&2
  exit 1
fi

name="$1"
state_file="${HARNESS_ROOT}/.work/${name}/state.json"

if [ ! -f "$state_file" ]; then
  echo "Error: state.json not found at ${state_file}" >&2
  exit 2
fi

mode="$(jq -r '.mode // "code"' "$state_file")"
step="$(jq -r '.step' "$state_file")"

if [ "$mode" = "research" ] && [ "$step" = "implement" ]; then
  file="research-implement.yaml"
elif [ "$mode" = "research" ] && [ "$step" = "spec" ]; then
  file="research-spec.yaml"
else
  file="${step}.yaml"
fi

dim_path="${HARNESS_ROOT}/evals/dimensions/${file}"

if [ ! -f "$dim_path" ]; then
  echo "Error: dimension file not found at ${dim_path}" >&2
  exit 3
fi

echo "$dim_path"
