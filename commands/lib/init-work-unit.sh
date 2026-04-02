#!/bin/sh
# init-work-unit.sh — Initialize work unit directory and state.json
#
# Usage: init-work-unit.sh <name> [title] [description]
#   name        — kebab-case work unit name
#   title       — human-readable title (defaults to name)
#   description — one-sentence summary (defaults to title)
#
# Creates .work/{name}/ with a valid state.json.
# Does NOT overwrite existing work unit directories.
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — directory already exists

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: init-work-unit.sh <name> [title] [description]" >&2
  exit 1
fi

name="$1"
title="${2:-${name}}"
description="${3:-${title}}"

# --- validate name is kebab-case ---

if ! echo "${name}" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "Name must be kebab-case: '${name}'" >&2
  exit 1
fi

# --- check for existing directory ---

work_dir=".work/${name}"

if [ -d "${work_dir}" ]; then
  echo "Work unit already exists: ${work_dir}" >&2
  exit 2
fi

# --- gather metadata ---

base_commit="$(git rev-parse HEAD 2>/dev/null)" || base_commit="unknown"
now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- create directory ---

mkdir -p "${work_dir}"

# --- write state.json ---

tmp_file="${work_dir}/state.json.tmp.$$"

jq -n \
  --arg name "${name}" \
  --arg title "${title}" \
  --arg description "${description}" \
  --arg base_commit "${base_commit}" \
  --arg now "${now}" \
  '{
    name: $name,
    title: $title,
    description: $description,
    step: "ideate",
    step_status: "in_progress",
    steps_sequence: ["ideate","research","plan","spec","decompose","implement","review"],
    deliverables: {},
    gates: [],
    force_stop_at: null,
    branch: null,
    mode: "code",
    base_commit: $base_commit,
    epic_id: null,
    issue_id: null,
    created_at: $now,
    updated_at: $now,
    archived_at: null
  }' > "${tmp_file}"

mv "${tmp_file}" "${work_dir}/state.json"

echo "Work unit initialized: ${work_dir}"
