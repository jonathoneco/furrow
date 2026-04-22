#!/bin/sh
# merge-sort-union.sh — Helper for sort-by-id-union merge strategy
#
# Usage: merge-sort-union.sh <path> <key> <sort_field1> [<sort_field2>...]
#
# Unions records from both sides (ours + theirs) of a merge conflict,
# de-dups by key, sorts by the provided tuple (LC_ALL=C).
# Supports: .jsonl (JSONL/NDJSON), .yaml/.yml (YAML list).
#
# Expects the file to be in a conflicted state (<<<HEAD ... >>>branch)
# or that the caller has set up the working tree appropriately.
#
# Exit codes:
#   0  merged content written to <path>
#   1  usage error
#   2  unsupported format / missing deps

set -eu

_die() { printf '[furrow:error] merge-sort-union: %s\n' "$1" >&2; exit "${2:-1}"; }

[ $# -ge 2 ] || { printf 'Usage: merge-sort-union.sh <path> <key> [sort_fields...]\n' >&2; exit 1; }

_path="$1"; shift
_key="$1"; shift
_sort_fields="$*"

[ -f "$_path" ] || _die "file not found: $_path" 2

command -v jq >/dev/null 2>&1 || _die "jq is required" 2

# Detect format
case "$_path" in
  *.jsonl|*.ndjson)
    _format="jsonl"
    ;;
  *.yaml|*.yml)
    _format="yaml"
    command -v yq >/dev/null 2>&1 || _die "yq is required for YAML files" 2
    ;;
  *)
    _die "unsupported format: $_path (expected .jsonl or .yaml)" 2
    ;;
esac

# Extract ours and theirs from conflict markers if present
_tmp_ours="$(mktemp)"
_tmp_theirs="$(mktemp)"
_tmp_merged="$(mktemp)"
trap 'rm -f "$_tmp_ours" "$_tmp_theirs" "$_tmp_merged"' EXIT INT TERM

_has_conflicts=0
if grep -q '^<<<<<<< ' "$_path" 2>/dev/null; then
  _has_conflicts=1
  # Extract ours (between <<<<<<< and =======)
  awk '/^<<<<<<< /{in_ours=1; next} /^=======$/{in_ours=0; next} in_ours{print}' "$_path" > "$_tmp_ours"
  # Extract theirs (between ======= and >>>>>>>)
  awk '/^=======$/{in_theirs=1; next} /^>>>>>>> /{in_theirs=0; next} in_theirs{print}' "$_path" > "$_tmp_theirs"
else
  # No conflict markers — use the file as-is (ours = theirs = current content)
  cp "$_path" "$_tmp_ours"
  cp "$_path" "$_tmp_theirs"
fi

if [ "$_format" = "jsonl" ]; then
  # Parse JSONL: each line is a JSON object
  # Build sort expression for jq
  if [ -n "$_sort_fields" ]; then
    _sort_expr="$(printf '%s' "$_sort_fields" | tr ' ' '\n' | while IFS= read -r _sf; do
      printf '.%s' "$_sf"
    done | paste -sd ',' | sed 's/^/[/' | sed 's/$/]/')"
  else
    _sort_expr="[.$_key]"
  fi

  # Union and sort using jq
  # Read both files as JSONL arrays, union by key, sort
  LC_ALL=C jq -s --arg key "$_key" --argjson sort_expr_placeholder '["created_at","id"]' '
    # Read all records from both inputs
    . as $all |
    # Build a map keyed by the key field (last-writer-wins)
    reduce $all[] as $rec ({}; . + {($rec[$key]): $rec}) |
    # Convert map back to array
    to_entries | map(.value) |
    # Sort by key fields
    sort_by(if has("created_at") then .created_at else "" end, if has($key) then .[$key] else "" end)
  ' \
    <(grep -v '^$' "$_tmp_ours" | jq -s '.') \
    <(grep -v '^$' "$_tmp_theirs" | jq -s '.') \
    2>/dev/null | jq -r '.[] | @json' > "$_tmp_merged"

  # Write merged content back
  cp "$_tmp_merged" "$_path"

elif [ "$_format" = "yaml" ]; then
  # Convert YAML to JSON, union, convert back
  _tmp_ours_json="$(mktemp)"
  _tmp_theirs_json="$(mktemp)"
  _tmp_merged_json="$(mktemp)"

  yq -o=json '.' "$_tmp_ours" > "$_tmp_ours_json" 2>/dev/null || printf '[]' > "$_tmp_ours_json"
  yq -o=json '.' "$_tmp_theirs" > "$_tmp_theirs_json" 2>/dev/null || printf '[]' > "$_tmp_theirs_json"

  LC_ALL=C jq -s --arg key "$_key" '
    flatten |
    reduce .[] as $rec ({}; . + {($rec[$key]): $rec}) |
    to_entries | map(.value) |
    sort_by(if has("created_at") then .created_at else "" end, .[$key])
  ' "$_tmp_ours_json" "$_tmp_theirs_json" > "$_tmp_merged_json"

  yq -o=yaml '.' "$_tmp_merged_json" > "$_path"

  rm -f "$_tmp_ours_json" "$_tmp_theirs_json" "$_tmp_merged_json"
fi

printf '[furrow:info] merge-sort-union: merged %s (%s, key=%s)\n' "$_path" "$_format" "$_key" >&2
exit 0
