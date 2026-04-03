# Almanac knowledge subcommands and rws review-archive flow -- Summary

## Task
Add knowledge management subcommands to alm (learn with full lifecycle, rationale, plus stubs for docs/specialists/history) and fix the rws review-archive flow with explicit deliverable tracking subcommands.

## Current State
Step: review | Status: completed
Deliverables: 2/2
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/cli-enhancements/definition.yaml
- state.json: .furrow/rows/cli-enhancements/state.json
- plan.json: .furrow/rows/cli-enhancements/plan.json
- research.md: .furrow/rows/cli-enhancements/research.md
- spec.md: .furrow/rows/cli-enhancements/spec.md
- specs/: .furrow/rows/cli-enhancements/specs/

## Settled Decisions
- **ideate->research**: pass — definition validated, well-scoped additive work
- **research->plan**: pass — existing protocol and data formats documented
- **plan->spec**: pass — single wave, two parallel deliverables, no file ownership conflicts
- **spec->decompose**: pass — implementation-ready spec with exact interfaces
- **spec->decompose**: pass — specs directory created
- **decompose->implement**: pass — single wave, two parallel deliverables, plan.json valid
- **decompose->implement**: pass — branch set, plan.json valid
- **implement->review**: pass — both deliverables implemented, 85 tests passing

## Context Budget
Measurement unavailable

## Key Findings
- Learnings protocol defined in skills/shared/learnings-protocol.md
- promote-learnings.sh was deleted — logic reimplemented in alm learn --promote
- rationale.yaml already in .furrow/almanac/ from migration

## Open Questions
None.

## Recommendations
- Both deliverables are independent — can implement in parallel
