# script-guard.sh — Block direct execution of bin/frw.d/ scripts
#
# Hook: PreToolUse (matcher: Bash)
# Receives JSON on stdin with tool_name and tool_input.
# Return 2 to block if command executes a frw.d/ script; return 0 otherwise.
# Read-only commands (cat, grep, head, etc.) are allowed via allowlist.
#
# Strategy: if a command references frw.d/, block UNLESS every frw.d/
# reference is preceded by a known read-only verb. This is safer than
# trying to enumerate all execution verbs.

# shellcheck source=../lib/common-minimal.sh
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"

hook_script_guard() {
  input="$(cat)"

  command_str="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)" || command_str=""

  # Fast path: no frw.d/ reference at all
  case "$command_str" in
    *frw.d/*) ;;
    *) return 0 ;;
  esac

  # Command references frw.d/ — allow only if it matches a read-only pattern.
  # Read-only verbs: cat, grep, rg, head, tail, less, more, wc, file, ls,
  # stat, diff, md5sum, sha256sum, hexdump, od, strings, readlink, realpath
  case "$command_str" in
    cat\ *frw.d/*|cat\ -*frw.d/*)       return 0 ;; # cat [-n] path
    grep\ *frw.d/*|grep\ -*frw.d/*)     return 0 ;; # grep [-flags] path
    rg\ *frw.d/*|rg\ -*frw.d/*)         return 0 ;; # ripgrep
    head\ *frw.d/*|head\ -*frw.d/*)     return 0 ;; # head [-n] path
    tail\ *frw.d/*|tail\ -*frw.d/*)     return 0 ;; # tail [-n] path
    less\ *frw.d/*)                      return 0 ;; # less path
    more\ *frw.d/*)                      return 0 ;; # more path
    wc\ *frw.d/*|wc\ -*frw.d/*)         return 0 ;; # wc [-l] path
    file\ *frw.d/*)                      return 0 ;; # file path
    ls\ *frw.d/*|ls\ -*frw.d/*)         return 0 ;; # ls [-la] path
    stat\ *frw.d/*)                      return 0 ;; # stat path
    diff\ *frw.d/*)                      return 0 ;; # diff path
    readlink\ *frw.d/*)                  return 0 ;; # readlink path
    realpath\ *frw.d/*)                  return 0 ;; # realpath path
  esac

  # Not a recognized read-only command — block
  log_error "bin/frw.d/ scripts are internal — use frw, rws, alm, or sds"
  return 2
}
