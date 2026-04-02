#!/bin/sh
# ownership-warn.sh — Warn on file_ownership violations during implement step
#
# Hook: PreToolUse (matcher: Write|Edit)
# Receives JSON on stdin with tool_name and tool_input.
# Advisory only — always exits 0.

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

work_dir="$(find_active_work_unit)"

if [ -z "$work_dir" ]; then
  exit 0
fi

state_file="$work_dir/state.json"
current_step="$(jq -r '.step // ""' "$state_file" 2>/dev/null)" || current_step=""

if [ "$current_step" != "implement" ]; then
  exit 0
fi

target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" || target_path=""

if [ -z "$target_path" ]; then
  exit 0
fi

plan_file="$work_dir/plan.json"

if [ ! -f "$plan_file" ]; then
  exit 0
fi

# Get all file_ownership globs from wave assignments
ownership_globs="$(jq -r '
  [.waves[].assignments | to_entries[].value.file_ownership // [] | .[]] | unique | .[]
' "$plan_file" 2>/dev/null)" || ownership_globs=""

if [ -z "$ownership_globs" ]; then
  exit 0
fi

_matched=0
_IFS_SAVE="$IFS"
IFS="$(printf '\n')"
# shellcheck disable=SC2254
for _glob in $ownership_globs; do
  case "$target_path" in
    $_glob) _matched=1; break ;;
  esac
done
IFS="$_IFS_SAVE"

if [ "$_matched" -eq 0 ]; then
  log_warning "File write outside file_ownership: $target_path (assigned globs: $(echo "$ownership_globs" | tr '\n' ', ' | sed 's/,$//'))"
fi

exit 0
