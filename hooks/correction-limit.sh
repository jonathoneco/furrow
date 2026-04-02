#!/bin/sh
# correction-limit.sh — PreToolUse hook on Write|Edit
#
# Blocks writes to files owned by deliverables that have reached their
# correction limit during implementation.
#
# Reads JSON from stdin: {"tool_name":"Write|Edit","tool_input":{"file_path":"..."}}
#
# Exit codes:
#   0 — allowed
#   2 — blocked (correction limit reached, message on stderr)

set -eu

# --- read stdin and extract file_path ---

input="$(cat)"
file_path="$(printf '%s' "${input}" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)" || file_path=""

if [ -z "${file_path}" ]; then
  exit 0
fi

# --- locate active work unit (inline discovery, no common.sh) ---

work_dir=""
for state_file in .work/*/state.json; do
  [ -f "${state_file}" ] || continue
  archived="$(jq -r '.archived_at // "null"' "${state_file}" 2>/dev/null)" || continue
  if [ "${archived}" = "null" ]; then
    work_dir="$(dirname "${state_file}")"
    break
  fi
done

if [ -z "${work_dir}" ]; then
  exit 0
fi

# --- only enforce during implementation ---

step="$(jq -r '.step' "${work_dir}/state.json" 2>/dev/null)" || step=""
if [ "${step}" != "implement" ]; then
  exit 0
fi

# --- read correction limit from harness.yaml ---

limit=3
if [ -f ".claude/harness.yaml" ] && command -v yq > /dev/null 2>&1; then
  limit="$(yq -r '.defaults.correction_limit // 3' ".claude/harness.yaml" 2>/dev/null)" || limit=3
fi

# --- require plan.json to map files to deliverables ---

plan_file="${work_dir}/plan.json"
if [ ! -f "${plan_file}" ]; then
  exit 0
fi

# --- check each deliverable against the correction limit ---

deliverables="$(jq -r '.deliverables | keys[]' "${work_dir}/state.json" 2>/dev/null)" || deliverables=""

for deliverable in ${deliverables}; do
  corrections="$(jq -r --arg d "${deliverable}" '.deliverables[$d].corrections // 0' "${work_dir}/state.json" 2>/dev/null)" || corrections=0

  if [ "${corrections}" -lt "${limit}" ]; then
    continue
  fi

  # Deliverable is at or over the limit — check file ownership
  globs="$(jq -r --arg d "${deliverable}" '
    [.waves[].assignments[$d].file_ownership // empty] | flatten | .[]
  ' "${plan_file}" 2>/dev/null)" || globs=""

  for glob in ${globs}; do
    # shellcheck disable=SC2254
    case "${file_path}" in
      ${glob})
        echo "Correction limit (${limit}) reached for deliverable '${deliverable}'. Escalate to human for guidance." >&2
        exit 2
        ;;
    esac
  done
done

exit 0
