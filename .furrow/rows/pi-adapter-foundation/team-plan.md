# Team Plan

## Scope Analysis
- The current emphasis stays inside `work-loop-boundary-hardening` and should land as backend-owned review normalization plus archive-disposition signals consumed by the existing Pi `/work` loop.
- The backend must land first because TypeScript should only render backend-owned review and archive evidence.
- The row remains active after this slice; do not treat completion of this bounded implementation pass as permission to archive `pi-adapter-foundation`.

## Team Composition
- `harness-engineer` for review-artifact normalization, review command/status surfaces, archive-readiness signals, and regression tests
- `typescript-specialist` only if new backend fields need rendering in `adapters/pi/furrow.ts`
- `technical-writer` for truthful contract/parity doc sync if implementation reality changes

## Task Assignment
- `evaluator-grade-review-semantics`
  - owner: `harness-engineer`
  - focus: normalize review JSON shapes, strengthen semantic validation, and add backend review status/validate surfaces
- `archive-disposition-signals`
  - owner: `harness-engineer`
  - focus: derive actionable follow-up/disposition signals from normalized review evidence and expose them through row/archive surfaces
  - downstream consumers: `typescript-specialist`, `technical-writer`

## Coordination
- Wave 1 lands the normalized review model and regression tests.
- Wave 2 reuses the normalized model for row/archive evidence, then updates the existing Pi adapter and docs only if backend fields change.
- Validate backend commands first, then validate a headless Pi `/work` flow against `pi-adapter-foundation`.

## Skills
- Keep lifecycle semantics backend-owned.
- Keep TypeScript thin and rendering-only.
- Preserve durable row artifacts and supported Furrow ceremony before implementation.
