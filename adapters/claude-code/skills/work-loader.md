# Work Loader — Claude Code Adapter

## Purpose
Activate work context when the user invokes a work command.

## Activation
This skill loads when a `/work` command runs or when recovering context.

## Work Discovery

1. Scan `.work/*/state.json` for files where `archived_at` is null.
2. If no active work unit found, report "No active work unit" and exit.
3. If multiple active work units found, list them and ask the user to specify.

## Context Loading

Once the active work unit is identified:

1. Read `state.json` — extract `step`, `step_status`, `mode`, and deliverable progress.
2. Read `summary.md` — load synthesized context from the previous step.
3. Determine the current step's skill file: `skills/{step}.md`.
4. Read the step skill file for current step guidance.

## State Display

Present the current state to the user:

```
Task: {title}
Step: {step} | Status: {step_status}
Mode: {mode}
Deliverables: {completed}/{total}
Gate policy: {gate_policy from definition.yaml}
```

## What This Skill Reads

- `.work/{name}/state.json` — current step and progress
- `.work/{name}/summary.md` — context recovery
- `skills/{step}.md` — current step guidance

## What This Skill Does NOT Read

- `definition.yaml` — read on demand by step skills, not at activation
- `plan.json` — read on demand during decompose/implement steps
- `reviews/*.json` — read on demand during review step
- Raw research notes — use `summary.md` instead

## Progressive Loading

After initial load, additional context is loaded on demand per the step:
- Reference files are indexed but NOT injected — read when needed.
- Step transitions replace the step skill (old step skill is dropped).
- See `progressive-loading.yaml` for the step-to-skill mapping.

## Error Handling

- Missing `state.json`: warn and suggest `/work` to create a new work unit.
- Missing `summary.md`: warn but continue (may be first step).
- Missing step skill file: error — the harness installation may be incomplete.
- Invalid `state.json` schema: error with validation details.
