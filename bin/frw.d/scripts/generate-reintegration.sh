#!/bin/sh
# generate-reintegration.sh — Build and write reintegration.json for a Furrow row.
#
# Usage: generate-reintegration.sh <row_name> <furrow_root>
#
# Reads: .furrow/rows/<name>/state.json, git log, reviews/, summary.md
# Writes: .furrow/rows/<name>/reintegration.json (atomic)
#         .furrow/rows/<name>/summary.md (Reintegration section, atomic)
#
# Exit codes:
#   0  success
#   1  usage
#   2  row not found
#   3  schema validation failed
#   4  subprocess (git/jq) failure
#
# Requirements: jq, git
# POSIX sh — no bash-isms.
set -eu

# --- args ---
if [ "$#" -lt 2 ]; then
  printf 'usage: generate-reintegration.sh <row_name> <furrow_root>\n' >&2
  exit 1
fi

ROW_NAME="$1"
FURROW_ROOT="$2"

ROWS_DIR="${FURROW_ROOT}/.furrow/rows"
ROW_DIR="${ROWS_DIR}/${ROW_NAME}"
STATE_FILE="${ROW_DIR}/state.json"
REINT_JSON="${ROW_DIR}/reintegration.json"
SUMMARY_FILE="${ROW_DIR}/summary.md"

# --- preflight ---
command -v jq >/dev/null 2>&1 || { printf 'generate-reintegration: jq is required\n' >&2; exit 4; }
command -v git >/dev/null 2>&1 || { printf 'generate-reintegration: git is required\n' >&2; exit 4; }

if [ ! -f "$STATE_FILE" ]; then
  printf 'generate-reintegration: state.json not found: %s\n' "$STATE_FILE" >&2
  exit 2
fi

# --- helpers ---

# Classify a file path into a category
classify_file() {
  _cf_path="$1"
  case "$_cf_path" in
    *.bak) echo "install-artifact" ;;
    schemas/*.json|schemas/*.yaml)        echo "schema" ;;
    tests/*|*_test.go|test-*.sh)          echo "test" ;;
    docs/*|*.md)                           echo "doc" ;;
    .furrow/*.yaml|*.yaml)                 echo "config" ;;
    *)                                     echo "source" ;;
  esac
}

# Parse conventional type from commit subject
parse_type() {
  _pt_subject="$1"
  _pt_type="$(printf '%s' "$_pt_subject" | sed -n 's/^\([a-z][a-z]*\)([^)]*): .*/\1/p')"
  if [ -z "$_pt_type" ]; then
    _pt_type="$(printf '%s' "$_pt_subject" | sed -n 's/^\([a-z][a-z]*\): .*/\1/p')"
  fi
  case "$_pt_type" in
    feat|fix|chore|docs|refactor|test|infra|merge|revert) printf '%s' "$_pt_type" ;;
    *) printf 'chore' ;;
  esac
}

# Check if path is an install artifact
is_install_artifact() {
  case "$1" in
    *.bak) return 0 ;;
    *) return 1 ;;
  esac
}

# Check if path is a rescue-relevant lib file
is_rescue_relevant() {
  case "$1" in
    bin/frw.d/lib/common.sh|bin/frw.d/lib/common-minimal.sh) return 0 ;;
    *) return 1 ;;
  esac
}

# --- read state ---
_row_name_state="$(jq -r '.name // ""' "$STATE_FILE" 2>/dev/null)" || _row_name_state=""
if [ -z "$_row_name_state" ] || [ "$_row_name_state" = "null" ]; then
  _row_name_state="$ROW_NAME"
fi

_branch="$(jq -r '.branch // ""' "$STATE_FILE" 2>/dev/null)" || _branch=""
if [ -z "$_branch" ] || [ "$_branch" = "null" ]; then
  # Try to detect from git
  _branch="$(git -C "$FURROW_ROOT" branch --show-current 2>/dev/null)" || _branch=""
  if [ -z "$_branch" ]; then
    _branch="work/${ROW_NAME}"
  fi
fi

