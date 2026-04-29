# /archive [name]

Archive a completed row after review passes.

## Arguments

- `name` (optional): Row name. If absent, archives the active task.

## Pre-Conditions

Review step must have passed. Check `state.json.gates[]` for a gate with
`boundary` containing `->review` or `implement->review` and `outcome: "pass"`.
If not found: error with message indicating what is blocking archive.

## Behavior

1. Find task via `furrow row status` or by `name` argument.
2. Read `state.json`. Verify review gate passed.
3. If review not passed:
   - Error: "Cannot archive: review step has not passed."
   - Show current step, status, and last gate outcome.

4. **Learnings promotion**: Run `commands/lib/promote-learnings.sh "{name}"`.
   - Present per-row learnings from `.furrow/rows/{name}/learnings.jsonl`.
   - Ask user which learnings to promote to project-level `learnings.jsonl`.

5. **Component promotion**: Run `commands/lib/promote-components.sh "{name}"`.
   - Present candidate artifacts for promotion to project docs/rules.
   - Ask user which to promote.

6. **TODO extraction**: Run the extract mode of `/work-todos --extract {name}`.
   - Uses the temporary compatibility holdout `alm extract "{name}"` to harvest candidates
     from summary.md open questions, learnings.jsonl unpromoted pitfalls,
     and reviews/*.json failed dimensions.
   - Agent deduplicates candidates against existing `.furrow/almanac/todos.yaml` entries.
   - Presents candidates with proposed actions (add/merge/skip).
   - User confirms. Writes to `.furrow/almanac/todos.yaml` and validates.
   - If no candidates found, skip silently.

7. **TODO pruning**: Check if `definition.yaml` has a canonical `source_todos` field.
   For historical definitions only, treat singular `source_todo` as a read-only
   fallback and normalize it to the same candidate list.
   - If set, read `.furrow/almanac/todos.yaml` and find entries matching those IDs.
   - For each match, present: "This row was started from TODO '{id}': {title}. Mark as resolved?"
   - **yes**: Remove the entry from `.furrow/almanac/todos.yaml`.
   - **no**: Keep as-is.
   - **partial**: Add a note to the entry's context indicating partial completion,
     bump `updated_at`.
   - If no `source_todos` are set and no historical fallback is present, or
     `.furrow/almanac/todos.yaml` has no matching entries, skip.
   - Validate `.furrow/almanac/todos.yaml` after any changes.

8. **Observations surface**: Run the temporary compatibility holdout
   `alm observe on-archive "{name}"`.
   - Displays any observations whose activation became `active` as a result
     of this row's archival (e.g., row_archived triggers whose `row` matches,
     or rows_since triggers whose count threshold just crossed).
   - **Surface only** — does NOT auto-resolve or auto-dismiss. Users handle
     each with temporary compatibility holdouts
     `alm observe resolve <id> ...` or `alm observe dismiss <id> ...` as
     separate explicit steps, outside /archive.
   - If no observations activate, prints a single line and moves on.

9. Run `furrow row archive "{name}"` to set `state.json.archived_at` through the
   Go archive-readiness gate. Do not use `rws archive` for gated rows; it does
   not own completion-evidence truth checks.
10. Regenerate final `summary.md` through the temporary compatibility holdout
    `rws regenerate-summary "{name}"` until a Go-backed summary command exists.
11. Git commit with message: `chore: archive {name}`.

## Output

Confirmation: task name, final status, promoted learnings count, archive timestamp.
