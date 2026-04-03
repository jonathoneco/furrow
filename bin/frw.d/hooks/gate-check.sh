# gate-check.sh — Verify gate record before step advance
#
# Hook: PreToolUse (matcher: Bash)
# Receives JSON on stdin with tool_name and tool_input.
# Return 2 to block if advancing without a passing gate; return 0 otherwise.
#
# Delegates to: rws gate-check

hook_gate_check() {
  RWS="$FURROW_ROOT/bin/rws"

  if [ ! -x "$RWS" ]; then
    return 0
  fi

  input="$(cat)"

  command_str="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)" || command_str=""

  # Only care about rws transition invocations
  case "$command_str" in
    *rws*transition*) ;;
    *) return 0 ;;
  esac

  # Extract row name from rws transition <name>
  row_name="$(echo "$command_str" | sed -E -n 's/.*rws +transition +([^ ]*).*/\1/p')"

  if [ -n "$row_name" ]; then
    state_file=".furrow/rows/$row_name/state.json"
    def_file=".furrow/rows/$row_name/definition.yaml"
  else
    # Fallback: try focused row
    focused_file=".furrow/.focused"
    if [ -f "$focused_file" ]; then
      row_name="$(cat "$focused_file")"
      state_file=".furrow/rows/$row_name/state.json"
      def_file=".furrow/rows/$row_name/definition.yaml"
    else
      return 0
    fi
  fi

  if [ -z "$row_name" ] || [ ! -f "$state_file" ]; then
    return 0
  fi

  current="$(jq -r '.step' "$state_file" 2>/dev/null)" || current=""
  if [ -z "$current" ]; then
    return 0
  fi

  # Delegate to rws gate-check
  if ! "$RWS" gate-check "$current" "$def_file" "$state_file" 2>/dev/null; then
    printf 'rws: gate-check failed for %s at step %s\n' "$row_name" "$current" >&2
    return 2
  fi

  return 0
}
