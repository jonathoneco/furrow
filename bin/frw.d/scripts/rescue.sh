#!/bin/sh
# rescue.sh — Standalone repair tool for Furrow library files.
#
# Usage: rescue.sh [--apply] [--file <path>] [--baseline-check]
#
# Options:
#   --apply             Write the restoration (default: diagnose-only, print diff)
#   --file <path>       Target file to repair (default: bin/frw.d/lib/common.sh)
#   --baseline-check    Diff bundled baseline vs live common-minimal.sh;
#                       exit 0 if match, 3 if drift
#
# Exit codes:
#   0  nothing to do / rescue applied / diagnose-only printed plan
#   1  target missing AND no usable baseline
#   2  usage error (unknown flag, missing required arg)
#   3  --baseline-check: bundled baseline differs from live common-minimal.sh
#   4  rescue wrote target but result failed sh -n parse check
#
# Standalone: no sourcing of common.sh or common-minimal.sh — depends on nothing.

set -eu

SCRIPT_PATH="$(readlink -f "$0")"
RESCUE_SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
# Derive FURROW_ROOT: rescue.sh lives at bin/frw.d/scripts/, go up 3 levels
FURROW_ROOT="$(cd "$RESCUE_SCRIPT_DIR/../../.." && pwd)"

_usage() {
  printf 'Usage: rescue.sh [--apply] [--file <path>] [--baseline-check]\n' >&2
  printf '  --apply            Write the restoration (default: diagnose-only)\n' >&2
  printf '  --file <path>      Target to repair (default: bin/frw.d/lib/common.sh)\n' >&2
  printf '  --baseline-check   Diff bundled baseline vs live common-minimal.sh\n' >&2
}

# Extract bundled baseline from this script into a temp file
_extract_baseline() {
  _out_file="$1"
  awk '
    /^FURROW_BASELINE_COMMON_MINIMAL$/ { if (inside) { exit } else { inside=1; next } }
    inside { print }
  ' "$SCRIPT_PATH" > "$_out_file"
}

# Arg parsing — POSIX while/case, mirrors doctor.sh
apply=0
baseline_check=0
target_file=""

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)
      apply=1
      shift
      ;;
    --file)
      [ $# -ge 2 ] || { printf '[furrow:error] --file requires a path argument\n' >&2; exit 2; }
      target_file="$2"
      shift 2
      ;;
    --baseline-check)
      baseline_check=1
      shift
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

# --- --baseline-check mode ---

if [ "$baseline_check" = "1" ]; then
  _cm_path="${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"
  if [ ! -f "$_cm_path" ]; then
    printf '[furrow:error] common-minimal.sh not found at %s\n' "$_cm_path" >&2
    exit 3
  fi
  _tmp_bl="$(mktemp)"
  trap 'rm -f "$_tmp_bl"' EXIT INT TERM
  _extract_baseline "$_tmp_bl"
  if cmp -s "$_cm_path" "$_tmp_bl"; then
    printf 'OK: bundled baseline matches live common-minimal.sh\n'
    rm -f "$_tmp_bl"
    trap - EXIT INT TERM
    exit 0
  else
    printf '[furrow:warning] baseline drift: common-minimal.sh has changed but rescue.sh bundled baseline was not refreshed\n' >&2
    rm -f "$_tmp_bl"
    trap - EXIT INT TERM
    exit 3
  fi
fi

# --- Default target ---

if [ -z "$target_file" ]; then
  target_file="${FURROW_ROOT}/bin/frw.d/lib/common.sh"
fi

# --- Step 1: Check if target parses cleanly (or is missing) ---

if [ ! -e "$target_file" ]; then
  printf '[furrow:warning] target not found: %s\n' "$target_file" >&2
elif sh -n "$target_file" 2>/dev/null; then
  printf 'OK: no rescue needed (%s parses cleanly)\n' "$target_file"
  exit 0
else
  printf '[furrow:warning] target fails sh -n: %s\n' "$target_file" >&2
fi

# --- Step 2: Try git show HEAD:<target> ---

_candidate=""
_candidate_source=""
_tmp_git="$(mktemp)"
_tmp_bundled="$(mktemp)"
trap 'rm -f "$_tmp_git" "$_tmp_bundled"' EXIT INT TERM

