# Step: Decompose

## What This Step Does
Break spec into executable work items with concurrency map (waves).

## What This Step Produces
- `plan.json` with wave assignments and specialist mappings
- `team-plan.md` with coordination strategy

## Step-Specific Rules
- Every deliverable must appear in exactly one wave.
- `depends_on` ordering must be respected across waves.
- `file_ownership` globs must not overlap within a wave.
- Read `summary.md` for spec context.

## Shared References
- `skills/shared/red-flags.md` — before finalizing decomposition
- `skills/shared/git-conventions.md` — before any commit
- `skills/shared/learnings-protocol.md` — when capturing learnings
- `skills/shared/context-isolation.md` — when planning agent teams
- `skills/shared/summary-protocol.md` — before completing step

## Team Planning
Write `team-plan.md` before dispatching sub-agents (>1 deliverable).
Sections: Scope Analysis, Team Composition, Task Assignment, Coordination, Skills.
Team sizing: 2-3 specialists for 2-3 deliverables; 4+: 2-3 agents multi-tasking.
Validate: every deliverable assigned, ownership globs match, skills exist.
Resolve specialist templates from `specialists/*.md` by domain value.

## Step Mechanics
Transition out: gate record `decompose->implement` with `pass` required.
Pre-step shell check (`gate-precheck.sh`): <=2 deliverables, no depends_on, same
specialist type, not supervised, not force-stopped.
Pre-step evaluator (`evals/gates/decompose.yaml`): wave-triviality — can all
deliverables execute in a single wave without coordination? Per `skills/shared/gate-evaluator.md`.
At this boundary, `scripts/create-work-branch.sh` creates the work branch.
Next step expects: `plan.json` with waves, `team-plan.md` with coordination.

## Learnings
Append reusable insights to `.work/{name}/learnings.jsonl`.
Read `skills/shared/learnings-protocol.md` for schema and categories.

## Research Mode
When `state.json.mode` is `"research"`:
- File ownership: `.work/{name}/deliverables/{section-name}.md` (not git tree).
- Specialists: research-domain experts (`domain-researcher`,
  `comparative-analyst`, `synthesis-writer`).
- Waves organize authoring sections; dependencies reflect authoring order.
- Read `references/research-mode.md` for storage conventions.
