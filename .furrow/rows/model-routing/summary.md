# Add Sonnet/Opus model routing hints to specialist templates and step skills -- Summary

## Task
Add model routing hints to Furrow specialist templates and step skills so the lead agent knows which Claude model (Sonnet or Opus) to use when spawning sub-agents. Two-tier resolution: specialist model_hint overrides step model_default, which overrides project default (sonnet).

## Current State
Step: decompose | Status: pending_approval
Deliverables: 0/4
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/model-routing/definition.yaml
- state.json: .furrow/rows/model-routing/state.json
- plan.json: .furrow/rows/model-routing/plan.json
- research.md: .furrow/rows/model-routing/research.md
- specs/: .furrow/rows/model-routing/specs/
- team-plan.md: .furrow/rows/model-routing/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Definition validated. User approved objective, deliverables, context pointers, constraints, and gate policy. Cross-model review incorporated decompose.md and review.md as additional consumers.
- **research->plan**: pass — Research complete: all 4 deliverables have confirmed implementation targets. Uniform specialist frontmatter, clear dispatch insertion points in implement/decompose/review, context-isolation insertion point identified.
- **plan->spec**: pass — Plan complete: 2-wave execution (D1+D2 parallel, D3+D4 sequential), single harness-engineer specialist, plan.json validated.
- **plan->spec**: pass — Plan complete: 3-wave execution (D1+D2 parallel, D3 consumer-wiring, D4 routing-docs), single harness-engineer specialist, plan.json validated.
- **spec->decompose**: pass — Specs complete: 4 deliverables specified with exact insertion points, before/after examples, and verification commands. All ACs refined to be testable.
- **decompose->implement**: pass — Decompose complete: 4 deliverables populated in state.json, 3-wave plan.json, team-plan.md written. Single harness-engineer specialist, no multi-agent team needed.

## Context Budget
Measurement unavailable

## Key Findings
- All 4 deliverables implemented: specialist-model-hints (15 files), step-model-defaults (7 files), consumer-wiring (3 files), routing-docs (1 file)
- D1: 3 opus (systems-architect, complexity-skeptic, security-engineer) + 12 sonnet across 15 specialist templates
- D2: 2 opus (research, review) + 5 sonnet across 7 step skills
- D3: routing instructions added to implement.md, decompose.md, review.md
- D4: Model Resolution section added to context-isolation.md

## Open Questions
- None — implementation complete

## Recommendations
- Advance to review for AC verification
