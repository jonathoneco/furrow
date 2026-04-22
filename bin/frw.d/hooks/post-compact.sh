# post-compact.sh — Re-inject context after compaction
#
# Hook: PostCompact (matcher: empty)
# Outputs critical context to stdout for re-injection.
# Return 0 on success, return 1 on state corruption.

# shellcheck source=../lib/common-minimal.sh
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"

hook_post_compact() {
  work_dir="$(find_focused_row)"

  if [ -z "$work_dir" ]; then
    echo "No focused row. Run /work to focus a row."
    return 0
  fi

  state_file="$work_dir/state.json"
  summary_file="$work_dir/summary.md"

  # Validate state integrity
  if [ -f "$FURROW_ROOT/bin/frw.d/lib/validate.sh" ]; then
    # shellcheck source=../lib/validate.sh
    . "$FURROW_ROOT/bin/frw.d/lib/validate.sh"

    if ! _val_errors="$(validate_state_json "$state_file" 2>&1)"; then
      log_error "STATE CORRUPTION detected after compaction. Validation errors: $_val_errors"
      return 1
    fi
  fi

  # Extract step context
  step="$(jq -r '.step // "unknown"' "$state_file" 2>/dev/null)" || step="unknown"
  status="$(jq -r '.step_status // "unknown"' "$state_file" 2>/dev/null)" || status="unknown"
  unit_name="$(jq -r '.name // "unknown"' "$state_file" 2>/dev/null)" || unit_name="unknown"
  mode="$(jq -r '.mode // "code"' "$state_file" 2>/dev/null)" || mode="code"

  # Deliverable progress
  completed="$(jq -r '[.deliverables | to_entries[] | select(.value.status == "completed")] | length' "$state_file" 2>/dev/null)" || completed="0"
  total="$(jq -r '.deliverables | length' "$state_file" 2>/dev/null)" || total="0"

  echo "=== Post-Compaction Context Recovery ==="
  echo ""
  echo "Active task: $unit_name"
  echo "Step: $step | Status: $status | Mode: $mode"
  echo "Deliverables: ${completed}/${total}"
  echo ""
  echo "Step skill: skills/${step}.md"
  echo ""

  # Output summary.md contents
  if [ -f "$summary_file" ]; then
    echo "=== Summary (${summary_file}) ==="
    echo ""
    cat "$summary_file"
    echo ""
  else
    echo "No summary.md found at ${summary_file}."
    echo "Read state.json for current context: $state_file"
  fi

  echo "=== End Context Recovery ==="

  return 0
}
