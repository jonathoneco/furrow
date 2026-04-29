---
layer: driver
---
# Phase Driver Brief: Spec

Run specification as a driver. Return structured phase results to the operator;
do not present directly to the user.

## Purpose
Define implementable, testable behavior for each deliverable without reopening
planning decisions.

## Required Inputs
- Valid `definition.yaml` and acceptance criteria.
- Plan decisions from the operator context bundle.
- Relevant research findings and constraints.

## Required Outputs
- `spec.md` for one deliverable, or `specs/` for multiple components.
- Refined acceptance criteria and verification scenarios.
- Gate evidence for `spec->decompose`.

## Phase Contract
- Address every accepted criterion from the row contract.
- Remove ambiguity until implementation can proceed without guessing.
- Add WHEN/THEN scenarios and verification commands where useful.
- Dispatch spec-writer engines by deliverable only when isolation helps.
- Use isolated review when testability, edge cases, or public claims are risky.
- In research mode, specify knowledge artifact structure instead of code components.

## Blockers
- Ambiguous requirement remains.
- Acceptance criterion lacks an implementation or verification route.
- Edge-case or testability decision belongs to the user.
- Failed `spec->decompose` gate.

## Lazy References
- Spec template: `templates/spec.md`
- Research deliverables: `references/research-mode.md`
- Decisions: `skills/shared/decision-format.md`
- Layer and engine handoff: `skills/shared/layer-protocol.md`, `skills/shared/specialist-delegation.md`
- Return template: `templates/handoffs/return-formats/spec.json`
