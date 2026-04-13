# /checkpoint [--step-end]

Save session progress for continuity across sessions or compaction.

## Behavior

1. Read `.furrow/rows/{name}/state.json` (use `rws status` to find active task).
2. If no active task: error "No active task to checkpoint."

### Default (no flags)

3. Regenerate `summary.md` via `rws regenerate-summary "{name}"`.
4. Git commit `.furrow/rows/{name}/` with message: `chore: checkpoint {name} at {step}`.
5. Display: current step, status, and artifact paths.

### With --step-end

3. Set `step_status` to `"completed"` in `state.json`.
4. Run `rws transition "{name}"` to evaluate gate.
5. Present gate results to user.
6. If gate passes and user approves: advance to next step.
7. Regenerate `summary.md` via `rws regenerate-summary "{name}"`.
8. Git commit `.furrow/rows/{name}/` with message: `chore: checkpoint {name} at {step}`.
9. After transition: run `frw run-gate` for pre-step evaluation (gate enforcement happens inside `rws transition` itself — there is no separate gate-check command).

## Output

Confirmation with: current step, step_status, deliverable progress, artifact paths.
