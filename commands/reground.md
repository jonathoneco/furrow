# /reground [name]

Recover context after session break or compaction event.

## Arguments

- `name` (optional): Specific work unit. If absent, uses active task.

## Behavior (per spec 00 SS5.4)

Read ONLY these three sources:

1. **state.json**: current step, step_status, deliverable progress, gate history.
2. **summary.md**: latest synthesized context (key findings, decisions, open questions).
3. **Current step skill**: `skills/{step}.md` for the active step.

Display a compact status:
```
Task: {name} — {title}
Step: {step} | Status: {step_status}
Mode: {mode}
Deliverables: {completed}/{total}
Last gate: {boundary} -> {outcome}
```

## What NOT To Read

- Raw research notes (`research/` directory)
- Previous step handoff summaries
- Full gate evidence files (`gates/` directory)
- Session transcripts or checkpoint history

## Output

Status display + current step skill loaded. Agent is ready to continue work.
The user can then run `/work` to resume the current step.
