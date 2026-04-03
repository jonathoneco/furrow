#!/bin/sh
# select-gate.sh — Return the gate YAML path for the current step
#
# Usage: select-gate.sh <name>
#   Outputs absolute path to evals/gates/{step}.yaml on stdout.
#
# Exit codes:
#   0 — success (path on stdout)
#   1 — usage error
#   2 — state.json not found
#   3 — gate file not found

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FURROW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -lt 1 ]; then
  echo "Usage: select-gate.sh <name>" >&2
  exit 1
fi

name="$1"
state_file="${FURROW_ROOT}/.furrow/rows/${name}/state.json"

if [ ! -f "$state_file" ]; then
  echo "Error: state.json not found at ${state_file}" >&2
  exit 2
fi

step="$(jq -r '.step // ""' "$state_file")"

if [ -z "$step" ]; then
  echo "Error: step is missing from ${state_file}" >&2
  exit 2
fi

# Gate YAML path follows a simple 1:1 convention: step name = file name
gate_path="${FURROW_ROOT}/evals/gates/${step}.yaml"

if [ ! -f "$gate_path" ]; then
  echo "Error: gate file not found at ${gate_path}" >&2
  exit 3
fi

echo "$gate_path"