# --- compute shas ---
_base_sha="$(git -C "$FURROW_ROOT" merge-base "$_branch" main 2>/dev/null)" || _base_sha=""
if [ -z "$_base_sha" ]; then
  # Fallback: first commit on the branch
  _base_sha="$(git -C "$FURROW_ROOT" log --no-merges --pretty=format:'%H' "$_branch" 2>/dev/null | tail -1)" || _base_sha=""
fi
if [ -z "$_base_sha" ]; then
  printf 'generate-reintegration: cannot determine base_sha for branch %s\n' "$_branch" >&2
  exit 4
fi

_head_sha="$(git -C "$FURROW_ROOT" rev-parse "$_branch" 2>/dev/null)" || _head_sha=""
if [ -z "$_head_sha" ]; then
  printf 'generate-reintegration: cannot determine head_sha for branch %s\n' "$_branch" >&2
  exit 4
fi

_generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# --- build commits array ---
_commits_json="[]"
_tmp_commits="$(mktemp)"
# shellcheck disable=SC2064
trap "rm -f '$_tmp_commits'" EXIT INT TERM

git -C "$FURROW_ROOT" log --no-merges --pretty=format:'%H%x09%s' "${_base_sha}..${_head_sha}" 2>/dev/null > "$_tmp_commits" || true

_rescue_needed=false

while IFS="$(printf '\t')" read -r _sha _subject || [ -n "$_sha" ]; do
  [ -n "$_sha" ] || continue
  _ctype="$(parse_type "$_subject")"

  # Check install artifact risk for this commit
  _risk="none"
  _commit_files="$(git -C "$FURROW_ROOT" diff-tree --no-commit-id -r --name-only "$_sha" 2>/dev/null)" || _commit_files=""
  for _cfile in $_commit_files; do
    if is_install_artifact "$_cfile"; then
      _risk="high"
    fi
    if is_rescue_relevant "$_cfile"; then
      _rescue_needed=true
    fi
  done

  # Truncate sha to 40 chars max, strip to 7 for display in subject but keep full for sha field
  _sha_full="$(printf '%s' "$_sha" | cut -c1-40)"
  _subject_safe="$(printf '%s' "$_subject" | cut -c1-100)"

  _commit_obj="$(jq -n \
    --arg sha "$_sha_full" \
    --arg subject "$_subject_safe" \
    --arg conventional_type "$_ctype" \
    --arg install_artifact_risk "$_risk" \
    '{sha: $sha, subject: $subject, conventional_type: $conventional_type, install_artifact_risk: $install_artifact_risk}'
  )"
  _commits_json="$(printf '%s\n%s' "$_commits_json" "$_commit_obj" | jq -s '.[0] + [.[1]]')"
done < "$_tmp_commits"
rm -f "$_tmp_commits"
trap - EXIT INT TERM

# If no commits, use a placeholder (schema requires minItems:1)
_commit_count="$(printf '%s' "$_commits_json" | jq 'length')"
if [ "$_commit_count" -eq 0 ]; then
  printf 'generate-reintegration: no commits found between %s and %s\n' "$_base_sha" "$_head_sha" >&2
  exit 4
fi

# --- build files_changed array ---
_files_json="[]"
_all_files="$(git -C "$FURROW_ROOT" diff --name-only "${_base_sha}..${_head_sha}" 2>/dev/null)" || _all_files=""

# Group files by category
_tmp_cats="$(mktemp)"
# shellcheck disable=SC2064
trap "rm -f '$_tmp_cats'" EXIT INT TERM

for _file in $_all_files; do
  _cat="$(classify_file "$_file")"
  printf '%s\t%s\n' "$_cat" "$_file" >> "$_tmp_cats"
done

