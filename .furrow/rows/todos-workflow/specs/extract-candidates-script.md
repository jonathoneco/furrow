# Spec: extract-todo-candidates.sh

## Component

Shell script that extracts TODO candidates from work unit artifacts. It is a **dumb JSON collector** -- all semantic reasoning (dedup, merge decisions, prioritization) happens in the agent layer, not here.

Part of the `extract-candidates-script` deliverable in the `todos-workflow` work unit.

## Files

| File | Role |
|------|------|
| `scripts/extract-todo-candidates.sh` | Implementation (new) |

## Usage

```sh
scripts/extract-todo-candidates.sh <work-unit-name>
```

- Single positional argument: the kebab-case work unit name (directory name under `.work/`).
- Outputs a JSON array to stdout.
- Exit 0 on success (including zero candidates).
- Exit 1 on fatal errors (missing work unit directory, missing arguments).
- No flags, no options, no stdin.

## Input Sources

The script reads from `.work/<name>/` and extracts candidates from three sources. Each source is independent -- a missing or malformed source does not affect the others.

### 1. summary.md -- Open Questions

- **File**: `.work/<name>/summary.md`
- **Section**: Text between `## Open Questions` header and the next `##` header (or EOF).
- **Candidate per**: Each non-empty, non-whitespace-only line within the extracted section.
- **Skip if**: File missing, or no `## Open Questions` section found.

### 2. learnings.jsonl -- Unpromoted Pitfalls

- **File**: `.work/<name>/learnings.jsonl`
- **Filter**: Lines where `category == "pitfall"` AND `promoted == false`.
- **Candidate per**: Each matching JSONL entry.
- **Skip if**: File missing. Malformed lines (invalid JSON) are skipped individually.

### 3. reviews/*.json -- Non-pass Dimensions

- **Files**: All `.json` files in `.work/<name>/reviews/`.
- **Filter**: Entries in `.phase_b.dimensions[]` where `verdict != "pass"`.
- **Candidate per**: Each matching dimension object, paired with the review's `.deliverable` name.
- **Skip if**: Directory missing or empty. Malformed JSON files are skipped individually.

## Output Format

A JSON array written to stdout. Empty array `[]` when no candidates are found.

Each element is an object with exactly these fields:

```json
{
  "source": "<source-type>",
  "title": "<string, max ~80 chars>",
  "context": "<string, why this matters>",
  "raw_content": "<string, original text/data>",
  "source_file": "<string, relative path to artifact>"
}
```

### Field Details

| Field | Type | Description |
|-------|------|-------------|
| `source` | string | One of: `"summary-open-questions"`, `"learnings-pitfall"`, `"review-finding"` |
| `title` | string | Short summary, truncated to ~80 characters. Trailing `...` when truncated. |
| `context` | string | Why this matters -- extracted from surrounding content or generated from source metadata. |
| `raw_content` | string | Original text or serialized JSON for the agent to reason about. |
| `source_file` | string | Relative path from project root to the source artifact (e.g., `.work/my-task/summary.md`). |

## Source Extraction Logic

### summary-open-questions

1. Use `sed` or `awk` to extract the block between `## Open Questions` and the next line starting with `## ` (or EOF).
2. Strip blank lines and leading/trailing whitespace from each line.
3. For each remaining non-empty line, emit a candidate:
   - `source`: `"summary-open-questions"`
   - `title`: First 80 characters of the line. Append `"..."` if truncated.
   - `context`: `"Open question from <name> work unit"`
   - `raw_content`: Full line text, untruncated.
   - `source_file`: `.work/<name>/summary.md`

### learnings-pitfall

1. Read `learnings.jsonl` line by line.
2. For each line, attempt to parse as JSON. If parsing fails, skip the line.
3. Filter: `select(.category == "pitfall" and .promoted == false)`.
4. For each matching entry, emit a candidate:
   - `source`: `"learnings-pitfall"`
   - `title`: `.content` field, truncated to 80 characters. Append `"..."` if truncated.
   - `context`: `.context` field value. If absent, use `"Pitfall from <name> work unit"`.
   - `raw_content`: The full JSON object serialized as a compact JSON string.
   - `source_file`: `.work/<name>/learnings.jsonl`

### review-finding

