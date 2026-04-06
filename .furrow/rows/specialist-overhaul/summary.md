# Encoded reasoning, template enforcement, step-specific modes, and new specialist domains -- Summary

## Task
Upgrade the specialist system: deepen encoded reasoning in all 15 existing templates, enforce specialist loading during implementation, add step-level specialist modifiers to relevant step skills, expand the roster with frontend/design and strategic specialist domains, and fix the gate-check hook that blocks manual transitions from non-auto-advanceable steps, collapse the two-phase transition ceremony into a single atomic command, and prevent the review step from self-answering TODO extraction questions by borrowing consent from unrelated prior user responses.

## Current State
Step: implement | Status: not_started
Deliverables: 0/6 (defined)
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/specialist-overhaul/definition.yaml
- state.json: .furrow/rows/specialist-overhaul/state.json
- plan.json: .furrow/rows/specialist-overhaul/plan.json
- research/: .furrow/rows/specialist-overhaul/research/
- specs/: .furrow/rows/specialist-overhaul/specs/
- team-plan.md: .furrow/rows/specialist-overhaul/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Gate evaluation PASS — all 5 dimensions (completeness, alignment, feasibility, cross-model, seed-sync) passed. Verdict: post_step-ideate.json
- **research->plan**: pass — Gate evaluation PASS — all 5 dimensions (coverage, evidence-basis, specificity, contradiction-check, seed-sync) passed
- **plan->spec**: pass — Gate evaluation PASS — all 5 dimensions passed (coverage, feasibility, specificity, research-grounding, seed-sync)
- **spec->decompose**: pass — Gate evaluation PASS — all 5 dimensions (testability, completeness, consistency, implementability, seed-sync) passed
- **decompose->implement**: pass — Gate evaluation PASS — all 6 dimensions (granularity, parallelism, coverage, ownership-clarity, vertical-slicing, seed-sync) passed

## Context Budget
Measurement unavailable

## Key Findings
- plan.json from plan step is decompose-ready — all 6 deliverables are vertical slices, no file overlap within waves, depends_on respected
- 4 waves: W1 (hook fix + specialist upgrades, parallel), W2 (consent isolation + new specialists, parallel), W3 (enforcement wiring, solo), W4 (transition simplification, solo)
- Each deliverable is independently testable without requiring others to complete first (within wave constraints)

## Open Questions
- None — decomposition verified against plan step artifacts

## Recommendations
- Proceed to implement — all artifacts ready
- Wave 1 can start immediately with parallel agents for hook fix and specialist upgrades
- specialist-reasoning-upgrade is the heaviest deliverable (15 specialists, 4 internal phases) — consider it the critical path
