#!/bin/sh
# common.sh — Shared utility functions for Furrow hooks
#
# Sourced by hook scripts; not executed directly.
# Dependencies: jq, yq

set -eu

# --- logging ---

log_warning() {
  echo "[furrow:warning] $1" >&2
}

log_error() {
  echo "[furrow:error] $1" >&2
}

# --- row discovery ---

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

# --- state field accessors ---

# read_state_field <path> <field> — extract a field from state.json using jq
# Args:
#   path  — path to state.json
#   field — jq field expression (e.g., ".step", ".step_status")
# Returns the raw value.
read_state_field() {
  _path="$1"
  _field="$2"
  jq -r "$_field" "$_path" 2>/dev/null
}

# read_definition_field <path> <field> — extract a field from definition.yaml using yq
# Args:
#   path  — path to definition.yaml
#   field — yq field expression (e.g., ".objective")
# Returns the raw value.
read_definition_field() {
  _path="$1"
  _field="$2"
  yq -r "$_field" "$_path" 2>/dev/null
}

# current_step — returns the current step from the active row
current_step() {
  _work_dir="${1:-$(find_active_row)}"
  [ -n "$_work_dir" ] || return 1
  read_state_field "$_work_dir/state.json" ".step"
}

# step_status — returns the current step status from the active row
step_status() {
  _work_dir="${1:-$(find_active_row)}"
  [ -n "$_work_dir" ] || return 1
  read_state_field "$_work_dir/state.json" ".step_status"
}

# --- gate checking ---

# has_passing_gate <state_path> <boundary>
# Returns 0 (true) if a gate record with outcome "pass" or "conditional" exists.
# Returns 1 (false) otherwise.
has_passing_gate() {
  _state_path="$1"
  _boundary="$2"

  _count="$(jq -r --arg b "$_boundary" '
    [.gates[] | select(.boundary == $b and (.outcome == "pass" or .outcome == "conditional"))] | length
  ' "$_state_path" 2>/dev/null)" || _count="0"

  [ "$_count" -gt 0 ]
}

# --- path helpers ---

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
# Returns the row directory (e.g., ".furrow/rows/my-unit") if path is inside
# .furrow/rows/{name}/, or empty string if not a row path.
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

# --- markdown section helpers ---

# extract_md_section <file> <display_name>
# Prints the content lines of the given ## section from a markdown file.
# Stops at the next ## heading. Strips blank lines.
extract_md_section() {
  _ems_file="$1"
  _ems_display="$2"
  awk -v sec="$_ems_display" '
    $0 == "## " sec { found=1; next }
    /^## /          { if (found) exit }
    found           { print }
  ' "$_ems_file" | sed '/^$/d'
}

# replace_md_section <file> <display_name> <content>
# Atomically replaces the ## section with new content.
# Writes to a temp file, validates the section is non-empty, then renames.
# Exits with EXIT_VALIDATION (3) if the section is missing/empty after write.
replace_md_section() {
  _rms_file="$1"
  _rms_display="$2"
  _rms_content="$3"

  _rms_tmp="${_rms_file}.tmp.$$"

  awk -v section="$_rms_display" -v new_content="$_rms_content" '
    /^## / { if (header == section) { replacing=0 } }
    /^## / { header=$0; sub(/^## /, "", header) }
    header == section && !printed_new { print "## " section; printf "%s\n", new_content; printed_new=1; replacing=1; next }
    replacing { next }
    { print }
  ' "$_rms_file" > "$_rms_tmp"

  _rms_check="$(awk -v sec="$_rms_display" '
    $0 == "## " sec { found=1; next }
    /^## /          { if (found) exit }
    found && NF     { print }
  ' "$_rms_tmp")"

  if [ -z "$_rms_check" ]; then
    rm -f "$_rms_tmp"
    printf "Validation failed: section '%s' has no non-empty lines after update\n" "$_rms_display" >&2
    exit 3
  fi

  mv "$_rms_tmp" "$_rms_file"
}

# --- focus management ---

# find_focused_row — find the focused row directory
# Reads .furrow/.focused (cache semantics), validates, falls back to
# find_active_row() on invalid state. Never errors.
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

# set_focus <name> — set the focused row
# Returns 0 on success, 1 if row doesn't exist or is archived.
set_focus() {
  _name="$1"
  if [ ! -f ".furrow/rows/${_name}/state.json" ]; then
    log_error "Cannot focus: .furrow/rows/${_name}/state.json not found"
    return 1
  fi
  # Fail-closed: jq failure rejects the row (strict for writes)
  _archived="$(jq -r '.archived_at // "null"' ".furrow/rows/${_name}/state.json" 2>/dev/null)" || _archived=""
  if [ "$_archived" != "null" ]; then
    log_error "Cannot focus: row '${_name}' is archived"
    return 1
  fi
  printf '%s' "$_name" > ".furrow/.focused"
  return 0
}

# clear_focus — remove the focus file (idempotent)
clear_focus() {
  rm -f ".furrow/.focused"
  return 0
}
