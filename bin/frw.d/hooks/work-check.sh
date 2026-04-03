# work-check.sh — Verify work state consistency at session end
#
# Hook: Stop (matcher: empty)
# Non-blocking — informational only. Always returns 0.

hook_work_check() {
  # Collect all active rows
  active_units=""
  for _state_file in .furrow/rows/*/state.json; do
    [ -f "$_state_file" ] || continue
    _archived="$(jq -r '.archived_at // "null"' "$_state_file" 2>/dev/null)" || continue
    if [ "$_archived" = "null" ]; then
      active_units="${active_units} $(dirname "$_state_file")"
    fi
  done

  if [ -z "$active_units" ]; then
    return 0
  fi

  # Source validate.sh once before the loop
  if [ -f "$FURROW_ROOT/bin/frw.d/lib/validate.sh" ]; then
    # shellcheck source=../lib/validate.sh
    . "$FURROW_ROOT/bin/frw.d/lib/validate.sh"
  fi

  # Source update-state module for direct function call (avoids recursive frw invocation)
  . "$FURROW_ROOT/bin/frw.d/scripts/update-state.sh"

  for work_dir in $active_units; do
    state_file="$work_dir/state.json"
    summary_file="$work_dir/summary.md"
    unit_name="$(row_name "$work_dir")"

    # Validate state.json integrity
    if [ -f "$FURROW_ROOT/bin/frw.d/lib/validate.sh" ]; then
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
        log_warning "summary.md missing required sections for ${unit_name}:${_missing}"
      fi

      # Check agent-written sections have minimum content (2 lines)
      for _agent_section in "Key Findings" "Open Questions" "Recommendations"; do
        _content="$(awk "/^## ${_agent_section}/{found=1; next} /^## /{if(found) exit} found{print}" "$summary_file" 2>/dev/null | sed '/^$/d')"
        _line_count="$(echo "$_content" | grep -c '.' 2>/dev/null)" || _line_count="0"

        if [ -n "$_content" ] && [ "$_line_count" -lt 2 ]; then
          log_warning "summary.md section '${_agent_section}' has fewer than 2 lines of content for ${unit_name}"
        fi
      done
    fi

    # Update timestamp
    if [ -n "$unit_name" ]; then
      frw_update_state "$unit_name" ".updated_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" 2>/dev/null || true
    fi
  done

  return 0
}
