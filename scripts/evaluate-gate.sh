#!/bin/sh
# Called by the eval runner (scripts/run-eval.sh), NOT by step-transition.sh
# directly. Step-transition accepts explicit verdicts from the human or
# evaluator; this script applies gate_policy to an evaluator's raw verdict
# to produce the final gate decision.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -lt 3 ]; then
  echo "Usage: evaluate-gate.sh <name> <boundary> <evaluator_verdict>" >&2
  exit 1
fi

name="$1"
boundary="$2"
evaluator_verdict="$3"

# Read gate_policy from definition.yaml, default to "supervised"
definition_file="${HARNESS_ROOT}/.work/${name}/definition.yaml"
if [ -f "$definition_file" ]; then
  gate_policy="$(yq -r '.gate_policy // "supervised"' "$definition_file")"
else
  gate_policy="supervised"
fi

# Parse boundary into from_step and to_step
from_step=$(echo "$boundary" | sed 's/->.*//')
to_step=$(echo "$boundary" | sed 's/.*->//')

# Validate and uppercase the evaluator verdict
verdict_upper="$(echo "$evaluator_verdict" | tr '[:lower:]' '[:upper:]')"
case "$verdict_upper" in
  PASS|FAIL|CONDITIONAL) ;;
  *)
    echo "Invalid evaluator verdict: '${evaluator_verdict}'. Must be pass, fail, or conditional." >&2
    echo "WAIT_FOR_HUMAN"
    exit 0
    ;;
esac

case "$gate_policy" in
  supervised)
    echo "WAIT_FOR_HUMAN"
    ;;
  delegated)
    if [ "$from_step" = "implement" ] && [ "$to_step" = "review" ]; then
      echo "WAIT_FOR_HUMAN"
    elif [ "$from_step" = "review" ] && [ "$to_step" = "archive" ]; then
      echo "WAIT_FOR_HUMAN"
    else
      echo "$verdict_upper"
    fi
    ;;
  autonomous)
    echo "$verdict_upper"
    ;;
  *)
    echo "WAIT_FOR_HUMAN"
    ;;
esac
