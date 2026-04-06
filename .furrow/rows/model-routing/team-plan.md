# Model Routing — Team Plan

## Scope Analysis
4 deliverables across 3 waves. All are harness infrastructure edits (specialist
templates and step skills). Single specialist type, no cross-domain coordination.

## Team Composition
- **harness-engineer** (1 agent) — all deliverables are same-domain harness edits

No multi-agent team needed. Lead agent executes directly using harness-engineer
specialist framing. Wave 1 deliverables (D1, D2) can be parallelized via sub-agents
since file ownership doesn't overlap.

## Task Assignment

| Wave | Deliverable | Specialist | Files |
|------|------------|------------|-------|
| 1 | specialist-model-hints | harness-engineer | specialists/*.md (16 files) |
| 1 | step-model-defaults | harness-engineer | skills/*.md (7 files) |
| 2 | consumer-wiring | harness-engineer | skills/implement.md, skills/decompose.md, skills/review.md |
| 3 | routing-docs | harness-engineer | skills/shared/context-isolation.md |

## Coordination
- Wave 1: D1 and D2 are independent — parallel sub-agents possible
- Wave 2: D3 depends on D1+D2 (references frontmatter field and model_default section)
- Wave 3: D4 depends on D3 (documents the routing instructions added in D3)
- No file ownership conflicts within any wave

## Skills
- Specialist: `specialists/harness-engineer.md`
- Specs: `specs/specialist-model-hints.md`, `specs/step-model-defaults.md`, `specs/consumer-wiring.md`, `specs/routing-docs.md`
