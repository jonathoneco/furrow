#!/bin/sh
# gate-precheck.sh — Structural pre-filter for gate evaluation
#
# Checks structural preconditions to determine if a step is eligible for
# pre-step evaluation. This is a hint, not a decision — the isolated
# subagent evaluator makes the actual triviality judgment.
#
# Usage: gate-precheck.sh <step> <definition_path> <state_path>
#   step            — current step name
#   definition_path — path to definition.yaml
#   state_path      — path to state.json
#
# Exit codes:
#   0 — structural preconditions met (evidence on stdout)
#   1 — structural preconditions NOT met

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
    # Research mode always needs research — never skip
    if [ "${mode}" = "research" ]; then
      exit 1
    fi
    # Single deliverable: no multi-deliverable coordination needed
    if [ "${deliv_count}" -ne 1 ]; then
      exit 1
    fi
    # ACs must reference file paths (require / to distinguish from method names)
    has_paths="$(yq -r '.deliverables[0].acceptance_criteria[]' "${def_path}" 2>/dev/null | grep -cE '/\w+' || true)"
    if [ "${has_paths}" -eq 0 ]; then
      exit 1
    fi
    # Context pointers must not reference directories (only specific files)
    has_dirs="$(yq -r '.context_pointers[].path' "${def_path}" 2>/dev/null | grep -cE '/$' || true)"
    if [ "${has_dirs}" -gt 0 ]; then
      exit 1
    fi
    first_file="$(yq -r '.deliverables[0].acceptance_criteria[0]' "${def_path}" 2>/dev/null | grep -oE '[^ ]*/\w+' | head -1)"
    echo "Single deliverable targeting known location (${first_file}); structural preconditions met for pre-step evaluation"
    exit 0
    ;;

  plan)
    # Single deliverable with no dependencies: no parallelism to plan
    if [ "${deliv_count}" -ne 1 ]; then
      exit 1
    fi
    deps="$(yq -r '.deliverables[0].depends_on | length' "${def_path}" 2>/dev/null)" || deps="0"
    if [ "${deps}" -gt 0 ]; then
      exit 1
    fi
    echo "Single deliverable, no dependencies -- structural preconditions met for pre-step evaluation"
    exit 0
    ;;

  spec)
    # Single deliverable with enough ACs to be structurally complete
    # Testability is judged by the evaluator, not regex — see evals/gates/spec.yaml
    if [ "${deliv_count}" -ne 1 ]; then
      exit 1
    fi
    ac_count="$(yq -r '.deliverables[0].acceptance_criteria | length' "${def_path}" 2>/dev/null)" || ac_count="0"
    if [ "${ac_count}" -lt 2 ]; then
      exit 1
    fi
    echo "Single deliverable with ${ac_count} acceptance criteria -- structural preconditions met for pre-step evaluation"
    exit 0
    ;;

  decompose)
    # Few deliverables, no dependencies, same specialist: single wave is obvious
    if [ "${deliv_count}" -gt 2 ]; then
      exit 1
    fi
    # No inter-deliverable dependencies
    has_deps="$(yq -r '[.deliverables[] | select(.depends_on != null and (.depends_on | length) > 0)] | length' "${def_path}" 2>/dev/null)" || has_deps="0"
    if [ "${has_deps}" -gt 0 ]; then
      exit 1
    fi
    # All deliverables use the same specialist type
    specialist_count="$(yq -r '[.deliverables[].specialist // "default"] | unique | length' "${def_path}" 2>/dev/null)" || specialist_count="1"
    if [ "${specialist_count}" -gt 1 ]; then
      exit 1
    fi
    echo "Single wave, ${deliv_count} deliverable(s), no dependencies -- structural preconditions met for pre-step evaluation"
    exit 0
    ;;

  *)
    exit 1
    ;;
esac
