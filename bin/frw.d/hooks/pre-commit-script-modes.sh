#!/bin/sh
# pre-commit-script-modes.sh — Block staging of bin/frw.d/scripts/*.sh files at
# mode 100644. Every script under bin/frw.d/scripts/ must ship as 100755 so the
# bin/frw dispatcher's `exec "$FURROW_ROOT/bin/frw.d/scripts/<name>.sh" "$@"`
# path does not fail with EACCES.
#
# Called directly by the git pre-commit dispatcher (not via frw hook), mirroring
# the pattern of pre-commit-bakfiles.sh and pre-commit-typechange.sh.
#
# Behavior: iterate every staged path under bin/frw.d/scripts/*.sh; for each one
# whose git index mode is 100644, print the offending path on stderr and exit 1.
# A clean staged tree (no matching paths, or all at 100755) exits 0.
#
# Return codes:
#   0 — allowed
#   1 — blocked (one or more bin/frw.d/scripts/*.sh staged at mode 100644)

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

# Collect staged additions + modifications under bin/frw.d/scripts/*.sh
# --diff-filter=ACM covers adds, copies, and modifications. Renames would keep
# the existing index mode and are handled by the generic 100644 check below.
_staged="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)"

# Iterate via a here-doc to avoid subshell scope issues with the `_failed` var.
while IFS= read -r _path; do
  [ -n "$_path" ] || continue
  case "$_path" in
    bin/frw.d/scripts/*.sh) ;;
    *) continue ;;
  esac

  # Read the index mode for this path. ls-files -s prints:
  #   <mode> <sha> <stage>\t<path>
  _mode="$(git ls-files -s -- "$_path" 2>/dev/null | awk '{print $1}' | head -n1)"
  [ -n "$_mode" ] || continue

  if [ "$_mode" = "100644" ]; then
    log_warning "pre-commit-script-modes: $_path must be 100755"
    _failed=1
  fi
done <<EOF
$_staged
EOF

exit "$_failed"
