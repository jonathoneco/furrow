# script-guard.sh — Block direct execution of bin/frw.d/ scripts
#
# Hook: PreToolUse (matcher: Bash)
# Receives JSON on stdin with tool_name and tool_input.
# Return 2 to block if command executes a frw.d/ script; return 0 otherwise.
#
# Strategy (v3 — execution-only blocklist):
# Previously the guard used a narrow allowlist of read verbs (cat, grep, ...)
# and blocked everything else. That rejected legitimate read/edit/analyze
# operations (sed -n '40,80p' bin/frw.d/foo.sh, awk, vim, git diff, etc.).
#
# The new policy is: block ONLY clear execution patterns, allow everything
# else. Execution is detected by tokenizing the stripped shell text and
# checking for a frw.d/ path at command-execution position:
#   - First token of a command chain is a frw.d/ path (direct invocation)
#   - First token is an interpreter (sh, bash, zsh, dash, ksh, exec, source, .)
#     and the first non-flag argument is a frw.d/ path
#   - sh -n / bash -n is a syntax check, not execution — allowed
#
# Before tokenizing, the input is run through shell_strip_data_regions to
# remove quoted strings, heredoc bodies, and comments (so literal frw.d/
# inside a commit message or printf arg doesn't false-positive).

# shellcheck source=../lib/common-minimal.sh
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"

# shell_strip_data_regions <string>
# Strips single-quoted strings, double-quoted strings, heredoc bodies,
# and line comments from a shell command string. The result contains only
# the unquoted, non-heredoc, non-comment token text.
#
# POSIX awk implementation — no bash-isms.
# Note: single-quote characters in awk strings use sprintf("%c",39) to
# avoid terminating the surrounding shell quoting.
shell_strip_data_regions() {
  # SQ=single-quote char used in awk comparisons without embedding a literal '
  printf '%s\n' "$1" | awk -v SQ="'" '
BEGIN {
  state = "normal"
  heredoc_word = ""
}
{
  line = $0
  n = length(line)
  i = 1
  while (i <= n) {
    ch = substr(line, i, 1)
    ch2 = (i < n) ? substr(line, i, 2) : ""

    if (state == "normal") {
      # Heredoc start: << or <<-
      if (ch2 == "<<") {
        i += 2
        if (i <= n && substr(line, i, 1) == "-") i++
        while (i <= n && substr(line, i, 1) == " ") i++
        # Collect heredoc delimiter word (strip enclosing quotes)
        hq = ""
        hw = ""
        if (i <= n && (substr(line, i, 1) == SQ || substr(line, i, 1) == "\"")) {
          hq = substr(line, i, 1)
          i++
        }
        while (i <= n) {
          c = substr(line, i, 1)
          if (hq != "" && c == hq) { i++; break }
          if (hq == "" && (c == " " || c == "\t" || c == ";" || c == "&" || c == "|")) break
          hw = hw c
          i++
        }
        heredoc_word = hw
        state = "heredoc"
        printf " "
        continue
      }
      # Single-quoted string
      if (ch == SQ) {
        state = "sq"
        printf " "
        i++
        continue
      }
      # Double-quoted string
      if (ch == "\"") {
        state = "dq"
        printf " "
        i++
        continue
      }
      # Comment — rest of line is not shell tokens
      if (ch == "#") {
        printf "\n"
        i = n + 1
        continue
      }
      # Normal token character — emit
      printf "%s", ch
      i++
    } else if (state == "sq") {
      if (ch == SQ) {
        state = "normal"
        printf " "
      }
      i++
    } else if (state == "dq") {
      # Backslash escapes the next char inside double quotes
      if (ch == "\\" && i < n) {
        i += 2
        continue
      }
      if (ch == "\"") {
        state = "normal"
        printf " "
      }
      i++
    } else {
      # heredoc state: skip all characters on this line; termination
      # checked per-line in the block below the while loop.
      i++
    }
  }
  if (state == "heredoc") {
    # Check if this line is the heredoc terminator
    trimmed = line
    gsub(/^[[:space:]]+/, "", trimmed)
    gsub(/[[:space:]]+$/, "", trimmed)
    if (trimmed == heredoc_word) {
      state = "normal"
      heredoc_word = ""
    }
    # Suppress the line (heredoc body is data, not tokens)
  } else {
    printf "\n"
  }
}
'
}

hook_script_guard() {
  input="$(cat)"

  command_str="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)" || command_str=""

  # Fast path: no frw.d/ reference at all in the raw string
  case "$command_str" in
    *"frw.d/"*) ;;
    *) return 0 ;;
  esac

  # Strip data regions (quoted strings, heredocs, comments) from the command.
  # Only the remaining shell tokens are checked for frw.d/ references.
  stripped="$(shell_strip_data_regions "$command_str")"

  # Fast path: no frw.d/ in the stripped (shell-token) text
  case "$stripped" in
    *"frw.d/"*) ;;
    *) return 0 ;;
  esac

  # Detect execution patterns. awk tokenizes the stripped command and exits
  # non-zero when a frw.d/ path appears at command-execution position.
  # All read/edit/analyze operations fall through to allow.
  if printf '%s\n' "$stripped" | awk '
    BEGIN { blocked = 0 }
    {
      line = $0
      # Collapse multi-char shell separators to single ";" so split works.
      gsub(/&&/, " ; ", line); gsub(/\|\|/, " ; ", line)
      gsub(/\|/,  " ; ", line); gsub(/&/,     " ; ", line)
      n = split(line, cmds, /[[:space:]]*;[[:space:]]*/)
      for (p = 1; p <= n; p++) {
        cmd = cmds[p]
        gsub(/^[[:space:]]+/, "", cmd); gsub(/[[:space:]]+$/, "", cmd)
        if (cmd == "") continue
        m = split(cmd, tok, /[[:space:]]+/)
        first = tok[1]
        # Direct execution: first token IS a frw.d/ path
        if (first ~ /bin\/frw\.d\//) { blocked = 1; continue }
        # Interpreter/source/exec followed by a frw.d/ path
        if (first == "sh" || first == "bash" || first == "zsh" ||
            first == "dash" || first == "ksh" || first == "source" ||
            first == "." || first == "exec") {
          has_n = 0
          for (j = 2; j <= m; j++) {
            t = tok[j]
            if (t == "") continue
            if (t == "-n") { has_n = 1; continue }
            if (t ~ /^-/) continue
            # First non-flag argument
            if (t ~ /bin\/frw\.d\//) {
              # sh -n / bash -n is syntax check only, not execution
              if (has_n && (first == "sh" || first == "bash")) break
              blocked = 1
            }
            break
          }
        }
      }
    }
    END { exit blocked }
  '; then
    return 0  # awk exit 0 → no execution pattern detected, allow
  fi

  log_error "bin/frw.d/ scripts are internal — use frw, rws, alm, or sds"
  return 2
}
