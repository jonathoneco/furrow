#!/bin/sh
# init-work-unit.sh — Initialize work unit directory and state.json
#
# Usage: init-work-unit.sh <name> [--title <title>] [--description <desc>]
#                                 [--mode code|research]
#                                 [--gate-policy supervised|delegated|autonomous]
#
#   name          — kebab-case work unit name (positional, required)
#   --title       — human-readable title (defaults to name)
#   --description — one-sentence summary (defaults to title)
#   --mode        — work mode (defaults from harness.yaml or "code")
#   --gate-policy — trust level hint (defaults from harness.yaml or "supervised")
#
# Creates .work/{name}/ with a valid state.json and reviews/ directory.
# Writes .gate_policy_hint if --gate-policy is provided.
# Does NOT overwrite existing work unit directories.
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — directory already exists

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: init-work-unit.sh <name> [--title <t>] [--description <d>] [--mode code|research] [--gate-policy supervised|delegated|autonomous]" >&2
  exit 1
fi

name="$1"
shift

# --- parse named flags ---

title=""
description=""
mode=""
gate_policy=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --title)
      title="${2:-}"
      shift 2 || { echo "Missing value for --title" >&2; exit 1; }
      ;;
    --description)
      description="${2:-}"
      shift 2 || { echo "Missing value for --description" >&2; exit 1; }
      ;;
    --mode)
      mode="${2:-}"
      shift 2 || { echo "Missing value for --mode" >&2; exit 1; }
      case "${mode}" in
        code|research) ;;
        *) echo "Invalid mode: '${mode}'. Must be code or research." >&2; exit 1 ;;
      esac
      ;;
    --gate-policy)
      gate_policy="${2:-}"
      shift 2 || { echo "Missing value for --gate-policy" >&2; exit 1; }
      case "${gate_policy}" in
        supervised|delegated|autonomous) ;;
        *) echo "Invalid gate-policy: '${gate_policy}'. Must be supervised, delegated, or autonomous." >&2; exit 1 ;;
      esac
      ;;
    *)
      # Support legacy positional args: init-work-unit.sh <name> [title] [description]
      if [ -z "${title}" ]; then
        title="$1"
      elif [ -z "${description}" ]; then
        description="$1"
      else
        echo "Unknown argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# --- apply defaults ---

title="${title:-${name}}"
description="${description:-${title}}"

# Read defaults from harness.yaml if flags not provided
_harness_yaml=".claude/harness.yaml"
if [ -z "${mode}" ]; then
  if [ -f "${_harness_yaml}" ] && command -v yq > /dev/null 2>&1; then
    mode="$(yq -r '.defaults.mode // "code"' "${_harness_yaml}" 2>/dev/null)" || mode="code"
  else
    mode="code"
  fi
fi
if [ -z "${gate_policy}" ]; then
  if [ -f "${_harness_yaml}" ] && command -v yq > /dev/null 2>&1; then
    gate_policy="$(yq -r '.defaults.gate_policy // "supervised"' "${_harness_yaml}" 2>/dev/null)" || gate_policy="supervised"
  else
    gate_policy="supervised"
  fi
fi

# --- validate name is kebab-case ---

if ! echo "${name}" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
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

# --- create directory with reviews/ ---

mkdir -p "${work_dir}/reviews"

# --- write state.json ---

tmp_file="${work_dir}/state.json.tmp.$$"
trap 'rm -f "${tmp_file}"' EXIT

jq -n \
  --arg name "${name}" \
  --arg title "${title}" \
  --arg description "${description}" \
  --arg mode "${mode}" \
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
    mode: $mode,
    base_commit: $base_commit,
    epic_id: null,
    issue_id: null,
    created_at: $now,
    updated_at: $now,
    archived_at: null
  }' > "${tmp_file}"

mv "${tmp_file}" "${work_dir}/state.json"

# --- write gate policy hint ---

if [ -n "${gate_policy}" ]; then
  echo "${gate_policy}" > "${work_dir}/.gate_policy_hint"
fi

echo "Work unit initialized: ${work_dir}"
