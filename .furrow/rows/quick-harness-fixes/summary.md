# Fix hook false positives, skill loading verbosity, and CLAUDE.md docs routing -- Summary

## Task
Fix three harness UX issues: (1) enforce CLI-mediated interaction with harness
state files instead of direct file surgery, adding missing CLI surface where needed;
(2) add guidance ensuring agents proactively maintain summary.md throughout steps
via CLI; (3) add project routing to CLAUDE.md so agents discover documentation
for sub-systems without ad-hoc exploration.

## Current State
Step: implement | Status: not_started
Deliverables: 3/3
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/quick-harness-fixes/definition.yaml
- state.json: .furrow/rows/quick-harness-fixes/state.json
- plan.json: .furrow/rows/quick-harness-fixes/plan.json
- research.md: .furrow/rows/quick-harness-fixes/research.md
- specs/: .furrow/rows/quick-harness-fixes/specs/
- team-plan.md: .furrow/rows/quick-harness-fixes/team-plan.md

## Settled Decisions
- **ideate->research**: pass — definition.yaml validated, cross-model review completed, user approved all sections
- **research->plan**: pass — research.md complete, all ideation questions resolved, CLI design and enforcement strategy determined
- **plan->spec**: pass — plan.json created with 2-wave execution, architecture decisions recorded in summary.md
- **spec->decompose**: pass — specs written for all 3 deliverables with refined ACs, interface contracts, and implementation notes
- **decompose->implement**: pass — plan.json and team-plan.md finalized, 2 waves, 2 agents, no file ownership overlap

## Context Budget
Measurement unavailable

## Key Findings
- D1: Added `rws update-summary` command to bin/rws (append/replace modes, stdin, 3 sections). Created `.claude/rules/cli-mediation.md`. Fixed broken workflow-detect.md symlink.
- D2: Updated summary-protocol.md: reconciled to ≥1 line (matches hook), added timing guidance, references CLI.
- D3: Added topic routing table to CLAUDE.md (11 categories, 88 lines total — within 100-line budget). Removed duplicate Furrow section.
## Open Questions
- None.
## Recommendations
- All 3 deliverables implemented and verified. Ready for review.
- rws update-summary tested: append, replace, invalid section rejection all work correctly.
