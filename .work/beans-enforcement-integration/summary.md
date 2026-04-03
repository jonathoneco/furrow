# Beans task management for enforcement layer and programmatic checks — Summary

## Task
Integrate Seeds as mandatory core infrastructure into Furrow, unify row lifecycle management under the rws CLI, create the alm CLI for planning and knowledge management, and restructure all harness state under .furrow/ — executing as a clean swap with no intermediate state.

## Current State
Step: decompose — plan.json validated (4 waves, 7 deliverables, no file ownership conflicts)
Deliverables: 0/7 (decomposed)
Mode: code

## Artifact Paths
- definition.yaml: .work/beans-enforcement-integration/definition.yaml
- state.json: .work/beans-enforcement-integration/state.json
- plan.json: .work/beans-enforcement-integration/plan.json
- research/: .work/beans-enforcement-integration/research/
- specs/: .work/beans-enforcement-integration/specs/
- team-plan.md: .work/beans-enforcement-integration/team-plan.md

## Settled Decisions
- **ideate->research**: pass — definition.yaml validated, all 16 design decisions settled through interactive ideation with user, cross-model outside voice review completed, summary written
- **research->plan**: pass — 5 parallel research tracks completed: sds fork analysis, rws architecture, gate integration, roadmap schema, alm CLI. Research directory with synthesis written. All ideation questions addressed.
- **plan->spec**: pass — 7 deliverables across 4 waves planned. Architecture decisions: CLIs as abstraction layer, domain hooks fold into rws, policy hooks stay separate. Operational ordering defined with checkpoints. D6 (tests) and D7 (docs) added.
- **spec->decompose**: pass — 7 implementation-ready specs written covering all deliverables
- **decompose->implement**: plan.json validated — 4 waves, 7 deliverables, dependency ordering respected, no file ownership conflicts within waves

## Context Budget
Measurement unavailable

## Key Findings
- sds: 11 subcommands, ~500 lines, fork from bn with 10-value status enum
- rws: 13 public subcommands + 9 internal functions, ~1200 lines, absorbs 21 files
- alm: 8 subcommands with roadmap.yaml schema, ~800 lines, absorbs 3 scripts
- Gate: Phase A (deterministic seed check) + Phase B (evaluator seed-sync dimension)
- Total new code: ~2500 lines across 3 CLIs
- Total files deleted: ~24 (scripts + hooks + old tests)

## Open Questions
None — all design questions resolved.

## Recommendations
- Commit specs before decompose — these are the implementation contract
- Wave 1 (restructure + sds) is mechanical and low-risk
- Wave 2 (rws + alm) is the bulk of new code
- Wave 3 (integration) is small (~140 lines) but high-impact
- Wave 4 (tests + docs) validates everything
