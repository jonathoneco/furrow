# Step: Plan

## What This Step Does
Synthesize research into architecture decisions and execution strategy.

## What This Step Produces
- Architecture decisions recorded in `summary.md`
- `plan.json` if parallel execution is needed (multiple deliverables)
- `team-plan.md` if agent teams will be used

## Step-Specific Rules
- Every deliverable from `definition.yaml` must have a clear implementation path.
- Architecture decisions must reference research findings, not assumptions.
- Ensure `skills/work-context.md` is loaded.
- Read `summary.md` for research context.

## Shared References
Read these when relevant to your current action:
- `skills/shared/red-flags.md` — before finalizing plan
- `skills/shared/learnings-protocol.md` — when capturing learnings

## Team Planning
When `plan.json` has multiple deliverables, create `team-plan.md` with specialist
assignments per deliverable. Read `references/specialist-template.md` for format.
Assign `file_ownership` globs to prevent cross-specialist conflicts in waves.

## Step Mechanics
Transition out: gate record `plan->spec` with outcome `pass` required.
Auto-advance when: single deliverable with no dependencies and no parallelism.
Next step expects: architecture decisions in `summary.md`, `plan.json` if
parallel execution needed, and clear implementation path per deliverable.

## Learnings
When you discover a reusable insight (pattern, pitfall, preference, convention,
or dependency quirk), append it to `.work/{name}/learnings.jsonl` using the
learning schema. Read `skills/shared/learnings-protocol.md` for format.
