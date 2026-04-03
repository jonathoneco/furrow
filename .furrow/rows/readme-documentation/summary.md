# Add README with general info and guidance about the harness -- Summary

## Task
Add a README.md that orients first-time readers on what Furrow is, what using it feels like, how to install it, and where to go deeper.

## Current State
Step: review | Status: completed
Deliverables: 1/1
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/readme-documentation/definition.yaml
- state.json: .furrow/rows/readme-documentation/state.json
- plan.json: .furrow/rows/readme-documentation/plan.json
- research.md: .furrow/rows/readme-documentation/research.md
- spec.md: .furrow/rows/readme-documentation/spec.md

## Settled Decisions
- **ideate->research**: pass — definition.yaml validated, cross-model review completed, all sections approved by user
- **research->plan**: pass — All open questions resolved, source material gathered, walkthrough format and Agent SDK scope decided
- **plan->spec**: pass — Architecture decisions recorded: section order, command table split, walkthrough format, no parallelism needed
- **spec->decompose**: pass — Spec covers all 8 ACs across 7 sections, ~143 lines estimated
- **decompose->implement**: pass — Single deliverable, single file — no decomposition needed
- **decompose->implement**: pass — plan.json created, single wave single deliverable
- **implement->review**: pass — README.md written, 110 lines, all 8 ACs met, deliverable marked complete
- **implement->review**: pass — README.md committed, all ACs met

## Context Budget
Measurement unavailable

## Key Findings
- Option B scope: ~150-200 line README covering what/why/install/commands/concepts
- Walkthrough format: annotated command sequence (durable, scannable, model-independent)
- Agent SDK: mention briefly (one sentence + pointer to adapters/), don't feature
- Section order: one-liner → walkthrough → prerequisites/install → commands → concepts → going deeper
- Command table split: "Working" (daily) vs "Managing" (infrastructure)
- No plan.json or team needed — single deliverable, single file
- Install is straightforward: clone + install.sh creates 4 CLI symlinks, then frw install --project
- 14 commands, 7 steps, 16 specialists — enough to summarize, not enumerate exhaustively

## Open Questions
(All resolved in research.md)

## Recommendations
- Lead with annotated command sequence walkthrough
- Split commands into "daily use" vs "infrastructure" groups in table
- Keep install to clone + two commands
- One sentence on Agent SDK with pointer to adapters/
