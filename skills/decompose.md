---
layer: driver
---
# Phase Driver Brief: Decompose

Run decomposition as a driver. Return structured phase results to the operator;
do not present directly to the user.

## Purpose
Turn specs into executable waves with clear ordering and non-overlapping file
ownership.

## Required Inputs
- Implementation-ready specs.
- Definition deliverables and dependency information.
- Plan decisions from the operator context bundle.

## Required Outputs
- `plan.json` with waves, deliverables, specialist hints, ownership, and dependencies.
- Gate evidence for `decompose->implement`.

## Phase Contract
- Put every deliverable in exactly one wave.
- Respect `depends_on` through wave order.
- Prevent same-wave ownership overlap.
- Prefer independently testable vertical slices.
- Do not produce or revive `team-plan.md`.
- Dispatch a decomposition engine only for genuinely complex structure.
- Let the implement driver compose engines at dispatch time.

## Blockers
- Missing deliverable or duplicate wave assignment.
- Ownership overlap within a wave.
- Dependency order cannot be represented safely.
- Failed `decompose->implement` gate.

## Lazy References
- Plan schema: `templates/plan.json`
- Dispatch and layer model: `skills/shared/layer-protocol.md`, `skills/shared/specialist-delegation.md`
- Quality checks: `skills/shared/red-flags.md`
- Research storage: `references/research-mode.md`
- Return template: `templates/handoffs/return-formats/decompose.json`
