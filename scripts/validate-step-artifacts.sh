#!/bin/sh
# validate-step-artifacts.sh — Deterministic artifact checks at step boundaries
#
# Usage: validate-step-artifacts.sh <name> <boundary>
#   name     — work unit name (kebab-case)
#   boundary — step boundary (e.g., "research->plan")
#
# Exit codes:
#   0 — artifacts valid
#   2 — state.json not found
#   3 — validation failed (details on stderr)

set -eu

# --- argument validation ---

if [ "$#" -lt 2 ]; then
  echo "Usage: validate-step-artifacts.sh <name> <boundary>" >&2
  exit 1
fi

name="$1"
boundary="$2"

# --- resolve harness root and source libraries ---

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../hooks/lib/validate.sh
. "$HARNESS_ROOT/hooks/lib/validate.sh"

# shellcheck source=../hooks/lib/common.sh
. "$HARNESS_ROOT/hooks/lib/common.sh"

# --- locate state ---

work_dir=".work/${name}"
state_file="${work_dir}/state.json"
def_file="${work_dir}/definition.yaml"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

# --- helper: count deliverables from definition.yaml ---

deliverable_count() {
  if [ -f "${def_file}" ] && command -v yq > /dev/null 2>&1; then
    yq -r '.deliverables | length' "${def_file}" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# --- helper: fail with message ---

fail() {
  echo "$1" >&2
  exit 3
}

# --- boundary validation ---

case "${boundary}" in

  "research->plan")
    # research.md OR research/synthesis.md must exist, be non-empty, and contain >= 1 ## heading
    research_file=""
    if [ -f "${work_dir}/research.md" ]; then
      research_file="${work_dir}/research.md"
    elif [ -f "${work_dir}/research/synthesis.md" ]; then
      research_file="${work_dir}/research/synthesis.md"
    fi

    if [ -z "${research_file}" ]; then
      fail "research->plan: neither ${work_dir}/research.md nor ${work_dir}/research/synthesis.md exists"
    fi

    if [ ! -s "${research_file}" ]; then
      fail "research->plan: ${research_file} is empty"
    fi

    heading_count="$(grep -c '^## ' "${research_file}" 2>/dev/null)" || heading_count="0"
    if [ "${heading_count}" -eq 0 ]; then
      fail "research->plan: ${research_file} contains no ## headings"
    fi
    ;;

  "plan->spec")
    # If deliverable count > 1: plan.json must exist and pass validation
    count="$(deliverable_count)"
    if [ "${count}" -gt 1 ]; then
      plan_file="${work_dir}/plan.json"
      if [ ! -f "${plan_file}" ]; then
        fail "plan->spec: ${plan_file} required (${count} deliverables) but not found"
      fi
      if ! validate_plan_json "${plan_file}" "${def_file}"; then
        fail "plan->spec: ${plan_file} failed validation"
      fi
    fi
    ;;

  "spec->decompose")
    # spec.md exists OR specs/ directory has >= 1 .md file
    has_spec=0
    if [ -f "${work_dir}/spec.md" ]; then
      has_spec=1
    elif [ -d "${work_dir}/specs" ]; then
      md_count="$(find "${work_dir}/specs" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l)" || md_count="0"
      if [ "${md_count}" -gt 0 ]; then
        has_spec=1
      fi
    fi

    if [ "${has_spec}" -eq 0 ]; then
      fail "spec->decompose: neither ${work_dir}/spec.md nor ${work_dir}/specs/*.md found"
    fi

    # If deliverable count > 1: specs dir must have a .md file for each deliverable name
    count="$(deliverable_count)"
    if [ "${count}" -gt 1 ]; then
      if [ ! -d "${work_dir}/specs" ]; then
        fail "spec->decompose: ${work_dir}/specs/ directory required for ${count} deliverables"
      fi
      missing=""
      for del_name in $(yq -r '.deliverables[].name' "${def_file}" 2>/dev/null); do
        if [ ! -f "${work_dir}/specs/${del_name}.md" ]; then
          missing="${missing} ${del_name}"
        fi
      done
      if [ -n "${missing}" ]; then
        fail "spec->decompose: missing spec files for deliverables:${missing}"
      fi
    fi
    ;;

  "decompose->implement")
    # plan.json must exist and be valid
    plan_file="${work_dir}/plan.json"
    if [ ! -f "${plan_file}" ]; then
      fail "decompose->implement: ${plan_file} not found"
    fi
    if ! validate_plan_json "${plan_file}" "${def_file}"; then
      fail "decompose->implement: ${plan_file} failed validation"
    fi

    # branch field must be non-null and non-empty
    branch="$(jq -r '.branch // ""' "${state_file}" 2>/dev/null)" || branch=""
    if [ -z "${branch}" ] || [ "${branch}" = "null" ]; then
      fail "decompose->implement: state.json 'branch' field is not set"
    fi
    ;;

  "implement->review")
    # Check mode from state.json
    mode="$(jq -r '.mode' "${state_file}" 2>/dev/null)" || mode=""

    if [ "${mode}" = "code" ]; then
      base_commit="$(jq -r '.base_commit' "${state_file}" 2>/dev/null)" || base_commit=""
      if [ -z "${base_commit}" ] || [ "${base_commit}" = "null" ]; then
        fail "implement->review: state.json 'base_commit' field is not set"
      fi
      diff_stat="$(git diff --stat "${base_commit}"..HEAD 2>/dev/null)" || diff_stat=""
      if [ -z "${diff_stat}" ]; then
        fail "implement->review: no changes detected since base commit ${base_commit}"
      fi
    elif [ "${mode}" = "research" ]; then
      if [ ! -d "${work_dir}/deliverables" ]; then
        fail "implement->review: ${work_dir}/deliverables/ directory not found"
      fi
      non_empty_count=0
      for f in "${work_dir}"/deliverables/*; do
        [ -f "$f" ] || continue
        if [ -s "$f" ]; then
          non_empty_count=$((non_empty_count + 1))
        fi
      done
      if [ "${non_empty_count}" -eq 0 ]; then
        fail "implement->review: no non-empty files in ${work_dir}/deliverables/"
      fi
    fi
    ;;

  "review->archive")
    # Each deliverable in state.json must have a matching review .json file with "overall": "pass"
    if [ ! -d "${work_dir}/reviews" ]; then
      fail "review->archive: ${work_dir}/reviews/ directory not found"
    fi

    # Get deliverable names from state.json deliverables map
    del_names="$(jq -r '.deliverables | keys[]' "${state_file}" 2>/dev/null)" || del_names=""
    if [ -z "${del_names}" ]; then
      fail "review->archive: no deliverables found in state.json"
    fi

    for del_name in ${del_names}; do
      review_file="${work_dir}/reviews/${del_name}.json"
      if [ ! -f "${review_file}" ]; then
        fail "review->archive: missing review file for deliverable '${del_name}'"
      fi
      overall="$(jq -r '.overall' "${review_file}" 2>/dev/null)" || overall=""
      if [ "${overall}" != "pass" ]; then
        fail "review->archive: deliverable '${del_name}' review has overall='${overall}', expected 'pass'"
      fi
    done
    ;;

  *)
    echo "Unknown boundary: ${boundary}" >&2
    exit 3
    ;;

esac

exit 0
