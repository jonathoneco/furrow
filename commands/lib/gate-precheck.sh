#!/bin/sh
# auto-advance.sh — Auto-advance detection for trivially resolved steps
#
# Usage: auto-advance.sh <step> <definition_path> <state_path>
#   step            — current step name
#   definition_path — path to definition.yaml
#   state_path      — path to state.json
#
# Exit codes:
#   0 — should auto-advance (evidence on stdout)
#   1 — should NOT auto-advance

set -eu

if [ "$#" -lt 3 ]; then
  echo "Usage: auto-advance.sh <step> <definition_path> <state_path>" >&2
  exit 1
fi

step="$1"
def_path="$2"
state_path="$3"

# --- global exclusions ---

# Ideate, implement, and review never auto-advance
case "${step}" in
  ideate|implement|review) exit 1 ;;
esac

# Supervised mode disables all auto-advance
gate_policy="$(yq -r '.gate_policy // "supervised"' "${def_path}" 2>/dev/null)" || gate_policy="supervised"
if [ "${gate_policy}" = "supervised" ]; then
  exit 1
fi

# force_stop_at overrides auto-advance
force_stop="$(jq -r '.force_stop_at // ""' "${state_path}" 2>/dev/null)" || force_stop=""
if [ "${force_stop}" = "${step}" ]; then
  exit 1
fi

# --- per-step criteria ---

deliv_count="$(yq -r '.deliverables | length' "${def_path}" 2>/dev/null)" || deliv_count="0"
mode="$(jq -r '.mode // "code"' "${state_path}" 2>/dev/null)" || mode="code"
case "${mode}" in
  code|research) ;;
  *) echo "Warning: invalid mode '${mode}', defaulting to 'code'" >&2; mode="code" ;;
esac

case "${step}" in
  research)
    # Never auto-advance research in research mode
    if [ "${mode}" = "research" ]; then
      exit 1
    fi
    # Must be exactly 1 deliverable
    if [ "${deliv_count}" -ne 1 ]; then
      exit 1
    fi
    # Acceptance criteria must reference specific files (path-like strings)
    has_paths="$(yq -r '.deliverables[0].acceptance_criteria[]' "${def_path}" 2>/dev/null | grep -cE '[/.]\w+' || true)"
    if [ "${has_paths}" -eq 0 ]; then
      exit 1
    fi
    # Context pointers must not reference directories (only files)
    has_dirs="$(yq -r '.context_pointers[].path' "${def_path}" 2>/dev/null | grep -cE '/$' || true)"
    if [ "${has_dirs}" -gt 0 ]; then
      exit 1
    fi
    first_file="$(yq -r '.deliverables[0].acceptance_criteria[0]' "${def_path}" 2>/dev/null | grep -oE '[^ ]*[/.]\w+' | head -1)"
    echo "Single deliverable targeting known location (${first_file}); no architectural unknowns"
    exit 0
    ;;

  plan)
    if [ "${deliv_count}" -ne 1 ]; then
      exit 1
    fi
    deps="$(yq -r '.deliverables[0].depends_on | length' "${def_path}" 2>/dev/null)" || deps="0"
    if [ "${deps}" -gt 0 ]; then
      exit 1
    fi
    echo "Single deliverable, no dependencies, no parallelism -- plan adds no information beyond definition"
    exit 0
    ;;

  spec)
    if [ "${deliv_count}" -ne 1 ]; then
      exit 1
    fi
    ac_count="$(yq -r '.deliverables[0].acceptance_criteria | length' "${def_path}" 2>/dev/null)" || ac_count="0"
    if [ "${ac_count}" -lt 2 ]; then
      exit 1
    fi
    # Check if criteria are testable (contain action verbs, numbers, or paths)
    testable="$(yq -r '.deliverables[0].acceptance_criteria[]' "${def_path}" 2>/dev/null | grep -ciE '(returns|enforces|validates|creates|contains|must|shall|[0-9]+|[/.]\w+)' || true)"
    if [ "${testable}" -lt "${ac_count}" ]; then
      exit 1
    fi
    echo "Single deliverable with ${ac_count} testable acceptance criteria; spec adds no refinement beyond definition"
    exit 0
    ;;

  decompose)
    if [ "${deliv_count}" -gt 2 ]; then
      exit 1
    fi
    # Check if all deliverables have no depends_on
    has_deps="$(yq -r '[.deliverables[] | select(.depends_on != null and (.depends_on | length) > 0)] | length' "${def_path}" 2>/dev/null)" || has_deps="0"
    if [ "${has_deps}" -gt 0 ]; then
      exit 1
    fi
    # Check specialist diversity
    specialist_count="$(yq -r '[.deliverables[].specialist // "default"] | unique | length' "${def_path}" 2>/dev/null)" || specialist_count="1"
    if [ "${specialist_count}" -gt 1 ]; then
      exit 1
    fi
    echo "Single wave, ${deliv_count} deliverable(s), no dependency ordering needed -- decomposition is trivial"
    exit 0
    ;;

  *)
    exit 1
    ;;
esac
