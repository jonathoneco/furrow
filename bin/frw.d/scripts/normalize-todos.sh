#!/bin/sh
# normalize-todos.sh — Sort .furrow/almanac/todos.yaml by (created_at, id) ASC.
# Requires: yq v4.
# Algorithm: yq sort_by(.created_at, .id) with atomic tmp+mv write.
# Idempotent: running twice produces zero diff.
#
# Usage: frw normalize-todos
#   (invoked via frw dispatcher; FURROW_ROOT and PROJECT_ROOT must be set)
set -eu

TODOS_YAML="${PROJECT_ROOT}/.furrow/almanac/todos.yaml"

frw_normalize_todos() {
  # Verify yq v4
  if ! command -v yq >/dev/null 2>&1; then
    printf '[furrow:error] normalize-todos: yq is required but not installed\n' >&2
    exit 1
  fi

  if ! yq --version 2>/dev/null | grep -qE 'v4\.'; then
    printf '[furrow:error] normalize-todos: yq v4 required (got: %s)\n' "$(yq --version 2>/dev/null || echo unknown)" >&2
    exit 1
  fi

  if [ ! -f "$TODOS_YAML" ]; then
    printf '[furrow:info] normalize-todos: %s not found, nothing to do\n' "$TODOS_YAML" >&2
    return 0
  fi

  _tmp="${TODOS_YAML}.normalize.$$"
  # shellcheck disable=SC2064
  trap "rm -f '$_tmp'" EXIT INT TERM

  # Sort by (created_at, id) and write to tmp
  LC_ALL=C yq -o=yaml 'sort_by(.created_at, .id)' "$TODOS_YAML" > "$_tmp" || {
    printf '[furrow:error] normalize-todos: yq sort failed\n' >&2
    rm -f "$_tmp"
    exit 1
  }

  # Atomic replace
  mv "$_tmp" "$TODOS_YAML"
  trap - EXIT INT TERM

  printf '[furrow:info] normalize-todos: sorted %s\n' "$TODOS_YAML" >&2
}

frw_normalize_todos "$@"
