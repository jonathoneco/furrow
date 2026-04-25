# Team Plan

## Scope Analysis
- The slice naturally breaks into a backend fix for supported row creation, backend boundary-hardening for implement and review artifacts, and thin adapter or docs consumption of the new evidence surfaces.
- Backend semantics must land first because the adapter should only render backend-owned evidence and blockers.
- The row stays inside the existing Phase 3 `work/pi-adapter-foundation` / `work-loop-boundary-hardening` boundary; no new roadmap track or parallel adapter is introduced.

## Team Composition
- `harness-engineer` for row-init tolerance, artifact validation, blocker behavior, archive evidence, and backend tests
- `typescript-specialist` for the existing Pi adapter rendering changes in `adapters/pi/furrow.ts`
- `technical-writer` for contract and parity docs that need truthful reconciliation

## Task Assignment
- `source-link-init-compatibility`
  - owner: `harness-engineer`
  - focus: align row init with tolerant almanac loading and add regression coverage
- `implement-review-boundary-validation`
  - owner: `harness-engineer`
  - focus: validate implement inputs and review artifacts, then fold those results into blockers and archive readiness
- `archive-evidence-and-pi-surfacing`
  - owner: `typescript-specialist`
  - focus: expose the richer checkpoint or archive evidence in the existing adapter and sync docs to repo truth

## Coordination
- Wave 1 lands backend semantics and tests.
- Wave 2 consumes the new backend surfaces in the existing Pi adapter and updates architecture docs.
- Validation runs after both waves, then durable row artifacts are updated to match what actually landed.

## Skills
- Keep lifecycle semantics backend-owned.
- Keep TypeScript thin and evidence-rendering only.
- Preserve durable row artifacts and supported Furrow ceremony for row progression.
