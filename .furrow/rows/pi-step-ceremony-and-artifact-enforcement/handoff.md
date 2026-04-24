# Handoff

## Outcome of this session

The repo still confirms the landed minimum Pi `/work` slice, and this session
added a first backend-canonical boundary-hardening pass on top of it.

What is now real in the repo beyond the prior minimum slice:
- backend current-step artifacts now carry validation data in `row status` / `row scaffold`
- the plan step now has a backend-owned `implementation-plan.md` artifact
- `row complete` and `row transition` block on semantic artifact-validation failures, not only missing files or incomplete scaffold sentinels
- backend transitions now write narrow checkpoint evidence files under `gates/`
- `row status` now exposes checkpoint action/evidence and gate transition history
- blocker surfaces now use a shared backend taxonomy shape (`code`, `category`, `severity`, `confirmation_path`, etc.)
- `furrow row archive --json` now exists as a narrow but real backend archive boundary surface
- the existing Pi `/work` loop can consume the backend archive checkpoint and does not need a parallel TS lifecycle path

## Still intentionally narrow

- artifact validation is structural/template-aware, not full evaluator-grade semantic review
- review execution is still not a mature backend review engine
- archive is still the narrow checkpoint/precondition path, not the full learnings/component/TODO promotion ceremony
- the leaf-command `--help` mismatch remains for `row init`, `row focus`, and `row scaffold`

## Files changed in this session

Code:
- `internal/cli/app.go`
- `internal/cli/row.go`
- `internal/cli/row_workflow.go`
- `internal/cli/row_semantics.go`
- `internal/cli/app_test.go`
- `adapters/pi/furrow.ts`

Architecture/docs:
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/pi-parity-ladder.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`

Durable row artifacts:
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/implementation-plan.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/spec.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/execution-progress.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/state.json` (backend-mediated progression during validation)

## Current row state

- Row: `pi-step-ceremony-and-artifact-enforcement`
- Step: `spec`
- Step status: `not_started`
- Seed: `furrow-7427` / `speccing`
- Current-step artifact: `spec.md` present and backend-valid
- Next checkpoint: `spec->decompose` (supervised), not yet ready because the current step has not been completed through the backend

## Recommended next slice

Stay inside `work-loop-boundary-hardening`, but keep the next increment narrower
than this session's breadth:

1. deepen review/gate evidence surfaces beyond the narrow checkpoint evidence now written by transition/archive
2. add richer implement/review artifact validation, not just structural markdown/JSON checks
3. expand archive from narrow preconditions into fuller promotion/disposition ceremony
4. validate the shared blocker taxonomy against Claude-compatible flows once the backend contract stabilizes a bit more

## Constraints to preserve

- `.furrow/` remains canonical
- supported mutations go through backend/CLI authority only
- keep TypeScript thin and backend-driven
- do not introduce a second/parallel Pi adapter
- keep seed/almanac follow-ups attached to `seeds-concept` / `pi-almanac-operating-model`
- only minimal `/work`-level almanac awareness belongs in this Phase 3 row
