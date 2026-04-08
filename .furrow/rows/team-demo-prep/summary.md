# Prepare demo folder and script for team demo of tmux and furrow workflows -- Summary

## Task
Prepare a 10-minute team demo of the development environment (tmux integrations + furrow workflow) using this repo's real state, with a structured demo script and pre-staged outputs so sequential operations don't require live waiting.

## Current State
Step: implement | Status: not_started
Deliverables: 2/2
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/team-demo-prep/definition.yaml
- state.json: .furrow/rows/team-demo-prep/state.json
- plan.json: .furrow/rows/team-demo-prep/plan.json
- research.md: .furrow/rows/team-demo-prep/research.md
- specs/: .furrow/rows/team-demo-prep/specs/
- team-plan.md: .furrow/rows/team-demo-prep/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Definition validated. Objective: 10-min team demo of tmux+furrow. Two deliverables: DEMO.md script and pre-staged outputs. Real state from 28 rows, no fake data. Fresh-eyes review incorporated.
- **research->plan**: pass — Research complete. tmux keybindings mapped, best row (quality-and-rules) and todo (parallel-agent-orchestration-adoption) identified, roadmap ready, furrow:next pre-staging strategy confirmed. All ideation questions resolved.
- **plan->spec**: pass — Plan complete. Two deliverables sequential, no plan.json needed. DEMO.md narrative arc structure, pre-stage only furrow:next output. No open questions.
- **plan->spec**: pass — Plan complete with plan.json. Two waves: wave 1 demo-script (DEMO.md), wave 2 pre-staged-outputs (.furrow/demo/). Sequential execution, single specialist.
- **spec->decompose**: pass — Specs complete. demo-script: 5 ACs with test scenarios. pre-staged-outputs: 3 ACs with verification commands. No open questions.
- **decompose->implement**: pass — Decompose complete. plan.json: 2 waves sequential. team-plan.md: single agent, no parallel dispatch. Wave 1: DEMO.md, Wave 2: pre-staged outputs.

## Context Budget
Measurement unavailable

## Key Findings
- DEMO.md created at project root with full 10-min demo outline
- Pre-staged furrow:next output saved to .furrow/demo/next-prompt.txt
- roadmap.md verified (204 lines), todos.yaml verified with target todo
- All ACs verified: prep checklist (3 items), keybindings, commands, narrative framing
- Note: alm next has a bug (.work_units vs .rows in jq) — output was manually constructed from roadmap.yaml data
## Open Questions
(none)
## Recommendations
- Rehearse once with stopwatch before the demo
- Consider filing a bug for alm next .work_units/.rows mismatch
