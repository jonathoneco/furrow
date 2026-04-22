#!/bin/sh
# cross-model-review.sh — Invoke a cross-model review for a deliverable
#
# Usage: frw cross-model-review <name> <deliverable>
#   name        — row name (kebab-case)
#   deliverable — deliverable name to review
#
# Return codes:
#   0 — cross-model review complete, result written
#   1 — usage error or cross_model.provider not configured (skip gracefully)
#   2 — invocation failed or response parsing error

frw_cross_model_review() {
  set -eu

  _ideation=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --ideation) _ideation=true; shift ;;
      *) break ;;
    esac
  done

  if [ "$_ideation" = true ]; then
    # Ideation mode needs only the name
    if [ $# -lt 1 ]; then
      echo "Usage: frw cross-model-review --ideation <name>" >&2
      return 1
    fi
    # Delegate to ideation function and return
    _cross_model_ideation "$@"
    return $?
  fi

  if [ $# -lt 2 ]; then
    echo "Usage: frw cross-model-review <name> <deliverable>" >&2
    return 1
  fi

  name="$1"
  deliverable="$2"
  work_dir="${PROJECT_ROOT}/.furrow/rows/${name}"
  state_file="${work_dir}/state.json"
  definition_file="${work_dir}/definition.yaml"
  furrow_config=""
  for _candidate in "${PROJECT_ROOT}/.furrow/furrow.yaml" "${PROJECT_ROOT}/.claude/furrow.yaml"; do
    if [ -f "$_candidate" ]; then
      furrow_config="$_candidate"
      break
    fi
  done

  # --- 1. Read cross-model provider ---

  if [ -z "$furrow_config" ]; then
    echo "Cross-model review skipped: no furrow.yaml found" >&2
    return 1
  fi
  provider="$(yq -r '.cross_model.provider // ""' "$furrow_config")"
  if [ -z "$provider" ]; then
    echo "Cross-model review skipped: no provider configured" >&2
    return 1
  fi

  # --- 2. Read mode and step from state ---

  if [ ! -f "$state_file" ]; then
    echo "Error: state.json not found at ${state_file}" >&2
    return 2
  fi

  mode="$(jq -r '.mode // "code"' "$state_file")"
  base_commit="$(jq -r '.base_commit // ""' "$state_file")"

  # --- 3. Get dimensions ---

  dim_path="$("$FURROW_ROOT/bin/frw" select-dimensions "$name")"
  dimensions="$(yq -r '.dimensions[] | "- **" + .name + "**: " + .definition + "\n  Pass: " + .pass_criteria + "\n  Fail: " + .fail_criteria' "$dim_path")"

  # --- 4. Read acceptance criteria for this deliverable ---

  if [ ! -f "$definition_file" ]; then
    echo "Error: definition.yaml not found at ${definition_file}" >&2
    return 2
  fi

  criteria="$(name="${deliverable}" yq -r '.deliverables[] | select(.name == env(name)) | .acceptance_criteria[]' "$definition_file" | sed 's/^/- /')"
  if [ -z "$criteria" ]; then
    echo "Error: no acceptance criteria found for deliverable '${deliverable}'" >&2
    return 2
  fi

  # --- 5. Get diff or file listing ---

  if [ "$mode" = "code" ] && [ -n "$base_commit" ] && [ "$base_commit" != "null" ] && [ "$base_commit" != "unknown" ]; then
    changes="$(git diff --stat "${base_commit}..HEAD" 2>/dev/null || echo "(no diff available)")"
  else
    deliverables_dir="${work_dir}/deliverables"
    if [ -d "$deliverables_dir" ]; then
      changes="$(ls -1 "$deliverables_dir" 2>/dev/null || echo "(no deliverable files)")"
    else
      changes="(no deliverable files found)"
    fi
  fi

  # --- 6. Build review prompt ---

  prompt="You are reviewing deliverable '${deliverable}' for quality.

## Acceptance Criteria

${criteria}

## Evaluation Dimensions

${dimensions}

## Changes

\`\`\`
${changes}
\`\`\`

## Instructions

For each dimension, provide: verdict (pass/fail) and one-line evidence.

Output as JSON: {\"dimensions\": [{\"name\": \"...\", \"verdict\": \"...\", \"evidence\": \"...\"}], \"overall\": \"pass|fail\"}"

  # --- 7. Invoke the model ---

  mkdir -p "${work_dir}/prompts"
  mkdir -p "${work_dir}/reviews"

  response=""
  _invoke_err="$(mktemp)"

  # Dispatch based on provider prefix
  case "$provider" in
    codex|codex/*)
      if ! command -v codex >/dev/null 2>&1; then
        echo "error: codex CLI not found" >&2
        rm -f "$_invoke_err"
        return 2
      fi
      _model="${provider#codex}"
      _model="${_model#/}"
      if [ -n "$_model" ]; then
        response="$(codex exec -c 'approval_policy="never"' -m "$_model" "$prompt" 2>"$_invoke_err")" || true
      else
        response="$(codex exec -c 'approval_policy="never"' "$prompt" 2>"$_invoke_err")" || true
      fi
      ;;
    *)
      # Default: use claude CLI with --model
      if command -v claude >/dev/null 2>&1; then
        response="$(claude --model "${provider}" --print "${prompt}" 2>"$_invoke_err")" || true
      fi
      ;;
  esac

  if [ -s "$_invoke_err" ]; then
    echo "cross-model stderr: $(cat "$_invoke_err")" >&2
  fi
  rm -f "$_invoke_err"

  if [ -z "$response" ]; then
    prompt_file="${work_dir}/prompts/review-${deliverable}-cross.md"
    prompt_tmp="$(mktemp)"
    printf '%s\n' "$prompt" > "$prompt_tmp"
    mv "$prompt_tmp" "$prompt_file"
    echo "Cross-model invocation failed — prompt written to ${prompt_file}" >&2
    return 2
  fi

  # --- 8. Parse response ---

  # Extract a complete JSON object from model response
  json_block="$(printf '%s\n' "$response" | awk '
    BEGIN { depth=0; capture=0; buf="" }
    {
      for (i=1; i<=length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") { depth++; capture=1 }
        if (capture) buf = buf c
        if (c == "}" && capture) {
          depth--
          if (depth == 0) { print buf; exit }
        }
      }
      if (capture) buf = buf "\n"
    }
  ')"

  if [ -z "$json_block" ] || ! printf '%s\n' "$json_block" | jq empty 2>/dev/null; then
    raw_file="${work_dir}/reviews/${deliverable}-cross.raw"
    raw_tmp="$(mktemp)"
    printf '%s\n' "$response" > "$raw_tmp"
    mv "$raw_tmp" "$raw_file"
    echo "Failed to parse JSON from model response — raw output written to ${raw_file}" >&2
    return 2
  fi

  # --- 9. Write review result ---

  model_dims="$(printf '%s\n' "$json_block" | jq -c '.dimensions')" || {
    echo "Error: failed to extract dimensions from model response" >&2
    return 2
  }
  model_overall="$(printf '%s\n' "$json_block" | jq -r '.overall')" || {
    echo "Error: failed to extract overall verdict from model response" >&2
    return 2
  }
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  review_tmp="$(mktemp)"
  trap 'rm -f "$review_tmp"' EXIT

  jq -n \
    --arg deliverable "$deliverable" \
    --argjson dims "$model_dims" \
    --arg overall "$model_overall" \
    --arg provider "$provider" \
    --arg ts "$timestamp" \
    '{
      deliverable: $deliverable,
      phase_a: { artifacts_present: true, acceptance_criteria: [], plan_completion: { planned_files_touched: true, unplanned_changes: [] }, verdict: "pass" },
      phase_b: { dimensions: $dims, verdict: $overall },
      overall: $overall,
      corrections: 0,
      reviewer: $provider,
      cross_model: true,
      timestamp: $ts
    }' > "$review_tmp"

  mv "$review_tmp" "${work_dir}/reviews/${deliverable}-cross.json"
  trap - EXIT

  echo "Cross-model review written to ${work_dir}/reviews/${deliverable}-cross.json"
}

_cross_model_ideation() {
  name="$1"
  work_dir="${PROJECT_ROOT}/.furrow/rows/${name}"
  definition_file="${work_dir}/definition.yaml"
  summary_file="${work_dir}/summary.md"
  furrow_config=""
  for _candidate in "${PROJECT_ROOT}/.furrow/furrow.yaml" "${PROJECT_ROOT}/.claude/furrow.yaml"; do
    if [ -f "$_candidate" ]; then
      furrow_config="$_candidate"
      break
    fi
  done

  # --- 1. Read cross-model provider ---
  if [ -z "$furrow_config" ]; then
    echo "Cross-model review skipped: no furrow.yaml found" >&2
    return 1
  fi
  provider="$(yq -r '.cross_model.provider // ""' "$furrow_config")"
  if [ -z "$provider" ]; then
    echo "Cross-model review skipped: no provider configured" >&2
    return 1
  fi

  # --- 2. Read definition ---
  if [ ! -f "$definition_file" ]; then
    echo "Error: definition.yaml not found at ${definition_file}" >&2
    return 2
  fi

  objective="$(yq -r '.objective // ""' "$definition_file")"
  deliverables="$(yq -r '.deliverables[] | "- **" + .name + "**: " + (.acceptance_criteria | length | tostring) + " ACs"' "$definition_file" 2>/dev/null)" || deliverables="(could not parse)"
  constraints="$(yq -r '.constraints[]' "$definition_file" 2>/dev/null | sed 's/^/- /')" || constraints="(none)"

  # --- 3. Read open questions from summary ---
  open_questions="None documented"
  if [ -f "$summary_file" ]; then
    open_questions="$(awk '/^## Open Questions/{found=1; next} /^## /{if(found) exit} found && /[^ ]/' "$summary_file")" || open_questions="None documented"
    [ -z "$open_questions" ] && open_questions="None documented"
  fi

  # --- 4. Build ideation review prompt ---
  prompt="You are reviewing the ideation framing for row '${name}'.

## Objective

${objective}

## Deliverables

${deliverables}

## Constraints

${constraints}

## Open Questions

${open_questions}

## Instructions

Evaluate this framing on these dimensions:
1. Feasibility — can the objective be achieved with stated constraints?
2. Alignment — do deliverables collectively address the objective?
3. Dependency validity — are stated dependencies correct and sufficient?
4. Risk assessment — are constraints adequate to prevent scope creep?
5. Completeness — are there obvious gaps in the deliverable set?

Output as JSON:
{\"dimensions\": [{\"name\": \"...\", \"verdict\": \"pass|fail|conditional\", \"evidence\": \"...\"}], \"framing_quality\": \"sound|questionable|unsound\", \"suggested_revisions\": [...]}"

  # --- 5. Invoke model ---
  mkdir -p "${work_dir}/reviews"

  response=""
  _invoke_err="$(mktemp)"

  case "$provider" in
    codex|codex/*)
      if ! command -v codex >/dev/null 2>&1; then
        echo "error: codex CLI not found" >&2
        rm -f "$_invoke_err"
        return 2
      fi
      _model="${provider#codex}"
      _model="${_model#/}"
      if [ -n "$_model" ]; then
        response="$(codex exec -c 'approval_policy="never"' -m "$_model" "$prompt" 2>"$_invoke_err")" || true
      else
        response="$(codex exec -c 'approval_policy="never"' "$prompt" 2>"$_invoke_err")" || true
      fi
      ;;
    *)
      if command -v claude >/dev/null 2>&1; then
        response="$(claude --model "${provider}" --print "${prompt}" 2>"$_invoke_err")" || true
      fi
      ;;
  esac

  if [ -s "$_invoke_err" ]; then
    echo "cross-model stderr: $(cat "$_invoke_err")" >&2
  fi
  rm -f "$_invoke_err"

  if [ -z "$response" ]; then
    prompt_file="${work_dir}/prompts/review-ideation-cross.md"
    mkdir -p "${work_dir}/prompts"
    prompt_tmp="$(mktemp)"
    printf '%s\n' "$prompt" > "$prompt_tmp"
    mv "$prompt_tmp" "$prompt_file"
    echo "Cross-model invocation failed — prompt written to ${prompt_file}" >&2
    return 2
  fi

  # --- 6. Parse and write result ---
  json_block="$(printf '%s\n' "$response" | awk '
    BEGIN { depth=0; capture=0; buf="" }
    {
      for (i=1; i<=length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") { depth++; capture=1 }
        if (capture) buf = buf c
        if (c == "}" && capture) {
          depth--
          if (depth == 0) { print buf; exit }
        }
      }
      if (capture) buf = buf "\n"
    }
  ')"

  if [ -z "$json_block" ] || ! printf '%s\n' "$json_block" | jq empty 2>/dev/null; then
    raw_file="${work_dir}/reviews/ideation-cross.raw"
    raw_tmp="$(mktemp)"
    printf '%s\n' "$response" > "$raw_tmp"
    mv "$raw_tmp" "$raw_file"
    echo "Failed to parse JSON from model response — raw output written to ${raw_file}" >&2
    return 2
  fi

  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  review_tmp="$(mktemp)"
  trap 'rm -f "$review_tmp"' EXIT

  jq -n \
    --argjson parsed "$json_block" \
    --arg provider "$provider" \
    --arg ts "$timestamp" \
    '{
      type: "ideation",
      dimensions: ($parsed.dimensions // []),
      framing_quality: ($parsed.framing_quality // "unknown"),
      suggested_revisions: ($parsed.suggested_revisions // []),
      reviewer: $provider,
      cross_model: true,
      timestamp: $ts
    }' > "$review_tmp"

  mv "$review_tmp" "${work_dir}/reviews/ideation-cross.json"
  trap - EXIT

  echo "Ideation cross-model review written to ${work_dir}/reviews/ideation-cross.json"
}
