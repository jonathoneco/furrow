#!/bin/sh
# common.sh — Broader helper library for Furrow scripts.
# Sourced only by longer-running scripts (not hooks).
# Hook-safe subset lives in common-minimal.sh.
#
# Sourced by frw dispatcher for non-hook commands; not executed directly.
# Dependencies: jq, yq

set -eu

# Pull in hook-safe subset (log_warning, log_error, find_active_row,
# read_state_field, row_name, is_row_file, extract_row_from_path,
# find_focused_row). Avoids duplication; hooks source common-minimal.sh directly.
# shellcheck source=common-minimal.sh
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"

# --- state field accessors ---

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
  trap 'rm -f "$_rms_tmp"' EXIT INT TERM

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
    trap - EXIT INT TERM
    printf "Validation failed: section '%s' has no non-empty lines after update\n" "$_rms_display" >&2
    exit 3
  fi

  mv "$_rms_tmp" "$_rms_file"
  trap - EXIT INT TERM
}

# --- config resolution (three-tier chain) ---

# resolve_config_value KEY
# KEY is a dotted path (e.g. "cross_model.provider").
# Tier 1: $PROJECT_ROOT/.furrow/furrow.yaml
# Tier 2: ${XDG_CONFIG_HOME:-$HOME/.config}/furrow/config.yaml
# Tier 3: $FURROW_ROOT/.furrow/furrow.yaml (compiled-in default)
# Output: resolved string value; exit 0 if found, exit 1 if unset everywhere.
# No hardcoded ~/.config — XDG_CONFIG_HOME is always honored.
resolve_config_value() {
  _rcv_key="$1"

  # Tier 1: project-local .furrow/furrow.yaml
  if [ -f "${PROJECT_ROOT}/.furrow/furrow.yaml" ]; then
    _rcv_v="$(yq -r ".${_rcv_key} // \"\"" "${PROJECT_ROOT}/.furrow/furrow.yaml" 2>/dev/null || true)"
    [ -n "$_rcv_v" ] && [ "$_rcv_v" != "null" ] && { printf '%s\n' "$_rcv_v"; return 0; }
  fi

  # Tier 2: XDG global config (honors $XDG_CONFIG_HOME)
  _rcv_xdg="${XDG_CONFIG_HOME:-${HOME}/.config}/furrow/config.yaml"
  if [ -f "$_rcv_xdg" ]; then
    _rcv_v="$(yq -r ".${_rcv_key} // \"\"" "$_rcv_xdg" 2>/dev/null || true)"
    [ -n "$_rcv_v" ] && [ "$_rcv_v" != "null" ] && { printf '%s\n' "$_rcv_v"; return 0; }
  fi

  # Tier 3: compiled-in default under $FURROW_ROOT
  if [ -f "${FURROW_ROOT}/.furrow/furrow.yaml" ]; then
    _rcv_v="$(yq -r ".${_rcv_key} // \"\"" "${FURROW_ROOT}/.furrow/furrow.yaml" 2>/dev/null || true)"
    [ -n "$_rcv_v" ] && [ "$_rcv_v" != "null" ] && { printf '%s\n' "$_rcv_v"; return 0; }
  fi

  return 1
}

# find_specialist NAME
# NAME is the specialist slug (e.g. "harness-engineer"); no .md extension.
# Precedence (first hit wins; no merging):
#   1. $PROJECT_ROOT/specialists/{name}.md       — project-local override
#   2. ${XDG_CONFIG_HOME:-$HOME/.config}/furrow/specialists/{name}.md — user global
#   3. $FURROW_ROOT/specialists/{name}.md        — compiled-in
# Output: absolute path to the specialist file; exit 0 if found, exit 1 if not.
# Errors to stderr with [furrow:error] prefix.
find_specialist() {
  _fs_name="$1"

  # Tier 1: project-local
  _fs_proj="${PROJECT_ROOT}/specialists/${_fs_name}.md"
  if [ -f "$_fs_proj" ]; then
    printf '%s\n' "$_fs_proj"
    return 0
  fi

  # Tier 2: XDG user-global
  _fs_xdg="${XDG_CONFIG_HOME:-${HOME}/.config}/furrow/specialists/${_fs_name}.md"
  if [ -f "$_fs_xdg" ]; then
    printf '%s\n' "$_fs_xdg"
    return 0
  fi

  # Tier 3: compiled-in
  _fs_root="${FURROW_ROOT}/specialists/${_fs_name}.md"
  if [ -f "$_fs_root" ]; then
    printf '%s\n' "$_fs_root"
    return 0
  fi

  log_error "specialist not found: ${_fs_name}"
  return 1
}

# --- focus management ---

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
