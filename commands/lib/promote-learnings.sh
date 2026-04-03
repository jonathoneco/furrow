#!/bin/sh
# promote-learnings.sh — Archive-time learnings promotion ceremony
#
# Usage: promote-learnings.sh <name> [project_learnings_path]
#   name                    — row name
#   project_learnings_path  — path to project-level learnings.jsonl (default: learnings.jsonl)
#
# Reads per-row learnings, auto-recommends promotion, and outputs
# promotion candidates for user confirmation.
#
# Exit codes:
#   0 — success (or no learnings)
#   1 — usage error

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: promote-learnings.sh <name> [project_learnings_path]" >&2
  exit 1
fi

name="$1"
project_file="${2:-learnings.jsonl}"

work_learnings=".furrow/rows/${name}/learnings.jsonl"

if [ ! -f "${work_learnings}" ]; then
  echo "No learnings to promote for row '${name}'."
  exit 0
fi

line_count="$(wc -l < "${work_learnings}")"
if [ "${line_count}" -eq 0 ]; then
  echo "No learnings to promote for row '${name}'."
  exit 0
fi

echo "Found ${line_count} learning(s) to review for promotion."
echo ""

# --- process each learning ---

line_num=0
promoted_count=0

while IFS= read -r line; do
  line_num=$((line_num + 1))

  category="$(echo "${line}" | jq -r '.category')"
  content="$(echo "${line}" | jq -r '.content')"
  context="$(echo "${line}" | jq -r '.context')"
  source_step="$(echo "${line}" | jq -r '.source_step')"
  already_promoted="$(echo "${line}" | jq -r '.promoted')"

  if [ "${already_promoted}" = "true" ]; then
    continue
  fi

  # --- auto-recommendation ---
  recommend="skip"
  reason=""

  case "${category}" in
    convention)
      recommend="promote"
      reason="Conventions are inherently project-wide."
      ;;
    dependency)
      recommend="promote"
      reason="Dependency quirks affect all code using that dependency."
      ;;
    preference)
      recommend="promote"
      reason="User preferences are always project-wide."
      ;;
    pattern)
      # Promote if content references project-level paths
      if echo "${content}" | grep -qE '(internal/|pkg/|src/|lib/)'; then
        recommend="promote"
        reason="Pattern references project-level code paths."
      else
        recommend="skip"
        reason="Pattern appears task-specific."
      fi
      ;;
    pitfall)
      # Promote if content references a package/module
      if echo "${content}" | grep -qE '(package|module|import|require|dependency)'; then
        recommend="promote"
        reason="Pitfall likely recurs in other rows."
      else
        recommend="skip"
        reason="Pitfall appears task-specific."
      fi
      ;;
  esac

  # --- check deduplication ---
  if [ -f "${project_file}" ]; then
    exact_match="$(jq -r --arg c "${content}" 'select(.content == $c) | .content' "${project_file}" 2>/dev/null | wc -l)" || exact_match="0"
    if [ "${exact_match}" -gt 0 ]; then
      echo "[${line_num}/${line_count}] SKIP (duplicate): ${content}"
      continue
    fi
  fi

  # --- output for user review ---
  echo "---"
  echo "[${line_num}/${line_count}]"
  echo "  Learning: \"${content}\""
  echo "  Category: ${category} | Source: ${name}/${source_step}"
  echo "  Context: \"${context}\""
  echo ""
  if [ "${recommend}" = "promote" ]; then
    echo "  Recommendation: PROMOTE to project level"
  else
    echo "  Recommendation: SKIP (task-specific)"
  fi
  echo "  Reason: ${reason}"
  echo ""

  promoted_count=$((promoted_count + 1))

done < "${work_learnings}"

echo "Review complete. ${promoted_count} candidate(s) presented."
echo "Use the interactive flow to confirm each promotion."
