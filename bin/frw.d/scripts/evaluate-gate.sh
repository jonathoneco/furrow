#!/bin/sh
# evaluate-gate.sh — Apply gate_policy to an evaluator's raw verdict
#
# Called by the in-context agent after subagent evaluation returns a verdict.
# The agent calls: frw evaluate-gate <name> <boundary> <evaluator_verdict>
# Then uses the output decision to call rws transition or present to human.
#
# Usage: frw evaluate-gate <name> <boundary> <evaluator_verdict>
#   Outputs gate decision on stdout: PASS, FAIL, CONDITIONAL, or WAIT_FOR_HUMAN
#
# Return codes:
#   0 — success (decision on stdout)
#   1 — invalid usage

frw_evaluate_gate() {
  set -eu

  if [ $# -lt 3 ]; then
    echo "Usage: frw evaluate-gate <name> <boundary> <evaluator_verdict>" >&2
    return 1
  fi

  name="$1"
  boundary="$2"
  evaluator_verdict="$3"

  # Read gate_policy from definition.yaml, default to "supervised"
  definition_file="${FURROW_ROOT}/.furrow/rows/${name}/definition.yaml"
  if [ -f "$definition_file" ] && command -v yq > /dev/null 2>&1; then
    gate_policy="$(yq -r '.gate_policy // "supervised"' "$definition_file")" || gate_policy="supervised"
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
      return 0
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
}
