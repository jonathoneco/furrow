#!/bin/sh
# init-row.sh — Create the directory structure for a new row
#
#
# Usage: init-row.sh <name> <description>
#   name        — kebab-case identifier (e.g., add-rate-limiting)
#   description — one-sentence summary of the row

set -eu

# --- argument validation ---

if [ "$#" -lt 2 ]; then
  echo "Usage: init-row.sh <name> <description>" >&2
  exit 1
fi

name="$1"
description="$2"

# --- validate kebab-case naming ---

if ! echo "${name}" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
  echo "Invalid name: must be kebab-case (e.g., add-rate-limiting)" >&2
  exit 1
fi

# --- check for duplicates ---

work_dir=".furrow/rows/${name}"

if [ -d "${work_dir}" ]; then
  echo "Row '${name}' already exists. Use reground to resume." >&2
  exit 1
fi

# --- capture base commit ---

base_commit="$(git rev-parse HEAD 2>/dev/null || echo "unknown")"

# --- create directory structure ---

mkdir -p "${work_dir}/reviews"

# --- generate timestamps ---

now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- create state.json (atomic: temp file + move) ---

tmp_state="${work_dir}/state.json.tmp.$$"
trap 'rm -f "${tmp_state}"' EXIT

jq -n \
  --arg name "${name}" \
  --arg description "${description}" \
  --arg base_commit "${base_commit}" \
  --arg now "${now}" \
  '{
    name: $name,
    title: "",
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
  }' > "${tmp_state}"

mv "${tmp_state}" "${work_dir}/state.json"

# --- copy _meta.yaml template if not present ---

meta_dir=".furrow"
if [ ! -f "${meta_dir}/_meta.yaml" ]; then
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  furrow_root="$(cd "${script_dir}/.." && pwd)"
  meta_template="${furrow_root}/references/row-meta.yaml"
  if [ -f "${meta_template}" ]; then
    cp "${meta_template}" "${meta_dir}/_meta.yaml"
  fi
fi

# --- output ---

echo "${work_dir}"
