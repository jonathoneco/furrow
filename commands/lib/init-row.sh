#!/bin/sh
# init-row.sh — Initialize row directory and state.json
#
# Usage: init-row.sh <name> [--title <title>] [--description <desc>]
#                            [--mode code|research]
#                            [--gate-policy supervised|delegated|autonomous]
#                            [--source-todo <todo-id>]
#
#   name          — kebab-case row name (positional, required)
#   --title       — human-readable title (defaults to name)
#   --description — one-sentence summary (defaults to title)
#   --mode        — work mode (defaults from furrow.yaml or "code")
#   --gate-policy — trust level hint (defaults from furrow.yaml or "supervised")
#   --source-todo — TODO entry ID this row was created from
#
# Creates .furrow/rows/{name}/ with a valid state.json and reviews/ directory.
# Does NOT overwrite existing row directories.
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — directory already exists

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: init-row.sh <name> [--title <t>] [--description <d>] [--mode code|research] [--gate-policy supervised|delegated|autonomous]" >&2
  exit 1
fi

name="$1"
shift

# --- parse named flags ---

title=""
description=""
mode=""
gate_policy=""
source_todo=""

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
    --source-todo)
      source_todo="${2:-}"
      shift 2 || { echo "Missing value for --source-todo" >&2; exit 1; }
      if ! echo "${source_todo}" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
        echo "Invalid source-todo: must be kebab-case: '${source_todo}'" >&2
        exit 1
      fi
      ;;
    *)
      # Support legacy positional args: init-row.sh <name> [title] [description]
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

# Read defaults from furrow.yaml if flags not provided
_furrow_yaml=".claude/furrow.yaml"
if [ -z "${mode}" ]; then
  if [ -f "${_furrow_yaml}" ] && command -v yq > /dev/null 2>&1; then
    mode="$(yq -r '.defaults.mode // "code"' "${_furrow_yaml}" 2>/dev/null)" || mode="code"
  else
    mode="code"
  fi
fi
if [ -z "${gate_policy}" ]; then
  if [ -f "${_furrow_yaml}" ] && command -v yq > /dev/null 2>&1; then
    gate_policy="$(yq -r '.defaults.gate_policy // "supervised"' "${_furrow_yaml}" 2>/dev/null)" || gate_policy="supervised"
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

work_dir=".furrow/rows/${name}"

if [ -d "${work_dir}" ]; then
  echo "Row already exists: ${work_dir}" >&2
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
  --arg source_todo "${source_todo}" \
  --arg gate_policy_init "${gate_policy}" \
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
    archived_at: null,
    source_todo: (if $source_todo == "" then null else $source_todo end),
    gate_policy_init: (if $gate_policy_init == "" then null else $gate_policy_init end)
  }' > "${tmp_file}"

mv "${tmp_file}" "${work_dir}/state.json"

echo "Row initialized: ${work_dir}"
