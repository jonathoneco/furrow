#!/bin/sh
# timestamp-update.sh — Update updated_at after work dir writes
#
# Hook: PostToolUse (matcher: Write|Edit)
# Receives JSON on stdin with tool_name and tool_input.
# Always exits 0.

set -eu

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$HOOK_DIR/.." && pwd)"

COMMON_LIB="$HARNESS_ROOT/hooks/lib/common.sh"

if [ ! -f "$COMMON_LIB" ]; then
  exit 0
fi

# shellcheck source=lib/common.sh
. "$COMMON_LIB"

input="$(cat)"

target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" || target_path=""

# Only act on writes to .work/ directories
case "$target_path" in
  .work/*) ;;
  *) exit 0 ;;
esac

work_dir="$(find_active_work_unit)"

if [ -z "$work_dir" ]; then
  exit 0
fi

unit_name="$(work_unit_name "$work_dir")"
update_script="$HARNESS_ROOT/scripts/update-state.sh"

if [ -x "$update_script" ] && [ -n "$unit_name" ]; then
  "$update_script" "$unit_name" ".updated_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" 2>/dev/null || true
fi

exit 0
