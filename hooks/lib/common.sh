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

# --- work unit discovery ---

# find_active_work_unit — find the active work unit directory
# Returns the path to the active work unit directory (e.g., .work/add-rate-limiting)
# or empty string if none found.
find_active_work_unit() {
  _best_dir=""
  _best_ts=""

  for _state_file in .work/*/state.json; do
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

# current_step — returns the current step from the active work unit
current_step() {
  _work_dir="${1:-$(find_active_work_unit)}"
  [ -n "$_work_dir" ] || return 1
  read_state_field "$_work_dir/state.json" ".step"
}

# step_status — returns the current step status from the active work unit
step_status() {
  _work_dir="${1:-$(find_active_work_unit)}"
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

# work_unit_name <work_dir> — extract the work unit name from its directory path
work_unit_name() {
  basename "$1"
}

# is_work_unit_file <path> — check if a path is inside a .work/ directory
is_work_unit_file() {
  case "$1" in
    .work/*|*/.work/*) return 0 ;;
    *) return 1 ;;
  esac
}

# extract_unit_from_path <file_path> — extract work unit directory from a file path
# Returns the work unit directory (e.g., ".work/my-unit") if path is inside
# .work/{name}/, or empty string if not a work unit path.
extract_unit_from_path() {
  _path="$1"

  # Normalize: strip everything up to and including .work/ to get relative remainder
  case "$_path" in
    .work/*)
      _remainder="${_path#.work/}"
      ;;
    */.work/*)
      _remainder="${_path#*/.work/}"
      ;;
    *)
      echo ""
      return 0
      ;;
  esac

  # Extract the unit name (first path component)
  _unit_name="${_remainder%%/*}"

  # Skip non-unit entries (dotfiles like .focused, _meta.yaml)
  case "$_unit_name" in
    .*|_*|"")
      echo ""
      return 0
      ;;
  esac

  # Validate the unit directory exists
  if [ -f ".work/${_unit_name}/state.json" ]; then
    echo ".work/${_unit_name}"
  else
    echo ""
  fi
  return 0
}

# --- focus management ---

# find_focused_work_unit — find the focused work unit directory
# Reads .work/.focused (cache semantics), validates, falls back to
# find_active_work_unit() on invalid state. Never errors.
find_focused_work_unit() {
  # Try .focused file first
  if [ -f ".work/.focused" ]; then
    _focused_name="$(cat ".work/.focused" 2>/dev/null)" || _focused_name=""
    if [ -n "$_focused_name" ] && [ -f ".work/${_focused_name}/state.json" ]; then
      # Fail-open: jq failure treats unit as not archived (permissive for reads)
      _archived="$(jq -r '.archived_at // "null"' ".work/${_focused_name}/state.json" 2>/dev/null)" || _archived="null"
      if [ "$_archived" = "null" ]; then
        echo ".work/${_focused_name}"
        return 0
      fi
    fi
    log_warning "Stale .focused file (unit: ${_focused_name:-empty}), falling back"
  fi

  # Fallback: most recently updated active unit
  find_active_work_unit
}

# set_focus <name> — set the focused work unit
# Returns 0 on success, 1 if unit doesn't exist or is archived.
set_focus() {
  _name="$1"
  if [ ! -f ".work/${_name}/state.json" ]; then
    log_error "Cannot focus: .work/${_name}/state.json not found"
    return 1
  fi
  # Fail-closed: jq failure rejects the unit (strict for writes)
  _archived="$(jq -r '.archived_at // "null"' ".work/${_name}/state.json" 2>/dev/null)" || _archived=""
  if [ "$_archived" != "null" ]; then
    log_error "Cannot focus: unit '${_name}' is archived"
    return 1
  fi
  printf '%s' "$_name" > ".work/.focused"
  return 0
}

# clear_focus — remove the focus file (idempotent)
clear_focus() {
  rm -f ".work/.focused"
  return 0
}
