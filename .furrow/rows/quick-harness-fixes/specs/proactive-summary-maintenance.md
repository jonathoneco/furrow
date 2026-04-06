# Spec: proactive-summary-maintenance

## Interface Contract

### `skills/shared/summary-protocol.md` (updated)

**Changes:**
- Reconcile content requirement: change from "≥2 bullets" to "≥1 non-empty line" to match `validate-summary` hook enforcement
- Add "When to update" guidance: after completing a deliverable or sub-task, after settling a design decision, after discovering a key finding — not on every tool call
- Reference `rws update-summary` command instead of direct file editing
- Clarify step-aware requirements match hook behavior (ideate: only Open Questions)

### `.claude/rules/summary-maintenance.md` (new, optional)

**Decision:** May not be needed if summary-protocol.md guidance is sufficient. The CLI-mediation rule (D1) already covers "use CLI, not direct edits." A separate summary-maintenance rule would be redundant. Instead, update summary-protocol.md to be the single source of truth.

**If created (~15 lines):** When to update summary.md during a step. References `rws update-summary`.

## Acceptance Criteria (Refined)

- `skills/shared/summary-protocol.md` specifies ≥1 non-empty line per required section (matches validate-summary.sh)
- `skills/shared/summary-protocol.md` includes "When to update" section with specific trigger conditions
- `skills/shared/summary-protocol.md` references `rws update-summary` as the update mechanism
- No contradiction between summary-protocol.md and validate-summary.sh validation rules

## Implementation Notes

- This is primarily a documentation/guidance change, not a code change
- The CLI-mediation rule from D1 already tells agents to use CLI for summary updates
- The main value is reconciling the protocol doc with the hook and adding timing guidance
- Keep changes minimal — update existing protocol, don't create parallel enforcement

## Dependencies

- `cli-mediated-interaction` deliverable must be complete first (provides the `rws update-summary` command to reference)
