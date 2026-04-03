#!/bin/sh
# check-artifacts.sh — Phase A deterministic artifact checks for deliverable review
#
# Usage: frw check-artifacts <name> <deliverable>
#   name        — row name (kebab-case)
#   deliverable — deliverable name to evaluate
#
# Return codes:
#   0 — pass (review result written)
#   1 — fail (review result written with failures)
#   2 — missing state/files

frw_check_artifacts() {
  set -eu

  . "$FURROW_ROOT/bin/frw.d/lib/validate.sh"

  # --- temp file registry for cleanup ---
  _eval_tmpdir="$(mktemp -d)"
  trap 'rm -rf "$_eval_tmpdir"' EXIT

  # --- argument validation ---

  if [ $# -lt 2 ]; then
    echo "Usage: frw check-artifacts <name> <deliverable>" >&2
    return 2
  fi

  name="$1"
  deliverable="$2"

  work_dir="$FURROW_ROOT/.furrow/rows/${name}"
  state_file="${work_dir}/state.json"
  def_file="${work_dir}/definition.yaml"
  plan_file="${work_dir}/plan.json"
  reviews_dir="${work_dir}/reviews"

  # --- prerequisite checks ---

  if [ ! -f "$state_file" ]; then
    echo "Error: state.json not found: ${state_file}" >&2
    return 2
  fi

  if [ ! -f "$def_file" ]; then
    echo "Error: definition.yaml not found: ${def_file}" >&2
    return 2
  fi

  mode="$(jq -r '.mode // "code"' "$state_file")"
  base_commit="$(jq -r '.base_commit // ""' "$state_file")"

  # =====================================================================
  # Phase A — Deterministic checks
  # =====================================================================

  # A1: Check deliverable exists in definition.yaml
  del_exists="$(d="$deliverable" yq -r \
    '[.deliverables[] | select(.name == env(d))] | length' "$def_file")"

  if [ "$del_exists" -eq 0 ]; then
    echo "Error: deliverable '${deliverable}' not found in definition.yaml" >&2
    return 2
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
    # Research mode: check .furrow/rows/{name}/deliverables/ has non-empty files
    if [ -d "${work_dir}/deliverables" ]; then
      has_content="false"
      for f in "${work_dir}/deliverables"/*; do
        [ -f "$f" ] || continue
        if [ -s "$f" ]; then
          has_content="true"
          break
        fi
      done
      if [ "$has_content" = "true" ]; then
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
          _globs_tmp="${_eval_tmpdir}/globs_a3"
          echo "$file_ownership" | jq -r '.[]' 2>/dev/null > "$_globs_tmp" || true
          while IFS= read -r glob_pattern; do
            # Use git diff with pathspec to check if any owned files changed
            match_count="$(git diff --name-only "${base_commit}..HEAD" -- "$glob_pattern" 2>/dev/null | wc -l)" || match_count="0"
            if [ "$match_count" -gt 0 ]; then
              matched="true"
              break
            fi
          done < "$_globs_tmp"
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
  ac_json="$(d="$deliverable" yq -o=json -r \
    '[.deliverables[] | select(.name == env(d)) | .acceptance_criteria[]]' "$def_file")"

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

  # A6: Seed consistency (deterministic)
  seed_id="$(jq -r '.seed_id // ""' "$state_file")"
  seed_check_pass="false"
  seed_check_evidence=""

  if [ -z "$seed_id" ] || [ "$seed_id" = "null" ]; then
    seed_check_pass="false"
    seed_check_evidence="No seed_id in state.json — seeds are mandatory"
  elif command -v sds > /dev/null 2>&1; then
    if ! sds show "$seed_id" > /dev/null 2>&1; then
      seed_check_pass="false"
      seed_check_evidence="Seed not found: $seed_id"
    else
      seed_status="$(sds show "$seed_id" --json | jq -r '.status')"
      if [ "$seed_status" = "closed" ]; then
        seed_check_pass="false"
        seed_check_evidence="Seed is closed: $seed_id (status=$seed_status)"
      else
        seed_check_pass="true"
        seed_check_evidence="Seed exists and is not closed: $seed_id (status=$seed_status)"
      fi
    fi
  else
    # sds not available — cannot verify, pass with warning
    seed_check_pass="true"
    seed_check_evidence="sds command not available — seed existence not verified (seed_id=$seed_id)"
  fi

  if [ "$seed_check_pass" = "false" ]; then
    phase_a_verdict="fail"
  fi

  # =====================================================================
  # Write Phase A results JSON
  # =====================================================================

  mkdir -p "$reviews_dir"
  phase_a_file="${reviews_dir}/phase-a-results.json"
  tmp_file="${phase_a_file}.tmp.$$"

  jq -n \
    --arg deliverable "$deliverable" \
    --argjson artifacts_present "$artifacts_present" \
    --argjson acceptance_criteria "$phase_a_ac" \
    --arg phase_a_verdict "$phase_a_verdict" \
    --arg mode "$mode" \
    --arg base_commit "$base_commit" \
    --argjson file_ownership "$file_ownership" \
    --argjson seed_check_pass "$seed_check_pass" \
    --arg seed_check_evidence "$seed_check_evidence" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{
      deliverable: $deliverable,
      artifacts_present: $artifacts_present,
      acceptance_criteria: $acceptance_criteria,
      seed_check: {
        pass: $seed_check_pass,
        evidence: $seed_check_evidence
      },
      verdict: $phase_a_verdict,
      mode: $mode,
      base_commit: $base_commit,
      file_ownership: $file_ownership,
      timestamp: $timestamp
    }' > "$tmp_file"

  # Atomic write
  mv "$tmp_file" "$phase_a_file"

  echo "Phase A results written: ${phase_a_file}" >&2

  # Output path on stdout for consumption by run-gate
  echo "$phase_a_file"

  # Return code reflects Phase A verdict
  if [ "$phase_a_verdict" = "pass" ]; then
    return 0
  else
    return 1
  fi
}
