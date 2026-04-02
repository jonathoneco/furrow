#!/bin/sh
# work-check.sh — Verify work state consistency at session end
#
# Hook: Stop (matcher: empty)
# Non-blocking — informational only. Always exits 0.

set -eu

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$HOOK_DIR/.." && pwd)"

COMMON_LIB="$HARNESS_ROOT/hooks/lib/common.sh"
VALIDATE_LIB="$HARNESS_ROOT/hooks/lib/validate.sh"

if [ ! -f "$COMMON_LIB" ]; then
  exit 0
fi

# shellcheck source=lib/common.sh
. "$COMMON_LIB"

work_dir="$(find_active_work_unit)"

if [ -z "$work_dir" ]; then
  exit 0
fi

state_file="$work_dir/state.json"
summary_file="$work_dir/summary.md"
unit_name="$(work_unit_name "$work_dir")"

# Validate state.json integrity
if [ -f "$VALIDATE_LIB" ]; then
  # shellcheck source=lib/validate.sh
  . "$VALIDATE_LIB"

  if ! validate_state_json "$state_file" 2>/dev/null; then
    log_warning "state.json validation failed for $unit_name"
  fi
fi

# Validate summary.md sections
if [ -f "$summary_file" ]; then
  _missing=""
  for _section in "Task" "Current State" "Artifact Paths" "Settled Decisions" "Key Findings" "Open Questions"; do
    if ! grep -q "^## ${_section}" "$summary_file" 2>/dev/null; then
      _missing="${_missing} ${_section}"
    fi
  done

  if [ -n "$_missing" ]; then
    log_warning "summary.md missing required sections:${_missing}"
  fi

  # Check agent-written sections have minimum content (2 lines)
  for _agent_section in "Key Findings" "Open Questions" "Recommendations"; do
    _content="$(awk "/^## ${_agent_section}/{found=1; next} /^## /{if(found) exit} found{print}" "$summary_file" 2>/dev/null | sed '/^$/d')"
    _line_count="$(echo "$_content" | grep -c '.' 2>/dev/null)" || _line_count="0"

    if [ -n "$_content" ] && [ "$_line_count" -lt 2 ]; then
      log_warning "summary.md section '${_agent_section}' has fewer than 2 lines of content"
    fi
  done
fi

# Update timestamp
update_script="$HARNESS_ROOT/scripts/update-state.sh"
if [ -x "$update_script" ] && [ -n "$unit_name" ]; then
  "$update_script" "$unit_name" ".updated_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" 2>/dev/null || true
fi

exit 0
