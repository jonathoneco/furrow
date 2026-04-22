#!/bin/sh
# pre-commit-typechange.sh — Block type-change commits (regular file → symlink)
# on protected paths.
#
# Called directly by the git pre-commit dispatcher (not via frw hook).
# Protected globs: bin/alm, bin/rws, bin/sds, .claude/rules/*
#
# Return codes:
#   0 — allowed
#   1 — blocked (typechange to symlink on protected path)

set -eu

# Locate common-minimal.sh relative to git root (pre-commit hook context).
_git_root="$(git rev-parse --show-toplevel 2>/dev/null)" || _git_root=""
if [ -n "$_git_root" ] && [ -f "$_git_root/bin/frw.d/lib/common-minimal.sh" ]; then
  # shellcheck source=../lib/common-minimal.sh
  . "$_git_root/bin/frw.d/lib/common-minimal.sh"
else
  # Fallback: minimal inline log_warning if lib not found
  log_warning() { printf '[furrow:warning] %s\n' "$1" >&2; }
fi

# Protected paths (exact matches and globs)
_is_protected() {
  _p="$1"
  case "$_p" in
    bin/alm|bin/rws|bin/sds) return 0 ;;
    .claude/rules/*) return 0 ;;
  esac
  return 1
}

_failed=0

# git diff --cached --raw emits lines like:
#   :100644 120000 <sha> <sha> T\tpath
# Filter for T (typechange) entries where new mode is 120000 (symlink).
while IFS= read -r _line; do
  # Parse: :<old_mode> <new_mode> <sha> <sha> <status>\t<path>
  _new_mode="$(printf '%s' "$_line" | awk '{print $2}')"
  _status="$(printf '%s' "$_line" | awk '{print $5}' | cut -c1)"
  _path="$(printf '%s' "$_line" | awk '{print $6}')"

  # Only care about typechange (T) to symlink (120000)
  if [ "$_status" = "T" ] && [ "$_new_mode" = "120000" ]; then
    if _is_protected "$_path"; then
      log_warning "pre-commit: refusing type-change -> symlink on ${_path} (see docs/architecture/self-hosting.md)"
      _failed=1
    fi
  fi
done <<EOF
$(git diff --cached --raw 2>/dev/null)
EOF

exit "$_failed"
