# Implementation Plan

## Objective
Harden backend-canonical `/work` boundaries without thickening TypeScript: add richer step-artifact validation, stronger checkpoint evidence surfaces, a shared blocker taxonomy, and a narrow review->archive boundary that can run inside the existing `/work` loop.

## Planned work
1. Extend backend current-step artifact semantics beyond presence checks.
   - add plan-step `implementation-plan.md` as a scaffoldable/current-step artifact
   - attach per-artifact validation results to `furrow row status` / `row scaffold`
   - block `row complete` / `row transition` on semantic validation failures, not only scaffold sentinels
2. Strengthen checkpoint evidence in backend JSON.
   - expose checkpoint action/evidence in `furrow row status`
   - persist narrow gate evidence files for backend-mediated transitions
   - surface transition history and artifact-validation summaries for adapters
3. Add narrow archive boundary support in the backend and consume it from Pi.
   - implement `furrow row archive --json` with review-step and review-gate preconditions
   - treat `review->archive` as a supervised checkpoint action in `/work`
4. Keep the Pi adapter thin.
   - render backend validation / checkpoint / blocker metadata
   - do not duplicate lifecycle rules in TypeScript
5. Validate the affected backend and Pi flows and then sync docs/row artifacts only where reality changed.

## Landed scope in this session
- Backend: richer current-step artifact validation, plan-step `implementation-plan.md`, structured blocker taxonomy fields, checkpoint evidence surfaces, gate evidence files, `row archive`
- Pi: `/work` now renders backend validation/evidence data and can drive the narrow `review->archive` checkpoint through the backend
- Tests/docs: backend unit coverage extended for validation and archive flows; architecture docs synced to implementation truth
