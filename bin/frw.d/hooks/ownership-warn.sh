# ownership-warn.sh — Warn on file_ownership violations during implement step
#
# Hook: PreToolUse (matcher: Write|Edit)
# Receives JSON on stdin with tool_name and tool_input.
# Advisory only — always returns 0.

hook_ownership_warn() {
  input="$(cat)"

  target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" || target_path=""

  if [ -z "$target_path" ]; then
    return 0
  fi

  work_dir="$(extract_row_from_path "$target_path")"

  if [ -z "$work_dir" ]; then
    work_dir="$(find_focused_row)"
  fi

  if [ -z "$work_dir" ]; then
    return 0
  fi

  state_file="$work_dir/state.json"
  current_step="$(jq -r '.step // ""' "$state_file" 2>/dev/null)" || current_step=""

  if [ "$current_step" != "implement" ]; then
    return 0
  fi

  plan_file="$work_dir/plan.json"

  if [ ! -f "$plan_file" ]; then
    return 0
  fi

  # Get all file_ownership globs from wave assignments
  ownership_globs="$(jq -r '
    [.waves[].assignments | to_entries[].value.file_ownership // [] | .[]] | unique | .[]
  ' "$plan_file" 2>/dev/null)" || ownership_globs=""

  if [ -z "$ownership_globs" ]; then
    return 0
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

  return 0
}
