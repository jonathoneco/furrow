#!/bin/sh
# promote-learnings.sh — Archive-time learnings promotion ceremony
#
# Usage: promote-learnings.sh <name> [project_learnings_path]
#   name                    — row name
#   project_learnings_path  — path to project-level learnings.jsonl (default: learnings.jsonl)
#
# Reads per-row learnings (canonical new schema — see schemas/learning.schema.json),
# auto-recommends promotion, and outputs promotion candidates for user confirmation.
#
# Canonical record shape (post-migration):
#   {ts, step, kind, summary, detail, tags}
#
# The append-learning hook guarantees every on-disk record matches this shape;
# this script asserts on missing fields and refers the user to the hook if the
# assertion fails.
#
# Exit codes:
#   0 — success (or no learnings)
#   1 — usage error
#   3 — on-disk record violates the canonical schema (hook bypass)

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

  [ -z "${line}" ] && continue

  # Canonical new-schema fields.
  kind="$(echo "${line}" | jq -r '.kind')"
  step="$(echo "${line}" | jq -r '.step')"
  summary="$(echo "${line}" | jq -r '.summary')"
  detail="$(echo "${line}" | jq -r '.detail')"
  tags="$(echo "${line}" | jq -r '.tags | join(",")')"

  # Assertion — append-learning hook should have prevented this.
  if [ -z "${kind}" ] || [ "${kind}" = "null" ] \
     || [ -z "${step}" ] || [ "${step}" = "null" ] \
     || [ -z "${summary}" ] || [ "${summary}" = "null" ]; then
    echo "promote-learnings: schema violation on line ${line_num} of ${work_learnings}" >&2
    echo "  missing one of [kind, step, summary] — the append-learning hook should have refused this write." >&2
    echo "  Run bin/frw.d/scripts/migrate-learnings-schema.sh and/or check hook registration in .claude/settings.json." >&2
    exit 3
  fi

  # --- auto-recommendation ---
  recommend="skip"
  reason=""

  case "${kind}" in
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
      # Promote if summary references project-level paths
      if echo "${summary}" | grep -qE '(internal/|pkg/|src/|lib/)'; then
        recommend="promote"
        reason="Pattern references project-level code paths."
      else
        recommend="skip"
        reason="Pattern appears task-specific."
      fi
      ;;
    pitfall)
      # Promote if summary references a package/module
      if echo "${summary}" | grep -qE '(package|module|import|require|dependency)'; then
        recommend="promote"
        reason="Pitfall likely recurs in other rows."
      else
        recommend="skip"
        reason="Pitfall appears task-specific."
      fi
      ;;
  esac

  # --- check deduplication (on summary) ---
  if [ -f "${project_file}" ]; then
    exact_match="$(jq -r --arg s "${summary}" 'select(.summary == $s) | .summary' "${project_file}" 2>/dev/null | wc -l)" || exact_match="0"
    if [ "${exact_match}" -gt 0 ]; then
      echo "[${line_num}/${line_count}] SKIP (duplicate): ${summary}"
      continue
    fi
  fi

  # --- output for user review ---
  echo "---"
  echo "[${line_num}/${line_count}]"
  echo "  summary=${summary}"
  echo "  kind=${kind}"
  echo "  step=${name}/${step}"
  echo "  tags=${tags}"
  echo "  detail=${detail}"
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
