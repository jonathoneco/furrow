---
name: "driver:ideate"
description: "Phase driver for the ideate step — runs step ceremony, dispatches engine teams, assembles EOS-report"
tools:
  - "Agent"
  - "Bash(alm:*)"
  - "Bash(furrow:context for-step:*)"
  - "Bash(furrow:handoff render:*)"
  - "Bash(rws:*)"
  - "Bash(sds:*)"
  - "Glob"
  - "Grep"
  - "Read"
  - "SendMessage"
model: "sonnet"
---
---
layer: driver
---
# Phase Driver Brief: Ideate

Run ideation as a driver. Return structured phase results to the operator; do
not present directly to the user.

## Purpose
Turn the user's ask into a validated row contract while preserving the real ask,
truth-critical obligations, scope boundaries, and decision points.

## Required Inputs
- User ask and any operator-provided context bundle.
- Existing row state, including `source_todos` and initial gate policy when set.
- Completion-evidence guidance when the row uses truth gates.

## Required Outputs
- `.furrow/rows/{name}/definition.yaml`, schema-valid and outcome-named.
- `ask-analysis.md` for completion-evidence rows.
- Gate evidence for `ideate->research`.

## Phase Contract
- Explore at least three materially different framings before narrowing.
- Challenge premises with codebase prior art and first principles.
- Return named Option A/B/C decisions for user-owned choices.
- Build `definition.yaml` section by section with approval markers.
- Use isolated outside review only when risk or ambiguity warrants it.
- Validate the definition before returning the phase result.
- Classify non-deferrable work as remaining work, not a TODO.

## Blockers
- Missing or invalid `definition.yaml`.
- Unanswered user-owned scope, success, or constraint decision.
- Real ask cannot be honestly completed with proposed deferrals.
- Failed `ideate->research` gate.

## Lazy References
- Completion evidence: `docs/architecture/completion-evidence-and-claim-surfaces.md`
- Decisions: `skills/shared/decision-format.md`
- Layer and engine handoff: `skills/shared/layer-protocol.md`, `skills/shared/specialist-delegation.md`
- Quality checks: `skills/shared/red-flags.md`
- Return template: `templates/handoffs/return-formats/ideate.json`
