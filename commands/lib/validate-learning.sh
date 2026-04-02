#!/bin/sh
# validate-learning.sh — Validate a single learning JSONL entry
#
# Usage: validate-learning.sh <json-string>
#   Reads a single JSON object from argument or stdin.
#
# Exit codes:
#   0 — valid
#   1 — validation failure (errors on stderr)

set -eu

# --- read input ---

if [ "$#" -ge 1 ]; then
  json_input="$1"
else
  json_input="$(cat)"
fi

if [ -z "${json_input}" ]; then
  echo "No input provided" >&2
  exit 1
fi

# --- validate with jq ---

errors="$(echo "${json_input}" | jq -r '
  def valid_categories: ["pattern","pitfall","preference","convention","dependency"];
  def valid_steps: ["ideate","research","plan","spec","decompose","implement","review"];

  . as $entry |
  [
    # Required fields
    (if .id == null or (.id | type) != "string" then "Missing or invalid field: id" else empty end),
    (if .timestamp == null or (.timestamp | type) != "string" then "Missing or invalid field: timestamp" else empty end),
    (if .category == null then "Missing field: category"
     elif ([.category] | inside(valid_categories) | not) then
       "Invalid category: \(.category). Must be one of: pattern, pitfall, preference, convention, dependency"
     else empty end),
    (if .content == null or (.content | type) != "string" then "Missing or invalid field: content"
     elif (.content | length) < 10 then "content must be at least 10 characters (has \(.content | length))"
     else empty end),
    (if .context == null or (.context | type) != "string" then "Missing or invalid field: context"
     elif (.context | length) < 10 then "context must be at least 10 characters (has \(.context | length))"
     else empty end),
    (if .source_task == null or (.source_task | type) != "string" then "Missing or invalid field: source_task" else empty end),
    (if .source_step == null then "Missing field: source_step"
     elif ([.source_step] | inside(valid_steps) | not) then
       "Invalid source_step: \(.source_step). Must be one of: ideate, research, plan, spec, decompose, implement, review"
     else empty end),
    (if .promoted == null or (.promoted | type) != "boolean" then "Missing or invalid field: promoted (must be boolean)" else empty end),
    # promoted_at consistency
    (if .promoted == true and (.promoted_at == null or .promoted_at == "") then
       "promoted is true but promoted_at is missing"
     elif .promoted == false and .promoted_at != null and .promoted_at != "" then
       "promoted is false but promoted_at is set"
     else empty end),
    # id format: {kebab-case}-{NNN}
    (if (.id | test("^[a-z0-9]+(-[a-z0-9]+)*-[0-9]{3}$") | not) then
       "Invalid id format: \(.id). Expected {kebab-case}-{NNN}"
     else empty end)
  ] | join("\n")
' 2>/dev/null)" || {
  echo "Failed to parse JSON input" >&2
  exit 1
}

if [ -n "${errors}" ]; then
  echo "Learning validation failed:" >&2
  echo "${errors}" >&2
  exit 1
fi

exit 0
