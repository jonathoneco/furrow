#!/bin/sh
# detect-context.sh — Scan .work/ for active tasks (archived_at is null).
# Output: one task name per line. Exit 0 with count on stderr.
# Usage: active=$(commands/lib/detect-context.sh)
set -eu

WORK_DIR=".work"

# No .work directory
if [ ! -d "$WORK_DIR" ]; then
  echo "0" >&2
  exit 0
fi

count=0
for state_file in "$WORK_DIR"/*/state.json; do
  # Handle glob with no matches
  [ -f "$state_file" ] || continue

  # Skip files that are not valid JSON
  if ! archived_at=$(jq -r '.archived_at // "null"' "$state_file" 2>/dev/null); then
    continue
  fi

  # Active task: archived_at is null or the literal string "null"
  if [ "$archived_at" = "null" ]; then
    task_name=$(jq -r '.name // empty' "$state_file" 2>/dev/null) || continue
    if [ -n "$task_name" ]; then
      echo "$task_name"
      count=$((count + 1))
    fi
  fi
done

echo "$count" >&2
exit 0
