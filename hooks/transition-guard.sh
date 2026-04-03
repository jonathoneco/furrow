#!/bin/sh
# transition-guard.sh — Block direct calls to record-gate.sh and advance-step.sh
#
# Hook: PreToolUse (matcher: Bash)
# Agents must use step-transition.sh for all step transitions.
# Direct calls to internal scripts are blocked.
#
# Exit codes:
#   0 — allowed
#   2 — blocked

set -eu

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
FURROW_ROOT="$(cd "$HOOK_DIR/.." && pwd)"
COMMON_LIB="$FURROW_ROOT/hooks/lib/common.sh"

if [ ! -f "$COMMON_LIB" ]; then
  exit 0
fi

. "$COMMON_LIB"

input="$(cat)"
command_str="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)" || command_str=""

# Allow step-transition.sh (the orchestrator)
case "$command_str" in
  *step-transition*) exit 0 ;;
esac

# Block direct calls to internal transition scripts
case "$command_str" in
  *record-gate.sh*|*record-gate\ *)
    log_error "Direct record-gate.sh calls blocked — use step-transition.sh"
    exit 2
    ;;
  *advance-step.sh*|*advance-step\ *)
    log_error "Direct advance-step.sh calls blocked — use step-transition.sh"
    exit 2
    ;;
esac

exit 0
