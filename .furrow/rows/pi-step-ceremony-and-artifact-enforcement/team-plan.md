# Team Plan — pi-step-ceremony-and-artifact-enforcement

> Retrospective decompose artifact: this plan captures how the landed boundary-hardening pass breaks down into durable deliverables so the row can be caught up truthfully through Furrow ceremony.

## Scope Analysis
- The landed work breaks into three coupled deliverables:
  1. backend boundary semantics
  2. Pi `/work` consumption of backend metadata
  3. docs + durable row truth sync
- The backend deliverable is the primary dependency because it establishes:
  - artifact validation
  - checkpoint evidence
  - blocker taxonomy
  - archive preconditions
- The adapter and docs then consume and explain those backend surfaces.

## Team Composition
- `harness-engineer` for backend workflow semantics and tests
- `typescript-specialist` for the existing Furrow adapter at `adapters/pi/furrow.ts`
- `technical-writer` for contract/parity/row-truth sync

## Task Assignment
- `backend-boundary-semantics`
  - owner: `harness-engineer`
  - focus: Go CLI semantics, blocker/evidence surfaces, archive boundary, tests
- `pi-work-consumption`
  - owner: `typescript-specialist`
  - focus: render backend validation/evidence/taxonomy in the existing `/work` loop without duplicating lifecycle semantics
- `docs-and-row-truth-sync`
  - owner: `technical-writer`
  - focus: align contract/parity docs and durable row artifacts with landed implementation truth

## Coordination
- Wave 1 lands backend semantics first.
- Wave 2 consumes those semantics in the existing adapter and syncs docs/row truth.
- This decomposition is retrospective rather than predictive: it records the shape of work that already landed so later review/archive steps describe reality honestly.
- No parallel Pi adapter is introduced; the existing adapter remains the only adapter path.

## Skills
- Backend work stays backend-owned; TypeScript stays thin.
- Documentation updates are reconciliation work, not a new planning track.
- Seed/almanac planning follow-ups remain out of scope for this row and stay attached to their existing roadmap rows.
