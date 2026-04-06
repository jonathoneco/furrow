# gate-check.sh — Verify gate record before step advance
#
# Hook: PreToolUse (matcher: Bash)
# Receives JSON on stdin with tool_name and tool_input.
# Return 2 to block if advancing without a passing gate; return 0 otherwise.
#
# Delegates to: has_passing_gate from common.sh

hook_gate_check() {
  RWS="$FURROW_ROOT/bin/rws"

  if [ ! -x "$RWS" ]; then
    return 0
  fi

  . "$FURROW_ROOT/bin/frw.d/lib/common.sh"

  input="$(cat)"

  command_str="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)" || command_str=""

  # Only care about "rws transition" as an actual command (not substring in args/heredoc)
  case "$command_str" in
    *"rws transition "*) ;;
    *"bin/rws transition "*) ;;
    *) return 0 ;;
  esac

  # Extract row name: rws transition --request <name> ... or rws transition --confirm <name>
  row_name="$(echo "$command_str" | sed -E -n 's/.*rws +transition +--(request|confirm) +([^ ]*).*/\2/p')"

  if [ -z "$row_name" ]; then
    # Fallback: try focused row
    focused_file=".furrow/.focused"
    if [ -f "$focused_file" ]; then
      row_name="$(cat "$focused_file")"
    else
      return 0
    fi
  fi

  state_file=".furrow/rows/$row_name/state.json"

  if [ -z "$row_name" ] || [ ! -f "$state_file" ]; then
    return 0
  fi

  current="$(jq -r '.step' "$state_file" 2>/dev/null)" || current=""
  if [ -z "$current" ]; then
    return 0
  fi

  # Only check --confirm (--request is what creates the gate record)
  # Blocking --request would be circular — no gate exists until --request writes it
  case "$command_str" in
    *--request*) return 0 ;;
  esac

  # Determine the boundary (current->next)
  next="$(jq -r --arg step "$current" '
    .steps_sequence as $seq |
    ($seq | to_entries[] | select(.value == $step) | .key) as $idx |
    $seq[$idx + 1] // "review"
  ' "$state_file" 2>/dev/null)" || next=""

  if [ -z "$next" ]; then
    return 0
  fi

  boundary="${current}->${next}"

  # Check for a passing gate record for this boundary
  if has_passing_gate "$state_file" "$boundary"; then
    return 0
  fi

  printf 'rws: no passing gate record for %s at boundary %s\n' "$row_name" "$boundary" >&2
  return 2
}
