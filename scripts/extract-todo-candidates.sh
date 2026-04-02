#!/bin/sh
# extract-todo-candidates.sh — Extract TODO candidates from work unit artifacts.
#
# A "dumb JSON collector": extracts raw candidates from three sources and
# outputs a JSON array to stdout. All semantic reasoning (dedup, merge,
# prioritization) happens in the agent layer, not here.
#
# Usage: extract-todo-candidates.sh <work-unit-name>
#
# Sources:
#   1. summary.md — lines under "## Open Questions"
#   2. learnings.jsonl — unpromoted pitfalls (category=pitfall, promoted=false)
#   3. reviews/*.json — non-pass phase_b dimensions
#
# Dependencies: jq, awk (POSIX)
# Exit 0 on success (including zero candidates). Exit 1 on fatal errors.

set -eu

# --- Argument validation ---
if [ $# -ne 1 ]; then
  echo "Usage: $0 <work-unit-name>" >&2
  exit 1
fi

NAME="$1"
WORK_DIR=".work/${NAME}"

if [ ! -d "$WORK_DIR" ]; then
  echo "Error: work unit '${NAME}' not found at ${WORK_DIR}/" >&2
  exit 1
fi

# --- Temp directory with cleanup ---
_tmpdir=$(mktemp -d)
trap 'rm -rf "$_tmpdir"' EXIT

# Initialize empty arrays for each source
printf '[]' > "$_tmpdir/summary.json"
printf '[]' > "$_tmpdir/learnings.json"
printf '[]' > "$_tmpdir/reviews.json"

# --- Source 1: summary.md Open Questions ---
extract_summary() {
  summary_file="${WORK_DIR}/summary.md"
  if [ ! -f "$summary_file" ]; then
    return 0
  fi

  # Extract lines between "## Open Questions" and next "## " or EOF
  section=$(awk '
    /^## Open Questions/ { found=1; next }
    found && /^## / { exit }
    found { print }
  ' "$summary_file")

  if [ -z "$section" ]; then
    return 0
  fi

  source_file=".work/${NAME}/summary.md"

  # Process each non-blank line
  printf '%s\n' "$section" | while IFS= read -r line; do
    # Skip blank/whitespace-only lines
    trimmed=$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$trimmed" ]; then
      continue
    fi

    # Build candidate via jq
    printf '%s' "$trimmed" | jq -R --arg source "summary-open-questions" \
      --arg name "$NAME" \
      --arg source_file "$source_file" \
      '{
        source: $source,
        title: (if (. | length) > 80 then (.[:80] + "...") else . end),
        context: ("Open question from " + $name + " work unit"),
        raw_content: .,
        source_file: $source_file
      }'
  done | jq -s '.' > "$_tmpdir/summary.json"
}

# --- Source 2: learnings.jsonl Unpromoted Pitfalls ---
extract_learnings() {
  learnings_file="${WORK_DIR}/learnings.jsonl"
  if [ ! -f "$learnings_file" ]; then
    return 0
  fi

  source_file=".work/${NAME}/learnings.jsonl"

  # Process line-by-line: skip malformed lines, filter pitfalls
  while IFS= read -r line; do
    printf '%s' "$line" | jq -c --arg name "$NAME" --arg source_file "$source_file" '
      select(.category == "pitfall" and .promoted == false) |
      {
        source: "learnings-pitfall",
        title: (if (.content | length) > 80 then (.content[:80] + "...") else .content end),
        context: (.context // ("Pitfall from " + $name + " work unit")),
        raw_content: (. | tostring),
        source_file: $source_file
      }
    ' 2>/dev/null || true
  done < "$learnings_file" | jq -s '.' > "$_tmpdir/learnings.json"
}

# --- Source 3: reviews/*.json Non-pass Dimensions ---
extract_reviews() {
  reviews_dir="${WORK_DIR}/reviews"
  if [ ! -d "$reviews_dir" ]; then
    return 0
  fi

  # Collect all review candidates into a single temp file
  : > "$_tmpdir/review_candidates.jsonl"

  for review_file in "$reviews_dir"/*.json; do
    # Handle glob that matches nothing
    if [ ! -f "$review_file" ]; then
      continue
    fi

    basename_file=$(basename "$review_file")
    source_file=".work/${NAME}/reviews/${basename_file}"
    # Filename stem for fallback deliverable name
    stem="${basename_file%.json}"

    # Parse the review file; skip if malformed
    jq -e '.' "$review_file" > /dev/null 2>&1 || continue

    # Extract deliverable name with fallback to filename stem
    deliverable=$(jq -r --arg stem "$stem" '.deliverable // $stem' "$review_file" 2>/dev/null) || deliverable="$stem"

    # Extract non-pass dimensions from phase_b
    jq -c --arg deliverable "$deliverable" --arg source_file "$source_file" '
      .phase_b.dimensions // [] | .[] |
      select(.verdict != "pass") |
      {
        source: "review-finding",
        title: ("Review finding: " + .name + " (" + .verdict + ")"),
        context: (.evidence // ("Non-pass dimension in " + $deliverable + " review")),
        raw_content: ({deliverable: $deliverable} + . | tostring),
        source_file: $source_file
      }
    ' "$review_file" 2>/dev/null >> "$_tmpdir/review_candidates.jsonl" || true
  done

  # Convert collected JSONL to array
  if [ -s "$_tmpdir/review_candidates.jsonl" ]; then
    jq -s '.' "$_tmpdir/review_candidates.jsonl" > "$_tmpdir/reviews.json"
  fi
}

# --- Main ---
extract_summary
extract_learnings
extract_reviews

# Merge all source arrays into a single array
jq -s 'add // []' \
  "$_tmpdir/summary.json" \
  "$_tmpdir/learnings.json" \
  "$_tmpdir/reviews.json"
