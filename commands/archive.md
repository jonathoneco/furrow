# /archive [name]

Archive a completed work unit after review passes.

## Arguments

- `name` (optional): Work unit name. If absent, archives the active task.

## Pre-Conditions

Review step must have passed. Check `state.json.gates[]` for a gate with
`boundary` containing `->review` or `implement->review` and `outcome: "pass"`.
If not found: error with message indicating what is blocking archive.

## Behavior

1. Find task via `commands/lib/detect-context.sh` or by `name` argument.
2. Read `state.json`. Verify review gate passed.
3. If review not passed:
   - Error: "Cannot archive: review step has not passed."
   - Show current step, status, and last gate outcome.

4. **Learnings promotion**: Run `commands/lib/promote-learnings.sh "{name}"`.
   - Present per-unit learnings from `.work/{name}/learnings.jsonl`.
   - Ask user which learnings to promote to project-level `learnings.jsonl`.

5. **Component promotion**: Run `commands/lib/promote-components.sh "{name}"`.
   - Present candidate artifacts for promotion to project docs/rules.
   - Ask user which to promote.

6. Set `state.json.archived_at` to current ISO 8601 timestamp.
7. Regenerate final `summary.md` via `commands/lib/generate-summary.sh "{name}"`.
8. Git commit with message: `chore: archive {name}`.

## Output

Confirmation: task name, final status, promoted learnings count, archive timestamp.