# Build category groups
for _category in source test doc config schema install-artifact; do
  _cat_count="$(grep -c "^${_category}	" "$_tmp_cats" 2>/dev/null || true)"
  if [ "${_cat_count:-0}" -gt 0 ]; then
    _cat_files="$(grep "^${_category}	" "$_tmp_cats" | cut -f2- | tr '\n' ',' | sed 's/,$//')"
    # Use first file as path_glob representative
    _first_file="$(grep "^${_category}	" "$_tmp_cats" | head -1 | cut -f2-)"
    if [ "$_cat_count" -eq 1 ]; then
      _path_glob="$_first_file"
    else
      # Create a simple glob from common prefix
      _path_glob="${_first_file%/*}/*"
      if [ "$_path_glob" = "*" ] || [ "$_path_glob" = "/*" ]; then
        _path_glob="$_first_file"
      fi
    fi
    _file_obj="$(jq -n \
      --arg path_glob "$_path_glob" \
      --argjson count "$_cat_count" \
      --arg category "$_category" \
      '{path_glob: $path_glob, count: $count, category: $category}'
    )"
    _files_json="$(printf '%s\n%s' "$_files_json" "$_file_obj" | jq -s '.[0] + [.[1]]')"
  fi
done

rm -f "$_tmp_cats"
trap - EXIT INT TERM

# --- read decisions from summary.md ---
_decisions_json="[]"
if [ -f "$SUMMARY_FILE" ]; then
  # Extract ideation section markers: <!-- ideation:section:<id> -->
  _tmp_sections="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$_tmp_sections'" EXIT INT TERM

  grep -n '<!-- ideation:section:' "$SUMMARY_FILE" > "$_tmp_sections" 2>/dev/null || true

  while IFS= read -r _section_line; do
    [ -n "$_section_line" ] || continue
    _section_id="$(printf '%s' "$_section_line" | sed -n 's/.*<!-- ideation:section:\([a-z0-9-]*\) -->.*/\1/p')"
    [ -n "$_section_id" ] || continue
    _linenum="$(printf '%s' "$_section_line" | cut -d: -f1)"

    # Extract heading immediately after the marker
    _title="$(awk -v start="$_linenum" 'NR > start && /^### / { sub(/^### /, ""); print; exit }' "$SUMMARY_FILE" 2>/dev/null)" || _title=""
    [ -n "$_title" ] || _title="Section: $_section_id"

    # Extract first paragraph after the heading as resolution
    _resolution="$(awk -v start="$_linenum" '
      NR > start && /^### / { in_heading=1; next }
      in_heading && /^[^#]/ && !/^$/ { print; exit }
    ' "$SUMMARY_FILE" 2>/dev/null)" || _resolution=""
    [ -n "$_resolution" ] || _resolution="See ideation section $_section_id"

    _dec_obj="$(jq -n \
      --arg title "$_title" \
      --arg resolution "$_resolution" \
      --arg rationale "See ideation:section:${_section_id} in summary.md" \
      --arg ideation_section "ideation:section:${_section_id}" \
      '{title: $title, resolution: $resolution, rationale: $rationale, ideation_section: $ideation_section}'
    )"
    _decisions_json="$(printf '%s\n%s' "$_decisions_json" "$_dec_obj" | jq -s '.[0] + [.[1]]')"
  done < "$_tmp_sections"

  rm -f "$_tmp_sections"
  trap - EXIT INT TERM
fi

# --- read open_items from latest review ---
_open_items_json="[]"
_evidence_path=""
_test_pass=false

