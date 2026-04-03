#!/bin/sh
# select-dimensions.sh — Return the correct eval dimension file path by mode and step
#
# Usage: frw select-dimensions <name>
#   Outputs absolute path to evals/dimensions/{file}.yaml on stdout.
#
# Routing logic (from references/research-mode.md):
#   research mode + implement step → research-implement.yaml
#   research mode + spec step     → research-spec.yaml
#   all other combinations        → {step}.yaml
#
# Return codes:
#   0 — success (path on stdout)
#   2 — state.json not found
#   3 — dimension file not found

frw_select_dimensions() {
  set -eu

  if [ $# -lt 1 ]; then
    echo "Usage: frw select-dimensions <name>" >&2
    return 1
  fi

  name="$1"
  state_file="${FURROW_ROOT}/.furrow/rows/${name}/state.json"

  if [ ! -f "$state_file" ]; then
    echo "Error: state.json not found at ${state_file}" >&2
    return 2
  fi

  mode="$(jq -r '.mode // "code"' "$state_file")"
  step="$(jq -r '.step // ""' "$state_file")"

  if [ -z "$step" ]; then
    echo "Error: step is missing from ${state_file}" >&2
    return 2
  fi

  if [ "$mode" = "research" ] && [ "$step" = "implement" ]; then
    file="research-implement.yaml"
  elif [ "$mode" = "research" ] && [ "$step" = "spec" ]; then
    file="research-spec.yaml"
  elif [ "$mode" = "research" ] && [ "$step" = "research" ]; then
    # Explicit routing: research mode + research step uses research.yaml
    file="research.yaml"
  else
    # Standard routing: step name maps directly to dimension file
    file="${step}.yaml"
  fi

  dim_path="${FURROW_ROOT}/evals/dimensions/${file}"

  if [ ! -f "$dim_path" ]; then
    echo "Error: dimension file not found at ${dim_path}" >&2
    return 3
  fi

  echo "$dim_path"
}
