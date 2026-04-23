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
