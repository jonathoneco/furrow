#!/bin/sh
# state-guard.sh — Block direct state.json writes
#
# Hook: PreToolUse (matcher: Write|Edit)
# Receives JSON on stdin with tool_name and tool_input.
# Exit 2 to block if target is state.json; exit 0 otherwise.

set -eu

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
FURROW_ROOT="$(cd "$HOOK_DIR/.." && pwd)"

COMMON_LIB="$FURROW_ROOT/hooks/lib/common.sh"

if [ ! -f "$COMMON_LIB" ]; then
  exit 0
fi

# shellcheck source=lib/common.sh
. "$COMMON_LIB"

input="$(cat)"

target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" || target_path=""

case "$target_path" in
  */state.json|state.json)
    log_error "state.json is Furrow-exclusive — use scripts/update-state.sh"
    exit 2
    ;;
esac

exit 0
