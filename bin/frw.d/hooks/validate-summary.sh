# validate-summary.sh — Validate summary.md at step boundaries
#
# Hook: Stop (matcher: empty)
# Checks summary.md has all required sections and
# agent-written sections have minimum content.
#
# Skips validation for auto-advanced steps.
#
# Return codes:
#   0 — valid (or no active row, or auto-advanced)
#   2 — validation failure (blocking)

hook_validate_summary() {
  # Optional step argument for step-aware validation (called from rws transition)
  step_arg="${1:-}"

  work_dir="$(find_focused_row)"

  if [ -z "${work_dir}" ]; then
    return 0
  fi

  state_file="${work_dir}/state.json"
  summary_file="${work_dir}/summary.md"

  # --- skip if no summary exists yet ---

  if [ ! -f "${summary_file}" ]; then
    return 0
  fi

  # --- skip if last gate was prechecked (pre-step evaluation skipped the step) ---

  last_decided="$(jq -r '.gates | last | .decided_by // ""' "${state_file}" 2>/dev/null)" || last_decided=""
  if [ "${last_decided}" = "prechecked" ]; then
    return 0
  fi

  # --- check required sections ---

  errors=""

  for section in "Task" "Current State" "Artifact Paths" "Settled Decisions" "Key Findings" "Open Questions" "Recommendations"; do
    if ! grep -q "^## ${section}" "${summary_file}"; then
      errors="${errors}Missing section: ${section}\n"
    fi
  done

  # --- check agent-written sections have >= 1 non-empty line ---

  for section in "Key Findings" "Open Questions" "Recommendations"; do
    # Step-aware: ideate only requires Open Questions
    if [ "${step_arg}" = "ideate" ] && [ "${section}" != "Open Questions" ]; then
      continue
    fi

    content="$(awk -v sec="${section}" '
      $0 ~ "^## " sec { found=1; next }
      /^## / { if(found) exit }
      found && /[^ ]/ { count++ }
      END { print count+0 }
    ' "${summary_file}")"

    if [ "${content}" -lt 1 ]; then
      errors="${errors}Section '${section}' needs at least 1 non-empty line (has ${content}).\n"
    fi
  done

  # --- report ---

  if [ -n "${errors}" ]; then
    printf "summary.md validation failed:\n%b" "${errors}" >&2
    return 2
  fi

  return 0
}
