#!/bin/sh
# pre-commit-bakfiles.sh — Block staging of install-artifact .bak files.
#
# Called directly by the git pre-commit dispatcher (not via frw hook).
# Protected globs: bin/*.bak, .claude/rules/*.bak
#
# Return codes:
#   0 — allowed
#   1 — blocked (.bak file staged on protected path)

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

_failed=0

while IFS= read -r _path; do
  case "$_path" in
    bin/*.bak|.claude/rules/*.bak)
      log_warning "pre-commit: refusing to stage install-artifact ${_path}; move to \$XDG_STATE_HOME/furrow/"
      _failed=1
      ;;
  esac
done <<EOF
$(git diff --cached --name-only 2>/dev/null)
EOF

exit "$_failed"
