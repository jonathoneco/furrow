# script-guard.sh — Block direct execution of bin/frw.d/ scripts
#
# Hook: PreToolUse (matcher: Bash)
# Receives JSON on stdin with tool_name and tool_input.
# Return 2 to block if command executes a frw.d/ script; return 0 otherwise.
# Read-only commands (cat, grep, head, etc.) are allowed.

hook_script_guard() {
  input="$(cat)"

  command_str="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)" || command_str=""

  # Fast path: no frw.d/ reference at all
  case "$command_str" in
    *frw.d/*) ;;
    *) return 0 ;;
  esac

  # Command references frw.d/ — check for execution verbs
  case "$command_str" in
    bash\ *frw.d/*|*/bash\ *frw.d/*)       ;; # bash <path>
    sh\ *frw.d/*|*/sh\ *frw.d/*)           ;; # sh <path>
    source\ *frw.d/*|*/source\ *frw.d/*)   ;; # source <path>
    ". "*frw.d/*)                            ;; # . <path> (dot-source)
    *"&& bash "*frw.d/*|*"|| bash "*frw.d/*);; # chained: && / || bash
    *"; bash "*frw.d/*|*"| bash "*frw.d/*)  ;; # chained/piped: ; / | bash
    *"&& sh "*frw.d/*|*"|| sh "*frw.d/*)   ;; # chained: && / || sh
    *"; sh "*frw.d/*|*"| sh "*frw.d/*)     ;; # chained/piped: ; / | sh
    *"&& source "*frw.d/*|*"|| source "*frw.d/*) ;; # chained: source
    *"; source "*frw.d/*)                   ;; # chained: ; source
    *"&& . "*frw.d/*|*"|| . "*frw.d/*)     ;; # chained: && / || .
    *"; . "*frw.d/*)                        ;; # chained: ; .
    *) return 0 ;;  # No execution verb — allow (read-only)
  esac

  log_error "bin/frw.d/ scripts are internal — use frw, rws, alm, or sds"
  return 2
}