# Determine git root from the target file's directory (not cwd) so rescue
# works correctly when invoked with --file pointing to a different repo.
_target_dir="$(dirname "$target_file")"
_git_root="$(git -C "$_target_dir" rev-parse --show-toplevel 2>/dev/null)" || _git_root=""
if [ -n "$_git_root" ]; then
  case "$target_file" in
    /*) _rel_path="${target_file#${_git_root}/}" ;;
    *)  _rel_path="$target_file" ;;
  esac
  if git -C "$_git_root" show "HEAD:${_rel_path}" > "$_tmp_git" 2>/dev/null; then
    if sh -n "$_tmp_git" 2>/dev/null; then
      _candidate="$_tmp_git"
      _candidate_source="HEAD"
    else
      printf '[furrow:warning] HEAD version also fails sh -n; trying bundled baseline\n' >&2
    fi
  else
    printf '[furrow:warning] git show HEAD:%s failed; trying bundled baseline\n' "$_rel_path" >&2
  fi
fi

# --- Step 3: Try bundled baseline ---

if [ -z "$_candidate" ]; then
  _extract_baseline "$_tmp_bundled"
  if [ ! -s "$_tmp_bundled" ]; then
    printf '[furrow:error] bundled baseline is empty; cannot rescue\n' >&2
    rm -f "$_tmp_git" "$_tmp_bundled"
    trap - EXIT INT TERM
    exit 1
  fi
  if sh -n "$_tmp_bundled" 2>/dev/null; then
    _candidate="$_tmp_bundled"
    _candidate_source="bundled-baseline"
  else
    printf '[furrow:error] bundled baseline also fails sh -n; cannot rescue\n' >&2
    rm -f "$_tmp_git" "$_tmp_bundled"
    trap - EXIT INT TERM
    exit 1
  fi
fi

if [ -z "$_candidate" ]; then
  printf '[furrow:error] no usable baseline found for %s\n' "$target_file" >&2
  rm -f "$_tmp_git" "$_tmp_bundled"
  trap - EXIT INT TERM
  exit 1
fi

printf '[furrow:warning] candidate source: %s\n' "$_candidate_source" >&2

# --- Step 4/5: Apply or diagnose ---

if [ "$apply" = "1" ]; then
  _tmp_out="$(mktemp)"
  cp "$_candidate" "$_tmp_out"
  if ! sh -n "$_tmp_out" 2>/dev/null; then
    printf '[furrow:error] post-write parse check failed; NOT writing target\n' >&2
    rm -f "$_tmp_out" "$_tmp_git" "$_tmp_bundled"
    trap - EXIT INT TERM
    exit 4
  fi
  mkdir -p "$(dirname "$target_file")"
  mv "$_tmp_out" "$target_file"
  printf 'rescue applied: %s restored from %s\n' "$target_file" "$_candidate_source"
else
  if [ -f "$target_file" ]; then
    diff -u "$target_file" "$_candidate" || true
  else
    printf '(target missing; candidate from %s)\n' "$_candidate_source"
    diff /dev/null "$_candidate" || true
  fi
fi

rm -f "$_tmp_git" "$_tmp_bundled"
trap - EXIT INT TERM
exit 0

# Baseline frozen from common-minimal.sh; CI --baseline-check guards drift.
FURROW_BASELINE_COMMON_MINIMAL
#!/bin/sh
# common-minimal.sh — Hook-safe subset of common.sh.
# Sourced by bin/frw.d/hooks/*.sh. Keep <= 120 LOC.
# common.sh remains canonical; drift is guarded by rescue.sh --baseline-check.
# Contains exactly 8 hook-safe functions. Depends only on POSIX sh + jq.

set -eu

log_warning() {
  echo "[furrow:warning] $1" >&2
}

log_error() {
  echo "[furrow:error] $1" >&2
}

# find_active_row — find the active row directory
# Returns the path to the active row directory (e.g., .furrow/rows/add-rate-limiting)
# or empty string if none found.
find_active_row() {
  _best_dir=""
  _best_ts=""

  for _state_file in .furrow/rows/*/state.json; do
    [ -f "$_state_file" ] || continue
    _archived="$(jq -r '.archived_at // "null"' "$_state_file" 2>/dev/null)" || continue
    if [ "$_archived" = "null" ]; then
      _dir="$(dirname "$_state_file")"
      _updated="$(jq -r '.updated_at // ""' "$_state_file" 2>/dev/null)" || _updated=""
      if [ -z "$_best_dir" ] || { LC_ALL=C expr "$_updated" \> "$_best_ts" > /dev/null 2>&1; }; then
        _best_dir="$_dir"
        _best_ts="$_updated"
      fi
    fi
  done

  echo "$_best_dir"
}

# read_state_field <path> <field> — extract a field from state.json using jq
read_state_field() {
  _path="$1"
  _field="$2"
  jq -r "$_field" "$_path" 2>/dev/null
}

# row_name <work_dir> — extract the row name from its directory path
row_name() {
  basename "$1"
}

# is_row_file <path> — check if a path is inside a .furrow/rows/ directory
is_row_file() {
  case "$1" in
    .furrow/rows/*|*/.furrow/rows/*) return 0 ;;
    *) return 1 ;;
  esac
}

# extract_row_from_path <file_path> — extract row directory from a file path
extract_row_from_path() {
  _path="$1"

  # Normalize: strip everything up to and including .furrow/rows/ to get relative remainder
  case "$_path" in
    .furrow/rows/*)
      _remainder="${_path#.furrow/rows/}"
      ;;
    */.furrow/rows/*)
      _remainder="${_path#*/.furrow/rows/}"
      ;;
    *)
      echo ""
      return 0
      ;;
  esac

  # Extract the row name (first path component)
  _unit_name="${_remainder%%/*}"

  # Skip non-row entries (dotfiles like .focused, _meta.yaml)
  case "$_unit_name" in
    .*|_*|"")
      echo ""
      return 0
      ;;
  esac

  # Validate the row directory exists
  if [ -f ".furrow/rows/${_unit_name}/state.json" ]; then
    echo ".furrow/rows/${_unit_name}"
  else
    echo ""
  fi
  return 0
}

# find_focused_row — finds focused row (fallback: find_active_row). Never errors.
find_focused_row() {
  # Try .focused file first
  if [ -f ".furrow/.focused" ]; then
    _focused_name="$(cat ".furrow/.focused" 2>/dev/null)" || _focused_name=""
    if [ -n "$_focused_name" ] && [ -f ".furrow/rows/${_focused_name}/state.json" ]; then
      # Fail-open: jq failure treats row as not archived (permissive for reads)
      _archived="$(jq -r '.archived_at // "null"' ".furrow/rows/${_focused_name}/state.json" 2>/dev/null)" || _archived="null"
      if [ "$_archived" = "null" ]; then
        echo ".furrow/rows/${_focused_name}"
        return 0
      fi
    fi
    log_warning "Stale .focused file (row: ${_focused_name:-empty}), falling back"
  fi

  # Fallback: most recently updated active row
  find_active_row
}
FURROW_BASELINE_COMMON_MINIMAL
