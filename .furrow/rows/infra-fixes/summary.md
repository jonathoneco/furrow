# FURROW_ROOT resolution, gate-check fix, template enforcement, config move, blocking stop hooks -- Summary

## Task
Fix infrastructure gaps blocking reliable harness operation: introduce PROJECT_ROOT for correct path resolution in consumer projects, enforce specialist template loading during implementation, move furrow.yaml to its natural .furrow/ home with source_todo wiring, and add ideation-mode cross-model review with correct codex invocation.

## Current State
Step: review | Status: completed
Deliverables: 4/4
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/infra-fixes/definition.yaml
- state.json: .furrow/rows/infra-fixes/state.json
- plan.json: .furrow/rows/infra-fixes/plan.json
- research/: .furrow/rows/infra-fixes/research/
- specs/: .furrow/rows/infra-fixes/specs/
- team-plan.md: .furrow/rows/infra-fixes/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Definition validated, dual outside voice (same-model + codex/gpt-5.4) completed, 4 deliverables confirmed, scope cuts approved
- **research->plan**: pass — Research complete: 4 research files produced, all open questions resolved, FURROW_ROOT audit (11 bugs in 8 files), specialist gap narrower than expected, config move mapped (9 files), cross-model ideation designed
- **plan->spec**: pass — Plan complete: 2-wave execution, plan.json and team-plan.md produced, architecture decisions recorded, file ownership clean
- **spec->decompose**: pass — 4 implementation-ready specs produced with interface contracts, refined ACs, test scenarios, and implementation notes
- **decompose->implement**: pass — Decomposition validated: 2 waves, 4 deliverables, no file overlap within waves, model hints documented, coordination strategy clear
- **implement->review**: pass — All 4 deliverables implemented and verified: PROJECT_ROOT (11 fixes), specialist enforcement (warn+proceed), config move (9 files + source_todo), cross-model ideation (--ideation flag + codex fix)
- **implement->review**: pass — All 4 deliverables implemented, committed (3d41116), verified: zero FURROW_ROOT leaks, codex approval_policy fixed, doctor baseline unchanged

## Context Budget
Measurement unavailable

## Key Findings
- All 4 deliverables implemented and reviewed
- Review found 2 important issues: missing .furrow/furrow.yaml in candidate loops (cross-model-review.sh, auto-install.sh, launch-phase.sh) — fixed in 9503f3a
- 2 commits: 3d41116 (main implementation, 22 files) + 9503f3a (review fixes, 4 files)
- Zero FURROW_ROOT project-relative leaks, all furrow.yaml readers have candidate loops
- Doctor baseline unchanged (pre-existing budget violations only)

## Open Questions
- None — implementation complete, all verifications pass

## Recommendations
- Ready for review step
- Consider running integration tests if available: bin/frw run-integration-tests
- Commit all changes with conventional commit message
