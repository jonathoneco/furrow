#!/bin/sh
# verdict-guard.sh — Block direct writes to gate-verdicts/
#
# Hook: PreToolUse (matcher: Write|Edit)
# Verdicts must be written by the evaluator subagent via shell,
# not directly by the in-context agent via Write/Edit tools.
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
target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" || target_path=""

case "$target_path" in
  */gate-verdicts/*|gate-verdicts/*)
    log_error "gate-verdicts/ is write-protected — verdicts written by evaluator subagent only"
    exit 2
    ;;
esac

exit 0
