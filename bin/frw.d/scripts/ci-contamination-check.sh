#!/bin/sh
# ci-contamination-check.sh — detect banned patterns in changed files.
#
# Usage: ci-contamination-check.sh [--base <ref>]
#   Default base ref: origin/main
#
# Exit codes:
#   0  clean
#   1  contamination found
#   2  usage error
#   3  baseline drift (rescue.sh --baseline-check exit 3)
set -eu

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
FURROW_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

_usage() {
  printf 'Usage: ci-contamination-check.sh [--base <ref>]\n' >&2
  printf '  --base <ref>   Git ref to diff against (default: origin/main)\n' >&2
}

base_ref="origin/main"

while [ $# -gt 0 ]; do
  case "$1" in
    --base)
      [ $# -ge 2 ] || { printf '[furrow:error] --base requires a ref argument\n' >&2; exit 2; }
      base_ref="$2"
      shift 2
      ;;
    -h|--help)
      _usage
      exit 0
      ;;
    -*)
      printf '[furrow:error] unknown flag: %s\n' "$1" >&2
      _usage
      exit 2
      ;;
    *)
      printf '[furrow:error] unexpected argument: %s\n' "$1" >&2
      _usage
      exit 2
      ;;
  esac
done

contaminated=0

# ----------------------------------------------------------------
# Helper: get the git tree entry mode and sha for a path at HEAD
# Returns: "<mode> <sha>" or empty if not in tree
_tree_entry() {
  _path="$1"
  git ls-tree -r HEAD -- "$_path" 2>/dev/null | awk '{print $1, $3}' | head -1
}

# ----------------------------------------------------------------
# Get list of changed files (Added, Copied, Modified) vs base ref
changed_files=""
if git rev-parse --verify "${base_ref}" >/dev/null 2>&1; then
  changed_files=$(git diff --name-only --diff-filter=ACM "${base_ref}..HEAD" 2>/dev/null) || changed_files=""
else
  # base_ref not reachable — diff against empty tree (first commit scenario)
  changed_files=$(git ls-files 2>/dev/null) || changed_files=""
fi

# ----------------------------------------------------------------
# Check 1: Protected bin scripts (alm|rws|sds) as symlinks
for _f in $changed_files; do
  case "$_f" in
    bin/alm|bin/rws|bin/sds)
      _entry=$(_tree_entry "$_f")
      _mode=$(printf '%s\n' "$_entry" | awk '{print $1}')
      if [ "$_mode" = "120000" ]; then
        printf '[furrow:error] contamination: protected binary %s is a symlink (mode 120000) — must be a regular file\n' "$_f" >&2
        contaminated=1
      fi
      ;;
  esac
done

# ----------------------------------------------------------------
# Check 2: .bak files in bin/
for _f in $changed_files; do
  case "$_f" in
    bin/*.bak)
      printf '[furrow:error] contamination: tracked .bak file: %s\n' "$_f" >&2
      contaminated=1
      ;;
  esac
done

# ----------------------------------------------------------------
# Check 3: Specialist symlinks that escape the worktree
for _f in $changed_files; do
  case "$_f" in
    .claude/commands/specialist:*.md)
      _entry=$(_tree_entry "$_f")
      _mode=$(printf '%s\n' "$_entry" | awk '{print $1}')
      if [ "$_mode" = "120000" ]; then
        _sha=$(printf '%s\n' "$_entry" | awk '{print $2}')
        if [ -n "$_sha" ]; then
          _target=$(git cat-file -p "$_sha" 2>/dev/null) || _target=""
          # Escaping: absolute path (starts with /) or too many parent traversals
          case "$_target" in
            /*)
              printf '[furrow:error] contamination: specialist symlink %s has absolute target: %s\n' "$_f" "$_target" >&2
              contaminated=1
              ;;
            *../../..*)
              printf '[furrow:error] contamination: specialist symlink %s escapes worktree (depth >=3): %s\n' "$_f" "$_target" >&2
              contaminated=1
              ;;
          esac
        fi
      fi
      ;;
  esac
done

# ----------------------------------------------------------------
# Check 4: Rescue baseline drift
_frwd_scripts_dir="${FURROW_ROOT}/bin/frw.d/scripts"
rescue_script="${_frwd_scripts_dir}/rescue.sh"
if [ -f "$rescue_script" ]; then
  _baseline_rc=0
  sh "$rescue_script" --baseline-check >/dev/null 2>&1 || _baseline_rc=$?
  if [ "$_baseline_rc" = "3" ]; then
    printf '[furrow:error] baseline drift: common-minimal.sh has changed but rescue.sh bundled baseline was not refreshed\n' >&2
    exit 3
  fi
fi

# ----------------------------------------------------------------
if [ "$contaminated" -ne 0 ]; then
  exit 1
fi

printf 'ci-contamination-check: clean\n'
exit 0
