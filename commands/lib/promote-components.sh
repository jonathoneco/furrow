#!/bin/sh
# promote-components.sh — Review-time component promotion flow
#
# Usage: promote-components.sh <name> [candidates_file]
#   name             — row name
#   candidates_file  — path to promotion candidates JSON (optional, reads from stdin)
#
# Presents component promotion candidates for user confirmation.
# Each candidate has: content, target path, rationale.
#
# Expected input format (JSONL, one per line):
#   {"type":"architecture-decision","content":"...","target":"...","rationale":"..."}
#
# Exit codes:
#   0 — success (or no candidates)
#   1 — usage error

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: promote-components.sh <name> [candidates_file]" >&2
  exit 1
fi

name="$1"
candidates_file="${2:-}"

# --- research mode guard ---

_state_file=".furrow/rows/${name}/state.json"
if [ -f "${_state_file}" ]; then
  _mode="$(jq -r '.mode // "code"' "${_state_file}" 2>/dev/null)" || _mode="code"
  if [ "${_mode}" = "research" ]; then
    echo "Research mode: component promotion deferred to archive time."
    exit 0
  fi
fi

# --- read candidates ---

if [ -n "${candidates_file}" ] && [ -f "${candidates_file}" ]; then
  input_file="${candidates_file}"
else
  # Check default location
  default_candidates=".furrow/rows/${name}/promotion-candidates.jsonl"
  if [ -f "${default_candidates}" ]; then
    input_file="${default_candidates}"
  else
    echo "No promotion candidates found for row '${name}'."
    exit 0
  fi
fi

line_count="$(wc -l < "${input_file}")"
if [ "${line_count}" -eq 0 ]; then
  echo "No promotion candidates."
  exit 0
fi

echo "Found ${line_count} promotion candidate(s) to review."
echo ""

# --- present each candidate ---

line_num=0

while IFS= read -r line; do
  line_num=$((line_num + 1))

  ctype="$(echo "${line}" | jq -r '.type // "unknown"')"
  content="$(echo "${line}" | jq -r '.content // ""')"
  target="$(echo "${line}" | jq -r '.target // ""')"
  rationale="$(echo "${line}" | jq -r '.rationale // ""')"

  echo "---"
  echo "[${line_num}/${line_count}]"
  echo "  Promotion Candidate: ${ctype}"
  echo "  Content: \"${content}\""
  echo "  Target: ${target}"
  echo "  Rationale: ${rationale}"
  echo ""
  echo "  Actions: promote (yes) | skip (no) | edit target"
  echo ""

done < "${input_file}"

echo "Review complete. Present each candidate to user for confirmation."
echo "On 'yes': write content to target, commit with 'docs: promote {type} from ${name}'."
echo "On 'edit target': accept new path, write there."
echo "On 'no': skip silently."
