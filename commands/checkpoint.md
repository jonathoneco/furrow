# /checkpoint [--step-end]

Save session progress for continuity across sessions or compaction.

## Behavior

1. Read `.furrow/rows/{name}/state.json` (use `furrow row status` to find active task).
2. If no active task: error "No active task to checkpoint."

### Default (no flags)

3. Regenerate `summary.md` via the legacy `rws regenerate-summary "{name}"`
   compatibility wrapper.
4. Git commit `.furrow/rows/{name}/` with message: `chore: checkpoint {name} at {step}`.
5. Display: current step, status, and artifact paths.

### With --step-end

3. Run `furrow row complete "{name}"` to set `step_status` to `"completed"` through the backend.
4. Run `furrow row transition "{name}" --step <next-step>` to evaluate the backend transition gate.
5. Present gate results to user.
6. If gate passes and user approves: advance to next step.
7. Regenerate `summary.md` via the legacy `rws regenerate-summary "{name}"`
   compatibility wrapper.
8. Git commit `.furrow/rows/{name}/` with message: `chore: checkpoint {name} at {step}`.
9. After transition: gate enforcement happens inside `furrow row transition`; there is no separate `furrow gate` command in the current Go CLI.

## Output

Confirmation with: current step, step_status, deliverable progress, artifact paths.
