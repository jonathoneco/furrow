#!/bin/sh
# normalize-seeds.sh — Sort .furrow/seeds/seeds.jsonl by (created_at, id) ASC.
# Algorithm: stable sort keyed on (created_at, id, line-number).
# Idempotent: running twice produces zero diff.
# Byte-identical output where input was already compact jq -c form.
#
# Usage: frw normalize-seeds
#   (invoked via frw dispatcher; FURROW_ROOT and PROJECT_ROOT must be set)
set -eu

SEEDS_JSONL="${PROJECT_ROOT}/.furrow/seeds/seeds.jsonl"

frw_normalize_seeds() {
  if [ ! -f "$SEEDS_JSONL" ]; then
    printf '[furrow:info] normalize-seeds: %s not found, nothing to do\n' "$SEEDS_JSONL" >&2
    return 0
  fi

  # Work entirely in temp files to allow atomic replace
  _tmp_keys=$(mktemp)
  _tmp_sorted=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '$_tmp_keys' '$_tmp_sorted'" EXIT INT TERM

  # Build a sortable key file: <created_at>\t<id>\t<linenum>\t<line>
  # We use LC_ALL=C throughout for locale-independent ordering.
  _linenum=0
  while IFS= read -r _line || [ -n "$_line" ]; do
    # Skip blank lines
    case "$_line" in
      '') continue ;;
    esac
    _linenum=$((_linenum + 1))

    # Extract sort keys from JSON — require jq
    _key=$(printf '%s\n' "$_line" | LC_ALL=C jq -r '[.created_at // "", .id // ""] | @tsv' 2>/dev/null) || {
      printf '[furrow:error] normalize-seeds: invalid JSON on line %d, aborting\n' "$_linenum" >&2
      rm -f "$_tmp_keys" "$_tmp_sorted"
      exit 1
    }
    # Format: created_at<TAB>id<TAB>linenum<TAB>original_line
    printf '%s\t%d\t%s\n' "$_key" "$_linenum" "$_line" >> "$_tmp_keys"
  done < "$SEEDS_JSONL"

  if [ ! -s "$_tmp_keys" ]; then
    # Empty or all-blank file — nothing to sort
    rm -f "$_tmp_keys" "$_tmp_sorted"
    return 0
  fi

  # Sort: primary key = col1 (created_at), secondary = col2 (id), tertiary = col3 (linenum, numeric)
  # -s = stable sort (GNU sort) or -k3,3n as tiebreaker achieves same effect on POSIX sort.
  # col separator is TAB.
  LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k2,2 -k3,3n "$_tmp_keys" | \
    cut -f4- > "$_tmp_sorted"

  # Atomic replace
  mv "$_tmp_sorted" "$SEEDS_JSONL"
  rm -f "$_tmp_keys"
  trap - EXIT INT TERM

  printf '[furrow:info] normalize-seeds: sorted %d entries in %s\n' "$_linenum" "$SEEDS_JSONL" >&2
}

frw_normalize_seeds "$@"
