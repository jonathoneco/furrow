#!/bin/sh
# append-learning.sh — Atomically append a validated learning to a JSONL file
#
# Usage: append-learning.sh <target_file> <source_task> <source_step> <category> <content> <context>
#
# Auto-generates: id (from last sequence number + 1), timestamp, promoted=false.
#
# Exit codes:
#   0 — success
#   1 — usage/validation error

set -eu

if [ "$#" -lt 6 ]; then
  echo "Usage: append-learning.sh <target_file> <source_task> <source_step> <category> <content> <context>" >&2
  exit 1
fi

target_file="$1"
source_task="$2"
source_step="$3"
category="$4"
content="$5"
context="$6"

# --- auto-generate sequence number ---

seq_num="001"
if [ -f "${target_file}" ]; then
  last_num="$(tail -1 "${target_file}" 2>/dev/null | jq -r '.id // ""' 2>/dev/null | grep -oE '[0-9]+$' || echo "0")"
  if [ -n "${last_num}" ]; then
    next_num=$((last_num + 1))
    seq_num="$(printf "%03d" "${next_num}")"
  fi
fi

id="${source_task}-${seq_num}"
now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- build JSON entry ---

entry="$(jq -n \
  --arg id "${id}" \
  --arg timestamp "${now}" \
  --arg category "${category}" \
  --arg content "${content}" \
  --arg context "${context}" \
  --arg source_task "${source_task}" \
  --arg source_step "${source_step}" \
  '{
    id: $id,
    timestamp: $timestamp,
    category: $category,
    content: $content,
    context: $context,
    source_task: $source_task,
    source_step: $source_step,
    promoted: false
  }'
)"

# --- validate ---

script_dir="$(cd "$(dirname "$0")" && pwd)"
echo "${entry}" | "${script_dir}/validate-learning.sh" || {
  echo "Entry failed validation, not appended." >&2
  exit 1
}

# --- atomic append ---

tmp_file="${target_file}.tmp.$$"

# Create parent directory if needed
mkdir -p "$(dirname "${target_file}")"

if [ -f "${target_file}" ]; then
  cp "${target_file}" "${tmp_file}"
else
  : > "${tmp_file}"
fi

# Append compacted JSON (single line)
echo "${entry}" | jq -c '.' >> "${tmp_file}"

mv "${tmp_file}" "${target_file}"

echo "Learning appended: ${id}"
