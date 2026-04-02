#!/bin/sh
# gate-check.sh — Verify gate record before step advance
#
# Hook: PreToolUse (matcher: Bash)
# Receives JSON on stdin with tool_name and tool_input.
# Exit 2 to block if advancing without a passing gate; exit 0 otherwise.

set -eu

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$HOOK_DIR/.." && pwd)"

COMMON_LIB="$HARNESS_ROOT/hooks/lib/common.sh"
VALIDATE_LIB="$HARNESS_ROOT/hooks/lib/validate.sh"

if [ ! -f "$COMMON_LIB" ] || [ ! -f "$VALIDATE_LIB" ]; then
  exit 0
fi

# shellcheck source=lib/common.sh
. "$COMMON_LIB"
# shellcheck source=lib/validate.sh
. "$VALIDATE_LIB"

input="$(cat)"

command_str="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)" || command_str=""

# Only care about advance-step invocations
case "$command_str" in
  *advance-step*) ;;
  *) exit 0 ;;
esac

work_dir="$(find_active_work_unit)"

if [ -z "$work_dir" ]; then
  exit 0
fi

state_file="$work_dir/state.json"

if [ ! -f "$state_file" ]; then
  exit 0
fi

if ! validate_step_boundary "$state_file" 2>/dev/null; then
  current="$(jq -r '.step' "$state_file" 2>/dev/null)" || current="unknown"
  next="$(jq -r --arg s "$current" '
    .steps_sequence as $seq |
    ($seq | to_entries[] | select(.value == $s) | .key) as $idx |
    if $idx + 1 < ($seq | length) then $seq[$idx + 1] else "end" end
  ' "$state_file" 2>/dev/null)" || next="unknown"
  log_error "Gate required: ${current}->${next}. No passing gate record found."
  exit 2
fi

exit 0
