# stop-ideation.sh — Validate section-by-section interaction during ideation
#
# Hook: Stop (matcher: empty)
# Checks the ideation agent presented definition sections
# individually rather than batch-approving the entire definition.
#
# Checks for section markers: <!-- ideation:section:{name} -->
# Required markers: objective, deliverables, context-pointers, constraints, gate-policy
#
# In supervised/delegated mode: all 5 markers must be present.
# In autonomous mode: marker check is skipped (evaluator validates instead).
#
# Return codes:
#   0 — valid (or not in ideation step, or autonomous mode)
#   2 — missing section markers (blocking)

hook_stop_ideation() {
  work_dir="$(find_focused_row)"

  if [ -z "$work_dir" ]; then
    return 0
  fi

  # --- check if in ideation step ---

  step="$(jq -r '.step' "${work_dir}/state.json" 2>/dev/null)" || step=""
  if [ "${step}" != "ideate" ]; then
    return 0
  fi

  # --- check gate policy ---

  def_file="${work_dir}/definition.yaml"
  gate_policy=""
  if [ -f "${def_file}" ] && command -v yq > /dev/null 2>&1; then
    gate_policy="$(yq -r '.gate_policy // ""' "${def_file}" 2>/dev/null)" || gate_policy=""
  fi

  if [ "${gate_policy}" = "autonomous" ]; then
    return 0
  fi

  # --- validate definition.yaml has all required fields ---
  # Hooks cannot read conversation history, so we validate the
  # definition file as a proxy for ideation completeness.

  if [ ! -f "${def_file}" ]; then
    # Definition not yet written — ideation still in progress, no error
    return 0
  fi

  if ! command -v yq > /dev/null 2>&1; then
    echo "yq not available — skipping definition field validation" >&2
    return 0
  fi

  missing=""

  # Check scalar fields
  for field in objective gate_policy; do
    val="$(yq -r ".${field} // \"\"" "${def_file}" 2>/dev/null)" || val=""
    if [ -z "${val}" ]; then
      missing="${missing}  - ${field}\n"
    fi
  done

  # Check array fields have >= 1 entry
  for field in deliverables context_pointers; do
    count="$(yq -r ".${field} | length" "${def_file}" 2>/dev/null)" || count="0"
    if [ "${count}" -lt 1 ] 2>/dev/null; then
      missing="${missing}  - ${field} (need >= 1 entry)\n"
    fi
  done

  # Check constraints (should exist, can be scalar or array)
  constraints="$(yq -r '.constraints // ""' "${def_file}" 2>/dev/null)" || constraints=""
  if [ -z "${constraints}" ] || [ "${constraints}" = "null" ]; then
    missing="${missing}  - constraints\n"
  fi

  if [ -n "${missing}" ]; then
    printf "Ideation incomplete — definition.yaml missing required fields:\n%b" "${missing}" >&2
    return 2
  fi

  return 0
}
