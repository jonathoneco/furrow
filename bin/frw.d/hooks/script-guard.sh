# script-guard.sh — Block direct execution of bin/frw.d/ scripts
#
# Hook: PreToolUse (matcher: Bash)
# Receives JSON on stdin with tool_name and tool_input.
# Return 2 to block if command executes a frw.d/ script; return 0 otherwise.
# Read-only commands (cat, grep, head, etc.) are allowed via allowlist.
#
# Strategy (v2 — token-aware):
# Before checking for frw.d/ references, strip:
#   1. Single-quoted strings ('...')      — data, not commands
#   2. Double-quoted strings ("...")      — data, not commands
#   3. Heredoc bodies (<<WORD...WORD)     — data, not commands
#   4. Shell comments (# ...)             — not commands
# Then apply the block check only to the remaining "shell token" text.
# This prevents false positives when the literal string appears inside a
# heredoc body, a quoted argument, or a comment.
#
# The tokenizer is conservative: when in doubt, the token stays (may block).
# The variable-substitution workaround (d=frw.d) still works as before.

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

  # Shell tokens reference frw.d/ — allow only if it matches a read-only pattern.
  # Read-only verbs: cat, grep, rg, head, tail, less, more, wc, file, ls,
  # stat, diff, md5sum, sha256sum, hexdump, od, strings, readlink, realpath, sh -n
  case "$stripped" in
    cat\ *"frw.d/"*|cat\ -*)            return 0 ;; # cat [-n] path
    grep\ *"frw.d/"*|grep\ -*)          return 0 ;; # grep [-flags] path
    rg\ *"frw.d/"*|rg\ -*)             return 0 ;; # ripgrep
    head\ *"frw.d/"*|head\ -*)         return 0 ;; # head [-n] path
    tail\ *"frw.d/"*|tail\ -*)         return 0 ;; # tail [-n] path
    less\ *"frw.d/"*)                  return 0 ;; # less path
    more\ *"frw.d/"*)                  return 0 ;; # more path
    wc\ *"frw.d/"*|wc\ -*)            return 0 ;; # wc [-l] path
    file\ *"frw.d/"*)                  return 0 ;; # file path
    ls\ *"frw.d/"*|ls\ -*)            return 0 ;; # ls [-la] path
    stat\ *"frw.d/"*)                  return 0 ;; # stat path
    diff\ *"frw.d/"*)                  return 0 ;; # diff path
    readlink\ *"frw.d/"*)              return 0 ;; # readlink path
    realpath\ *"frw.d/"*)              return 0 ;; # realpath path
    "sh -n"*"frw.d/"*)                return 0 ;; # sh -n (syntax check)
  esac

  # Not a recognized read-only command — block
  log_error "bin/frw.d/ scripts are internal — use frw, rws, alm, or sds"
  return 2
}
