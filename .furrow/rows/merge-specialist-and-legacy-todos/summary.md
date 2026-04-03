# Merge specialist template and legacy TODO migration -- Summary

## Task
Create the merge-specialist reasoning template, update the harness-engineer specialist to reflect V2 Furrow architecture, and bring rationale.yaml up to date with all current harness components — completing pre-merge hygiene for the work/beans-integration branch.

## Current State
Step: review | Status: completed
Deliverables: 4/4
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/merge-specialist-and-legacy-todos/definition.yaml
- state.json: .furrow/rows/merge-specialist-and-legacy-todos/state.json
- plan.json: .furrow/rows/merge-specialist-and-legacy-todos/plan.json
- research.md: .furrow/rows/merge-specialist-and-legacy-todos/research.md
- specs/: .furrow/rows/merge-specialist-and-legacy-todos/specs/
- team-plan.md: .furrow/rows/merge-specialist-and-legacy-todos/team-plan.md

## Settled Decisions
- **ideate->research**: pass — definition validated: 3 deliverables, supervised gate policy, cross-model review completed
- **research->plan**: pass — research complete: 4 deliverables researched, all implementation approaches clear, single wave feasible
- **plan->spec**: pass — plan complete: single wave, 4 parallel deliverables, plan.json created, no agent team needed
- **spec->decompose**: pass — specs complete: 4 implementation-ready specs in specs/, all ACs addressable
- **decompose->implement**: pass — decompose complete: plan.json single wave, team-plan.md 2-agent split, no ownership overlaps
- **implement->review**: pass — implement complete: 4/4 deliverables done, 85 tests passing, todos validated, roadmap regenerated
- **implement->review**: pass — implement complete: 4/4 deliverables done, 85 tests passing, committed 13a1188

## Context Budget
Measurement unavailable

## Key Findings
- **Review passed all 4 deliverables**: merge-specialist (7/7 AC), harness-engineer-grounding (4/4 AC), rationale-update (6/6 AC after correction), todos-roadmap-refresh (5/5 AC)
- **1 review correction**: merge-specialist.md was missing its own rationale entry — fixed in commit 5e33adf
- **85 tests still passing**: no regressions from any changes
- **New TODO captured**: specialist-templates-from-team-plan-not-enforced — real architectural gap discovered during this row's implementation

## Open Questions
- None — review complete, all criteria met.

## Recommendations
- Archive this row and proceed to merge work/beans-integration → main via scripts/merge-to-main.sh.
- Bootstrap gap: merge-specialist cannot guide this merge — use merge-to-main.sh directly.
