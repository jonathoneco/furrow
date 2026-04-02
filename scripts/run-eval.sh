#!/bin/sh
# run-eval.sh — Deterministic eval runner for deliverable review
#
# Usage: run-eval.sh <name> <deliverable>
#   name        — work unit name (kebab-case)
#   deliverable — deliverable name to evaluate
#
# Exit codes:
#   0 — pass (review result written)
#   1 — fail (review result written with failures)
#   2 — missing state/files

set -eu

# --- paths ---

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../hooks/lib/validate.sh
. "$HARNESS_ROOT/hooks/lib/validate.sh"

# --- argument validation ---

if [ $# -lt 2 ]; then
  echo "Usage: run-eval.sh <name> <deliverable>" >&2
  exit 1
fi

name="$1"
deliverable="$2"

work_dir="$HARNESS_ROOT/.work/${name}"
state_file="${work_dir}/state.json"
def_file="${work_dir}/definition.yaml"
plan_file="${work_dir}/plan.json"
reviews_dir="${work_dir}/reviews"

# --- prerequisite checks ---

if [ ! -f "$state_file" ]; then
  echo "Error: state.json not found: ${state_file}" >&2
  exit 2
fi

if [ ! -f "$def_file" ]; then
  echo "Error: definition.yaml not found: ${def_file}" >&2
  exit 2
fi

mode="$(jq -r '.mode // "code"' "$state_file")"
base_commit="$(jq -r '.base_commit // ""' "$state_file")"

# =====================================================================
# Phase A — Deterministic checks
# =====================================================================

# A1: Check deliverable exists in definition.yaml
del_exists="$(yq -r --arg d "$deliverable" \
  '[.deliverables[] | select(.name == $d)] | length' "$def_file")"

if [ "$del_exists" -eq 0 ]; then
  echo "Error: deliverable '${deliverable}' not found in definition.yaml" >&2
  exit 2
fi

# A2: Read file_ownership from plan.json (if it exists)
file_ownership="[]"
if [ -f "$plan_file" ]; then
  file_ownership="$(jq -r --arg d "$deliverable" '
    [.waves[].assignments[$d].file_ownership // []] | add // []
  ' "$plan_file")"
fi

# A3: Check owned files were actually modified
artifacts_present="false"
if [ "$mode" = "research" ]; then
  # Research mode: check .work/{name}/deliverables/ has files
  if [ -d "${work_dir}/deliverables" ]; then
    file_count="$(find "${work_dir}/deliverables" -maxdepth 1 -type f 2>/dev/null | wc -l)" || file_count="0"
    if [ "$file_count" -gt 0 ]; then
      artifacts_present="true"
    fi
  fi
else
  # Code mode: compare file_ownership globs against git diff
  if [ -n "$base_commit" ] && [ "$base_commit" != "null" ]; then
    changed_files="$(git diff --name-only "${base_commit}..HEAD" 2>/dev/null)" || changed_files=""
    if [ "$file_ownership" != "[]" ]; then
      glob_count="$(echo "$file_ownership" | jq -r '.[]' 2>/dev/null | wc -l)" || glob_count="0"
      if [ "$glob_count" -gt 0 ]; then
        matched="false"
        for glob_pattern in $(echo "$file_ownership" | jq -r '.[]' 2>/dev/null); do
          # Use git diff with pathspec to check if any owned files changed
          match_count="$(git diff --name-only "${base_commit}..HEAD" -- "$glob_pattern" 2>/dev/null | wc -l)" || match_count="0"
          if [ "$match_count" -gt 0 ]; then
            matched="true"
            break
          fi
        done
        artifacts_present="$matched"
      else
        # No globs defined but plan exists — check if any diff at all
        if [ -n "$changed_files" ]; then
          artifacts_present="true"
        fi
      fi
    else
      # No file_ownership and no plan — check if any diff at all
      if [ -n "$changed_files" ]; then
        artifacts_present="true"
      fi
    fi
  fi
fi

# A4: Read acceptance criteria from definition.yaml
ac_json="$(yq -o=json -r --arg d "$deliverable" \
  '[.deliverables[] | select(.name == $d) | .acceptance_criteria[]] // []' "$def_file")"

# A5: Build phase_a acceptance_criteria array and verdict
phase_a_ac="$(echo "$ac_json" | jq --argjson present "$artifacts_present" '
  [.[] | {
    criterion: .,
    met: $present,
    evidence: (if $present then "artifacts present" else "artifacts missing" end)
  }]
')"

phase_a_verdict="pass"
if [ "$artifacts_present" = "false" ]; then
  phase_a_verdict="fail"
fi

# Check each AC — if any are not met, fail
phase_a_check="$(echo "$phase_a_ac" | jq -r '[.[] | select(.met == false)] | length')"
if [ "$phase_a_check" -gt 0 ]; then
  phase_a_verdict="fail"
fi

# =====================================================================
# Phase B — Dimension evaluation
# =====================================================================

# B1: Get dimension file path
dim_path="$("$SCRIPT_DIR/select-dimensions.sh" "$name")" || {
  echo "Error: failed to select dimensions for '${name}'" >&2
  exit 2
}

# B2: Read dimensions from YAML
dim_names="$(yq -r '.dimensions[].name' "$dim_path")"

# B3: Evaluate each dimension
phase_b_dims="[]"
phase_b_verdict="pass"

# Gather git diff data once for reuse
owned_diff_files=""
all_diff_files=""
if [ "$mode" = "code" ] && [ -n "$base_commit" ] && [ "$base_commit" != "null" ]; then
  all_diff_files="$(git diff --name-only "${base_commit}..HEAD" 2>/dev/null)" || all_diff_files=""

  if [ "$file_ownership" != "[]" ]; then
    for glob_pattern in $(echo "$file_ownership" | jq -r '.[]' 2>/dev/null); do
      matches="$(git diff --name-only "${base_commit}..HEAD" -- "$glob_pattern" 2>/dev/null)" || matches=""
      owned_diff_files="$(printf '%s\n%s' "$owned_diff_files" "$matches")"
    done
    owned_diff_files="$(echo "$owned_diff_files" | sed '/^$/d' | sort -u)"
  fi
fi

for dim in $dim_names; do
  verdict="skipped"
  evidence="requires evaluator"

  case "$dim" in
    correctness)
      # Check git diff non-empty for owned files
      if [ "$mode" = "code" ]; then
        if [ -n "$owned_diff_files" ]; then
          verdict="pass"
          evidence="owned files have changes"
        elif [ -n "$all_diff_files" ] && [ "$file_ownership" = "[]" ]; then
          verdict="pass"
          evidence="changes detected (no file_ownership defined)"
        else
          verdict="fail"
          evidence="no changes detected for owned files"
          phase_b_verdict="fail"
        fi
      else
        if [ "$artifacts_present" = "true" ]; then
          verdict="pass"
          evidence="deliverable artifacts present"
        else
          verdict="fail"
          evidence="no deliverable artifacts found"
          phase_b_verdict="fail"
        fi
      fi
      ;;

    test-coverage)
      # Check if test files exist in file_ownership patterns
      has_tests="false"
      if [ "$file_ownership" != "[]" ]; then
        for glob_pattern in $(echo "$file_ownership" | jq -r '.[]' 2>/dev/null); do
          case "$glob_pattern" in
            *test*|*Test*|*spec*|*Spec*)
              has_tests="true"
              break
              ;;
          esac
        done
      fi
      if [ "$has_tests" = "true" ]; then
        verdict="pass"
        evidence="test file patterns found in file_ownership"
      else
        verdict="fail"
        evidence="no test file patterns in file_ownership"
        phase_b_verdict="fail"
      fi
      ;;

    unplanned-changes)
      # Compare git diff files against file_ownership globs
      if [ "$mode" = "code" ] && [ -n "$all_diff_files" ] && [ "$file_ownership" != "[]" ]; then
        # Collect all files matching ownership globs
        all_owned=""
        for glob_pattern in $(echo "$file_ownership" | jq -r '.[]' 2>/dev/null); do
          matches="$(git diff --name-only "${base_commit}..HEAD" -- "$glob_pattern" 2>/dev/null)" || matches=""
          all_owned="$(printf '%s\n%s' "$all_owned" "$matches")"
        done
        all_owned="$(echo "$all_owned" | sed '/^$/d' | sort -u)"

        # Find files in diff but not in owned set (exclude .work/ files)
        unplanned=""
        for f in $all_diff_files; do
          case "$f" in
            .work/*) continue ;;
          esac
          in_owned="false"
          for o in $all_owned; do
            if [ "$f" = "$o" ]; then
              in_owned="true"
              break
            fi
          done
          if [ "$in_owned" = "false" ]; then
            unplanned="${unplanned:+${unplanned}, }${f}"
          fi
        done

        if [ -z "$unplanned" ]; then
          verdict="pass"
          evidence="all changed files within file_ownership"
        else
          verdict="fail"
          evidence="unplanned files: ${unplanned}"
          phase_b_verdict="fail"
        fi
      else
        verdict="pass"
        evidence="no file_ownership defined or no diff to compare"
      fi
      ;;

    spec-compliance)
      # Check owned files modified
      if [ "$mode" = "code" ]; then
        if [ -n "$owned_diff_files" ]; then
          verdict="pass"
          evidence="owned files modified per spec"
        elif [ -n "$all_diff_files" ] && [ "$file_ownership" = "[]" ]; then
          verdict="pass"
          evidence="changes detected (no file_ownership defined)"
        else
          verdict="fail"
          evidence="no owned files modified"
          phase_b_verdict="fail"
        fi
      else
        if [ "$artifacts_present" = "true" ]; then
          verdict="pass"
          evidence="deliverable artifacts present"
        else
          verdict="fail"
          evidence="no deliverable artifacts found"
          phase_b_verdict="fail"
        fi
      fi
      ;;

    *)
      # All other dimensions: skip for deterministic eval
      verdict="skipped"
      evidence="requires evaluator"
      ;;
  esac

  # Append dimension result
  phase_b_dims="$(echo "$phase_b_dims" | jq \
    --arg name "$dim" \
    --arg verdict "$verdict" \
    --arg evidence "$evidence" \
    '. + [{name: $name, verdict: $verdict, evidence: $evidence}]')"
done

# =====================================================================
# Compose review result
# =====================================================================

overall="pass"
if [ "$phase_a_verdict" != "pass" ] || [ "$phase_b_verdict" != "pass" ]; then
  overall="fail"
fi

now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "$reviews_dir"
tmp_file="${reviews_dir}/${deliverable}.json.tmp.$$"

jq -n \
  --arg deliverable "$deliverable" \
  --argjson artifacts_present "$artifacts_present" \
  --argjson acceptance_criteria "$phase_a_ac" \
  --arg phase_a_verdict "$phase_a_verdict" \
  --argjson dimensions "$phase_b_dims" \
  --arg phase_b_verdict "$phase_b_verdict" \
  --arg overall "$overall" \
  --arg timestamp "$now" \
  '{
    deliverable: $deliverable,
    phase_a: {
      artifacts_present: $artifacts_present,
      acceptance_criteria: $acceptance_criteria,
      plan_completion: {},
      verdict: $phase_a_verdict
    },
    phase_b: {
      dimensions: $dimensions,
      verdict: $phase_b_verdict
    },
    overall: $overall,
    corrections: 0,
    reviewer: "run-eval",
    cross_model: false,
    timestamp: $timestamp
  }' > "$tmp_file"

# Atomic write
mv "$tmp_file" "${reviews_dir}/${deliverable}.json"

echo "Review written: ${reviews_dir}/${deliverable}.json" >&2

# --- gate evaluation ---

gate_output="$("$SCRIPT_DIR/evaluate-gate.sh" "$name" "implement->review" "$overall")"
echo "$gate_output"

# --- exit code ---

if [ "$overall" = "pass" ]; then
  exit 0
else
  exit 1
fi
