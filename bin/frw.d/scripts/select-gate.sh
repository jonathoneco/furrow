#!/bin/sh
# select-gate.sh — Return the gate YAML path for the current step
#
# Usage: frw select-gate <name>
#   Outputs absolute path to evals/gates/{step}.yaml on stdout.
#
# Return codes:
#   0 — success (path on stdout)
#   1 — usage error
#   2 — state.json not found
#   3 — gate file not found

frw_select_gate() {
  set -eu

  if [ $# -lt 1 ]; then
    echo "Usage: frw select-gate <name>" >&2
    return 1
  fi

  name="$1"
  state_file="${PROJECT_ROOT}/.furrow/rows/${name}/state.json"

  if [ ! -f "$state_file" ]; then
    echo "Error: state.json not found at ${state_file}" >&2
    return 2
  fi

  step="$(jq -r '.step // ""' "$state_file")"

  if [ -z "$step" ]; then
    echo "Error: step is missing from ${state_file}" >&2
    return 2
  fi

  # Gate YAML path follows a simple 1:1 convention: step name = file name
  gate_path="${FURROW_ROOT}/evals/gates/${step}.yaml"

  if [ ! -f "$gate_path" ]; then
    echo "Error: gate file not found at ${gate_path}" >&2
    return 3
  fi

  echo "$gate_path"
}
