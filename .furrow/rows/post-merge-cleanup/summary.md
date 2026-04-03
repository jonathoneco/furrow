# Post-merge cleanup: fix path refs, CLI install, step budgets -- Summary

## Task
Fix post-beans-integration drift: CLI PATH install, stale path references in scripts/commands, and stale .focused file

## Current State
Step: review | Status: completed
Deliverables: 5/5
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/post-merge-cleanup/definition.yaml
- state.json: .furrow/rows/post-merge-cleanup/state.json
- plan.json: .furrow/rows/post-merge-cleanup/plan.json
- research.md: .furrow/rows/post-merge-cleanup/research.md
- spec.md: .furrow/rows/post-merge-cleanup/spec.md
- specs/: .furrow/rows/post-merge-cleanup/specs/
- team-plan.md: .furrow/rows/post-merge-cleanup/team-plan.md

## Settled Decisions
- **ideate->research**: pass — definition.yaml validated; 4 deliverables approved by user
- **research->plan**: pass — 19 stale references identified across furrow-doctor.sh, measure-context.sh, alm, commands/furrow.md, and command specs; CLI symlink issue confirmed
- **research->plan**: pass — research artifact written; 19 stale refs mapped
- **research->plan**: pass — research complete; 19 stale refs mapped
- **plan->spec**: pass — plan: 3 waves — script fixes, command spec fixes, state cleanup + verify
- **plan->spec**: pass — plan: 3 waves — scripts+CLI, command specs, state cleanup
- **spec->decompose**: pass — spec complete: 5 deliverables with line-level change tables
- **spec->decompose**: pass — spec complete: 5 per-deliverable specs in specs/
- **decompose->implement**: pass — decompose: plan.json + team-plan.md ready, single-agent execution
- **implement->review**: pass — all 5 deliverables implemented + bonus rationale cleanup; doctor down 27→8 (remaining are out-of-scope skill budgets)
- **implement->review**: pass — all deliverables implemented and committed; doctor 27→8 failures (remaining are out-of-scope skill budgets)

## Context Budget
Measurement unavailable

## Key Findings
- 19 stale path references across scripts, commands, and bin/alm after beans-integration restructure — all fixed
- CLIs (alm, rws, sds) symlinked to ~/.local/bin — all resolve
- `.furrow/.focused` updated to active row
- skills/plan.md and spec.md now reference their template files
- 19 stale rationale.yaml entries removed (absorbed scripts/commands)
- furrow-doctor.sh down from 27 to 8 failures (remaining 8 are step skill budgets — out of scope)

## Open Questions
- None

## Recommendations
- Step skill budgets (50-line max) can be addressed in a follow-up row
