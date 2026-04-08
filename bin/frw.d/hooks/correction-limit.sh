# correction-limit.sh — PreToolUse hook on Write|Edit
#
# Hook: PreToolUse (matcher: Write|Edit)
# Blocks writes to files owned by deliverables that have reached their
# correction limit during implementation.
#
# Reads JSON from stdin: {"tool_name":"Write|Edit","tool_input":{"file_path":"..."}}
#
# Return codes:
#   0 — allowed
#   2 — blocked (correction limit reached, message on stderr)

hook_correction_limit() {
  input="$(cat)"
  file_path="$(printf '%s' "${input}" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)" || file_path=""

  if [ -z "${file_path}" ]; then
    return 0
  fi

  work_dir="$(extract_row_from_path "$file_path")"

  if [ -z "$work_dir" ]; then
    work_dir="$(find_focused_row)"
  fi

  if [ -z "$work_dir" ] || [ ! -f "$work_dir/state.json" ]; then
    return 0
  fi

  archived="$(jq -r '.archived_at // "null"' "$work_dir/state.json" 2>/dev/null)" || archived="null"
  if [ "$archived" != "null" ]; then
    return 0
  fi

  # --- only enforce during implementation ---

  step="$(jq -r '.step' "${work_dir}/state.json" 2>/dev/null)" || step=""
  if [ "${step}" != "implement" ]; then
    return 0
  fi

  # --- read correction limit from furrow.yaml ---

  limit=3
  _furrow_yaml=""
  for _candidate in .furrow/furrow.yaml .claude/furrow.yaml; do
    if [ -f "$_candidate" ]; then
      _furrow_yaml="$_candidate"
      break
    fi
  done
  if [ -n "$_furrow_yaml" ] && command -v yq > /dev/null 2>&1; then
    limit="$(yq -r '.defaults.correction_limit // 3' "$_furrow_yaml" 2>/dev/null)" || limit=3
  fi

  # --- require plan.json to map files to deliverables ---

  plan_file="${work_dir}/plan.json"
  if [ ! -f "${plan_file}" ]; then
    return 0
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
          return 2
          ;;
      esac
    done
  done

  return 0
}
