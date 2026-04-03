# Merge specialist template and legacy TODO migration -- Summary

## Task
Create the merge-specialist reasoning template, update the harness-engineer specialist to reflect V2 Furrow architecture, bring rationale.yaml up to date, and refresh todos/roadmap — completing pre-merge hygiene for the work/beans-integration branch.

## Current State
Step: implement | Status: in_progress
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
- **ideate->research**: pass — definition validated, supervised gate policy, cross-model review completed
- **research->plan**: pass — 4 deliverables researched, all approaches clear, single wave feasible
- **plan->spec**: pass — single wave, 4 parallel deliverables, no agent team needed
- **spec->decompose**: pass — 4 implementation-ready specs, all ACs addressable
- **decompose->implement**: pass — plan.json single wave, team-plan.md 2-agent split, no ownership overlaps

## Context Budget
Measurement unavailable

## Key Findings
- **All 4 deliverables implemented**: merge-specialist.md created, harness-engineer.md updated, rationale.yaml extended (25 entries), todos.yaml refreshed (7 done, 1 new TODO added)
- **85 tests passing**: 14 alm + 12 lifecycle + 35 rws + 24 sds — no regressions
- **Staleness audit**: seeds-concept kept active (different scope than implemented seeds), work-folder-structure kept active (not addressed by namespace-rename), duplication-cleanup already done
- **New TODO added**: specialist-templates-from-team-plan-not-enforced — specialist templates assigned in plan.json are not loaded during agent dispatch

## Open Questions
- None — all deliverables complete and validated.

## Recommendations
- Commit all changes before advancing to review.
- Bootstrap gap is documented — first merge of this branch uses scripts/merge-to-main.sh directly.
