# Team Plan: dual-review-delegation

## Scope Analysis

2 deliverables across 2 sequential waves. Wave 2 depends on Wave 1 (scenarios field must exist before new specialists can use it). Each wave has 1 deliverable — no parallelism within waves.

## Team Composition

| Wave | Deliverable | Specialist | Model Hint | Scenario Matched |
|------|-------------|-----------|------------|------------------|
| 1 | dual-review-and-specialist-delegation | harness-engineer | sonnet | "Workflow harness infrastructure — shell scripts, hooks, validation pipelines" |
| 2 | new-specialist-templates | prompt-engineer | opus | "Structural constraint over behavioral instruction, failure mode prediction" |

## Task Assignment

### Wave 1: dual-review-and-specialist-delegation (harness-engineer, sonnet)

**Group A — Specialist System**:
1. Add `scenarios` field to all 21 entries in `specialists/_meta.yaml`
2. Add scenarios normative requirement to `references/specialist-template.md`

**Group B — Shared Delegation Protocol**:
3. Create `skills/shared/specialist-delegation.md` (~15 lines)
4. Add one-line reference in Shared References section of: ideate.md, research.md, plan.md, spec.md, decompose.md

**Group C — Dual-Review Protocol**:
5. Add Dual-Reviewer Protocol section to `skills/plan.md` (after Step Mechanics)
6. Add Dual-Reviewer Protocol section to `skills/spec.md` (after Step Mechanics)

**Group D — Cross-Model Infrastructure**:
7. Add `--plan` and `--spec` flags + `_cross_model_plan()` and `_cross_model_spec()` functions to `cross-model-review.sh`
8. Add `dual-review` dimension to `evals/gates/plan.yaml` additional_dimensions
9. Add `dual-review` dimension to `evals/gates/spec.yaml` additional_dimensions

### Wave 2: new-specialist-templates (prompt-engineer, opus)

1. Create `specialists/llm-specialist.md` (≤80 lines, per spec)
2. Create `specialists/test-driven-specialist.md` (≤80 lines, per spec)
3. Register both in `specialists/_meta.yaml` with scenarios

## Coordination

- Wave 2 blocks on Wave 1 completion (scenarios field schema must exist)
- Within Wave 1: Group A → B → C/D (groups C and D are independent of each other)
- `specialists/_meta.yaml` is touched by both waves — Wave 2 appends entries after Wave 1 adds scenarios to existing entries

## Skills

- `skills/shared/context-isolation.md` — for agent dispatch isolation rules
- `references/specialist-template.md` — normative specialist requirements
- Spec files: `specs/dual-review-and-specialist-delegation.md`, `specs/new-specialist-templates.md`
