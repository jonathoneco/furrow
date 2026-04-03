#!/bin/sh
# summary-regen.sh — Regenerate summary.md at step boundaries
#
# Hook: PostToolUse (matcher: Write|Edit)
# Receives JSON on stdin with tool_name and tool_input.
# Triggers summary regeneration when step_status changes to completed.
# Always exits 0.

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

# Only act on writes to .furrow/rows/ directories
case "$target_path" in
  .furrow/rows/*) ;;
  *) exit 0 ;;
esac

work_dir="$(extract_row_from_path "$target_path")"

if [ -z "$work_dir" ]; then
  work_dir="$(find_focused_row)"
fi

if [ -z "$work_dir" ]; then
  exit 0
fi

state_file="$work_dir/state.json"
step_status="$(jq -r '.step_status // ""' "$state_file" 2>/dev/null)" || step_status=""

if [ "$step_status" != "completed" ]; then
  exit 0
fi

unit_name="$(row_name "$work_dir")"
regen_script="$FURROW_ROOT/scripts/regenerate-summary.sh"

if [ -x "$regen_script" ] && [ -n "$unit_name" ]; then
  "$regen_script" "$unit_name" 2>/dev/null || log_warning "summary.md regeneration failed"
fi

exit 0
