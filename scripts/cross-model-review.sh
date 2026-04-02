#!/bin/sh
# cross-model-review.sh — Invoke a cross-model review for a deliverable
#
# Usage: cross-model-review.sh <name> <deliverable>
#   name        — work unit name (kebab-case)
#   deliverable — deliverable name to review
#
# Exit codes:
#   0 — cross-model review complete, result written
#   1 — cross_model.provider not configured (skip gracefully)
#   2 — invocation failed

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -lt 2 ]; then
  echo "Usage: cross-model-review.sh <name> <deliverable>" >&2
  exit 1
fi

name="$1"
deliverable="$2"
work_dir="${HARNESS_ROOT}/.work/${name}"
state_file="${work_dir}/state.json"
definition_file="${work_dir}/definition.yaml"
harness_config="${HARNESS_ROOT}/.claude/harness.yaml"

# --- 1. Read cross-model provider ---

provider="$(yq -r '.cross_model.provider // ""' "$harness_config")"
if [ -z "$provider" ]; then
  echo "Cross-model review skipped: no provider configured" >&2
  exit 1
fi

# --- 2. Read mode and step from state ---

if [ ! -f "$state_file" ]; then
  echo "Error: state.json not found at ${state_file}" >&2
  exit 2
fi

mode="$(jq -r '.mode // "code"' "$state_file")"
base_commit="$(jq -r '.base_commit // ""' "$state_file")"

# --- 3. Get dimensions ---

dim_path="$("${SCRIPT_DIR}/select-dimensions.sh" "$name")"
dimensions="$(yq -r '.dimensions[] | "- **" + .name + "**: " + .definition + "\n  Pass: " + .pass_criteria + "\n  Fail: " + .fail_criteria' "$dim_path")"

# --- 4. Read acceptance criteria for this deliverable ---

if [ ! -f "$definition_file" ]; then
  echo "Error: definition.yaml not found at ${definition_file}" >&2
  exit 2
fi

criteria="$(yq -r ".deliverables[] | select(.name == \"${deliverable}\") | .acceptance_criteria[]" "$definition_file" | sed 's/^/- /')"
if [ -z "$criteria" ]; then
  echo "Error: no acceptance criteria found for deliverable '${deliverable}'" >&2
  exit 2
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
if command -v claude >/dev/null 2>&1; then
  response="$(claude --model "${provider}" --print "${prompt}" 2>/dev/null)" || true
fi

if [ -z "$response" ]; then
  prompt_file="${work_dir}/prompts/review-${deliverable}-cross.md"
  printf '%s\n' "$prompt" > "$prompt_file"
  if command -v claude >/dev/null 2>&1; then
    echo "Cross-model invocation failed — prompt written to ${prompt_file}" >&2
  else
    echo "Prompt written — invoke manually with model ${provider}" >&2
  fi
  exit 2
fi

# --- 8. Parse response ---

json_block="$(printf '%s\n' "$response" | sed -n '/{/,/^}/p' | head -1)"
# Try to extract a complete JSON object
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
  printf '%s\n' "$response" > "$raw_file"
  echo "Failed to parse JSON from model response — raw output written to ${raw_file}" >&2
  exit 2
fi

# --- 9. Write review result ---

model_dims="$(printf '%s\n' "$json_block" | jq -c '.dimensions')"
model_overall="$(printf '%s\n' "$json_block" | jq -r '.overall')"
timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

jq -n \
  --arg deliverable "$deliverable" \
  --argjson dims "$model_dims" \
  --arg overall "$model_overall" \
  --arg provider "$provider" \
  --arg ts "$timestamp" \
  '{
    deliverable: $deliverable,
    phase_a: { artifacts_present: true, acceptance_criteria: [], verdict: "pass" },
    phase_b: { dimensions: $dims, verdict: $overall },
    overall: $overall,
    corrections: 0,
    reviewer: $provider,
    cross_model: true,
    timestamp: $ts
  }' > "${work_dir}/reviews/${deliverable}-cross.json"

echo "Cross-model review written to ${work_dir}/reviews/${deliverable}-cross.json"