if [ -d "${ROW_DIR}/reviews" ]; then
  # Find most recently modified review file
  _latest_review="$(find "${ROW_DIR}/reviews" -maxdepth 1 \( -name "*.md" -o -name "*.json" \) -type f 2>/dev/null | \
    xargs ls -t 2>/dev/null | head -1)" || _latest_review=""

  if [ -n "$_latest_review" ] && [ -f "$_latest_review" ]; then
    _evidence_path="reviews/$(basename "$_latest_review")"

    # Try to detect pass status from review content
    if grep -qi 'pass: true\|overall.*pass\|result.*pass' "$_latest_review" 2>/dev/null; then
      _test_pass=true
    fi

    # Try to extract open items from "Open Items" section
    _tmp_oi="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$_tmp_oi'" EXIT INT TERM

    awk '/^## Open Items/,/^## [^O]/' "$_latest_review" 2>/dev/null | \
      grep '^- ' | head -10 > "$_tmp_oi" || true

    while IFS= read -r _oi_line; do
      [ -n "$_oi_line" ] || continue
      _oi_text="$(printf '%s' "$_oi_line" | sed 's/^- //' | sed 's/^\[.*\] //')"
      _oi_urgency="medium"
      case "$_oi_line" in
        *\[high\]*|*HIGH*) _oi_urgency="high" ;;
        *\[low\]*|*LOW*)   _oi_urgency="low" ;;
      esac
      _oi_obj="$(jq -n \
        --arg title "$_oi_text" \
        --arg urgency "$_oi_urgency" \
        '{title: $title, urgency: $urgency}'
      )"
      _open_items_json="$(printf '%s\n%s' "$_open_items_json" "$_oi_obj" | jq -s '.[0] + [.[1]]')"
    done < "$_tmp_oi"

    rm -f "$_tmp_oi"
    trap - EXIT INT TERM
  fi
fi

# --- build test_results ---
if [ -n "$_evidence_path" ]; then
  _test_results="$(jq -n \
    --argjson pass "$_test_pass" \
    --arg evidence_path "$_evidence_path" \
    '{pass: $pass, evidence_path: $evidence_path}'
  )"
else
  _test_results='{"pass": false}'
fi

# --- build merge_hints ---
_merge_hints="$(jq -n \
  --argjson rescue_likely_needed "$_rescue_needed" \
  '{expected_conflicts: [], rescue_likely_needed: $rescue_likely_needed}'
)"

# --- assemble reintegration JSON ---
_base_sha_short="$(printf '%s' "$_base_sha" | cut -c1-7)"
_head_sha_short="$(printf '%s' "$_head_sha" | cut -c1-7)"

_reint_json="$(jq -n \
  --arg schema_version "1.0" \
  --arg row_name "$_row_name_state" \
  --arg branch "$_branch" \
  --arg base_sha "$_base_sha_short" \
  --arg head_sha "$_head_sha_short" \
  --arg generated_at "$_generated_at" \
  --argjson commits "$_commits_json" \
  --argjson files_changed "$_files_json" \
  --argjson decisions "$_decisions_json" \
  --argjson open_items "$_open_items_json" \
  --argjson test_results "$_test_results" \
  --argjson merge_hints "$_merge_hints" \
  '{
    schema_version: $schema_version,
    row_name: $row_name,
    branch: $branch,
    base_sha: $base_sha,
    head_sha: $head_sha,
    generated_at: $generated_at,
    commits: $commits,
    files_changed: $files_changed,
    decisions: $decisions,
    open_items: $open_items,
    test_results: $test_results,
    merge_hints: $merge_hints
  }'
)"