1. Iterate over all `*.json` files in `.work/<name>/reviews/`.
2. For each file, attempt to parse as JSON. If parsing fails, skip the file.
3. Extract `.deliverable` as `deliverable_name` (fall back to filename without extension if absent).
4. Iterate `.phase_b.dimensions[]` and select entries where `.verdict != "pass"`.
5. For each matching dimension, emit a candidate:
   - `source`: `"review-finding"`
   - `title`: `"Review finding: <dimension.name> (<dimension.verdict>)"`
   - `context`: `.evidence` field value. If absent, use `"Non-pass dimension in <deliverable_name> review"`.
   - `raw_content`: JSON object containing the dimension object plus `"deliverable": "<deliverable_name>"`, serialized as compact JSON string.
   - `source_file`: `.work/<name>/reviews/<filename>` (relative path to the specific review file)

## Error Handling

### Fatal Errors (exit 1)

| Condition | Message (to stderr) |
|-----------|---------------------|
| No argument provided | `Usage: extract-todo-candidates.sh <work-unit-name>` |
| `.work/<name>/` does not exist | `Error: work unit '<name>' not found at .work/<name>/` |

### Graceful Degradation (continue, exit 0)

| Condition | Behavior |
|-----------|----------|
| `summary.md` missing | Skip source, contribute zero candidates |
| `summary.md` has no `## Open Questions` section | Skip source, contribute zero candidates |
| `learnings.jsonl` missing | Skip source, contribute zero candidates |
| Malformed JSONL line in `learnings.jsonl` | Skip that line, continue with remaining lines |
| `reviews/` directory missing or empty | Skip source, contribute zero candidates |
| Malformed JSON in a review file | Skip that file, continue with remaining files |
| `.phase_b` or `.dimensions` missing in a review file | Skip that file, continue |
| No candidates found across all sources | Output `[]` |

Diagnostic messages for skipped entries go to stderr (not stdout), gated behind a `-v` flag or unconditionally -- implementer's choice. Stdout must contain only the JSON array.

## Acceptance Criteria

1. Reads `summary.md`, `learnings.jsonl`, and `reviews/*.json` from the named work unit.
2. Outputs a valid JSON array of candidate objects to stdout.
3. Each candidate has all five fields: `source`, `title`, `context`, `raw_content`, `source_file`.
4. `source` values are constrained to the three defined types.
5. Tolerant of missing sources -- returns empty array for absent files.
6. Tolerant of malformed sources -- skips bad lines/files, does not abort.
7. Exit 1 with usage message when called without arguments.
8. Exit 1 with error when the work unit directory does not exist.
9. Output is always valid JSON (parseable by `jq .`).

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Work unit has no summary.md, no learnings.jsonl, no reviews/ | Output `[]`, exit 0 |
| summary.md exists but has no `## Open Questions` header | Zero candidates from this source |
| `## Open Questions` section is empty (header exists, no content before next `##`) | Zero candidates from this source |
| Open question line exceeds 80 characters | `title` truncated with `...`, `raw_content` has the full line |
| learnings.jsonl has a mix of valid and invalid JSON lines | Valid lines processed, invalid lines skipped |
| learnings.jsonl entry has `category: "pitfall"` but `promoted: true` | Filtered out, no candidate emitted |
| learnings.jsonl entry is a pitfall but has no `.context` field | `context` falls back to default string |
| Review file has no `.phase_b` key | File skipped entirely |
| Review file has `.phase_b.dimensions` but all are `"pass"` | Zero candidates from that file |
| Review dimension has no `.evidence` field | `context` falls back to default string |
| Review JSON has no `.deliverable` field | Fall back to filename stem as deliverable name |
| reviews/ directory exists but contains non-JSON files | Non `.json` files ignored by glob |
| Work unit name contains special characters | Script should work with any valid directory name; paths are quoted |
| Multiple `## Open Questions` sections in summary.md | Only the first occurrence is extracted (stop at next `##`) |
| jq is not installed | Script fails -- jq is a hard dependency (document in header comment) |

## Dependencies

- **jq**: Required for all JSON processing (JSONL filtering, review parsing, final array assembly).
- **awk** or **sed**: For summary.md section extraction.
- POSIX shell (`#!/bin/sh` with `set -eu`).

## Implementation Notes

- Use a temp directory pattern (`mktemp -d` with `trap ... EXIT` cleanup) to accumulate per-source JSON fragments, then merge with `jq -s 'add // []'` or equivalent.
- The three extraction functions can each write their candidate array to a temp file. Final assembly concatenates them.
- Keep the script under ~150 lines. Three source extraction functions plus a main orchestrator.
- Header comment should document usage, dependencies, and the "dumb collector" design intent.
