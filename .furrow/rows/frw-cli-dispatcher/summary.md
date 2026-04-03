# Add frw CLI dispatcher — centralize path resolution for hooks, scripts, and sub-CLIs -- Summary

## Task
Create frw, a modularized POSIX sh CLI that centralizes all harness-level concerns (hooks, scripts, init, install, doctor) behind a single PATH-resolved entry point, eliminating relative path fragility and consolidating scattered shell scripts into a coherent tool.

## Current State
Step: implement | Status: pending_approval
Deliverables: 6/6
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/frw-cli-dispatcher/definition.yaml
- state.json: .furrow/rows/frw-cli-dispatcher/state.json
- plan.json: .furrow/rows/frw-cli-dispatcher/plan.json
- research.md: .furrow/rows/frw-cli-dispatcher/research.md
- specs/: .furrow/rows/frw-cli-dispatcher/specs/
- team-plan.md: .furrow/rows/frw-cli-dispatcher/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Definition approved with 6 deliverables, modularized architecture, supervised gate policy
- **research->plan**: pass — Research complete — 90+ refs mapped, 3 open questions resolved, agent-sdk adapter migration included in D6
- **plan->spec**: pass — Plan complete — 4 waves, 6 deliverables, architecture decisions recorded, plan.json validated
- **spec->decompose**: pass — Specs complete — 6 implementation-ready specs with interface contracts, refined ACs, and dependency maps
- **decompose->implement**: pass — Decompose complete — 4 waves, team plan with 3 parallel wave-2 agents, plan.json validated
- **implement->review**: pass — Implementation complete — 6/6 deliverables, frw CLI operational, 90+ refs updated, old dirs deleted, install check passes
- **implement->review**: pass — Implementation complete — 6/6 deliverables, 5 commits, frw operational from PATH

## Context Budget
Measurement unavailable

## Key Findings
- **rws is simpler than expected**: only 2 direct script refs (lines 456, 903). sds and alm have zero.
- **~90+ total references**: 15 in commands/skills/references, 32 in rationale.yaml, 19 in todos.yaml, 11 in install.sh, plus tests and adapters
- **Agent SDK blocker for deletion**: `adapters/agent-sdk/` hardcodes `hooks/lib/validate.sh` — included in D6

## Open Questions
- None remaining — all resolved in research

## Recommendations
- Wave 2 deliverables can be parallelized across agents since file_ownership doesn't overlap
- D6 final commit (directory deletion) should be gated on `frw doctor` passing with new paths