# --- validate against schema (jq-based) ---
_validate_result="$(printf '%s' "$_reint_json" | jq -r '
  def check_required(obj; fields):
    fields | map(
      if obj[.] == null then "missing:" + . else empty end
    ) | .[];

  def check_pattern(val; pat):
    if (val | type) != "string" then "not-string"
    elif (val | test(pat) | not) then "pattern-mismatch"
    else "ok"
    end;

  . as $doc |

  # Required top-level fields
  (check_required($doc; ["schema_version","row_name","branch","base_sha","head_sha","generated_at","commits","files_changed","decisions","open_items","test_results"]) // empty),

  # schema_version must be "1.0"
  (if $doc.schema_version != "1.0" then "invalid:schema_version" else empty end),

  # row_name pattern
  (if ($doc.row_name | type) == "string" and ($doc.row_name | test("^[a-z][a-z0-9]*(-[a-z0-9]+)*$") | not) then "pattern:row_name" else empty end),

  # branch pattern
  (if ($doc.branch | type) == "string" and ($doc.branch | test("^[A-Za-z0-9._/-]+$") | not) then "pattern:branch" else empty end),

  # sha patterns
  (if ($doc.base_sha | type) == "string" and ($doc.base_sha | test("^[0-9a-f]{7,40}$") | not) then "pattern:base_sha" else empty end),
  (if ($doc.head_sha | type) == "string" and ($doc.head_sha | test("^[0-9a-f]{7,40}$") | not) then "pattern:head_sha" else empty end),

  # commits array
  (if ($doc.commits | type) != "array" then "type:commits"
   elif ($doc.commits | length) == 0 then "empty:commits"
   else empty end),

  # test_results.pass is boolean
  (if ($doc.test_results.pass | type) != "boolean" then "type:test_results.pass" else empty end)

' 2>/dev/null)"

if [ -n "$_validate_result" ]; then
  printf 'generate-reintegration: schema validation failed: %s\n' "$_validate_result" >&2
  exit 3
fi

# --- write reintegration.json atomically ---
_tmp_json="${REINT_JSON}.tmp.$$"
printf '%s' "$_reint_json" | jq --sort-keys '.' > "$_tmp_json" 2>/dev/null || {
  rm -f "$_tmp_json"
  printf 'generate-reintegration: failed to write JSON\n' >&2
  exit 4
}
mv "$_tmp_json" "$REINT_JSON"

# --- render markdown ---
_md_content="$(printf '%s' "$_reint_json" | jq -r '
  "<!-- reintegration:begin -->\n## Reintegration\n",
  ("**Branch**: " + .branch + "  ·  **Range**: " + .base_sha + ".." + .head_sha + "  ·  Generated: " + .generated_at + "\n"),
  ("### Commits (" + (.commits | length | tostring) + ")"),
  (.commits[] | "- `" + .sha[0:7] + "` **" + .conventional_type + "** — " + .subject +
    (if .install_artifact_risk != "none" then " _(install-artifact risk: " + .install_artifact_risk + ")_" else "" end)
  ),
  "\n### Files Changed",
  (.files_changed[] | "- `" + .path_glob + "` (" + (.count | tostring) + ") — _" + .category + "_"),
  "\n### Decisions",
  (if (.decisions | length) == 0 then "- _No decisions recorded._" else .decisions[] | "- **" + .title + "** — " + .resolution + " _(why: " + .rationale + ")_" end),
  "\n### Open Items",
  (if (.open_items | length) == 0 then "- _No open items._" else .open_items[] | "- [" + .urgency + "] " + .title + (if .suggested_todo_id then " → `" + .suggested_todo_id + "`" else "" end) end),
  "\n### Test Results",
  ("- pass: **" + (.test_results.pass | tostring) + "**" + (if .test_results.evidence_path then " · evidence: `" + .test_results.evidence_path + "`" else "" end)),
  (if .merge_hints.rescue_likely_needed == true then "\n> **Merge hint**: `frw rescue` may be needed after merge — this worktree touched common.sh." else empty end),
  "<!-- reintegration:end -->"
' 2>/dev/null)"

# --- update summary.md with Reintegration section ---
if [ -f "$SUMMARY_FILE" ]; then
  # Check if markers already exist
  if grep -q '<!-- reintegration:begin -->' "$SUMMARY_FILE" 2>/dev/null; then
    # Replace between markers
    _tmp_summary="${SUMMARY_FILE}.tmp.$$"
    awk '
      /<!-- reintegration:begin -->/ { skip=1 }
      /<!-- reintegration:end -->/ { skip=0; next }
      !skip { print }
    ' "$SUMMARY_FILE" > "$_tmp_summary" 2>/dev/null || {
      rm -f "$_tmp_summary"
      printf 'generate-reintegration: warning: failed to update summary.md\n' >&2
    }
    # Append the new content
    printf '%s\n' "$_md_content" >> "$_tmp_summary"
    mv "$_tmp_summary" "$SUMMARY_FILE"
  else
    # Append new section at end
    printf '\n%s\n' "$_md_content" >> "$SUMMARY_FILE"
  fi
else
  # Create summary.md with just the reintegration section
  printf '%s\n' "$_md_content" > "$SUMMARY_FILE"
fi

printf 'Generated reintegration section: %s\n' "$SUMMARY_FILE"
