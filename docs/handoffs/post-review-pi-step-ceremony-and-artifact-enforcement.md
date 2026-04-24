# Handoff: post-review follow-up for `pi-step-ceremony-and-artifact-enforcement`

## Outcome so far

The minimum usable slice remains landed, and the repo now also contains a first
backend-canonical boundary-hardening pass.

What is now real in the repo:

- Go backend support for:
  - `furrow row init`
  - `furrow row focus`
  - `furrow row scaffold`
  - richer `furrow row status` surfaces for blockers, seed state, checkpoint state, current-step artifact validation, checkpoint evidence, and gate history
  - stricter `furrow row transition` enforcement plus checkpoint evidence files under `gates/`
  - stricter `furrow row complete` enforcement, including semantic current-step artifact validation
  - narrow `furrow row archive` support with review-step/review-gate preconditions and archive checkpoint evidence
- Pi adapter support for a primary `/work` command in `adapters/pi/furrow.ts`
- `/work` can:
  - resolve, select, and focus rows
  - initialize new rows through the backend
  - scaffold only the active step artifact on use
  - surface blockers, seed state, checkpoint state, checkpoint evidence, and current-step artifact validation
  - require explicit confirmation before supervised advancement
  - consume the narrow backend `review->archive` checkpoint without introducing parallel lifecycle logic in TS

## Validated mismatch still to keep in mind

- `go run ./cmd/furrow row init --help`
- `go run ./cmd/furrow row focus --help`
- `go run ./cmd/furrow row scaffold --help`

currently still fail with `unknown flag --help`.

Help is available through:

- `go run ./cmd/furrow row`
- `go run ./cmd/furrow row help`

Do not assume leaf-command `--help` support exists yet.

## What remains intentionally incomplete

- artifact validation is stronger, but still structural/template-aware rather than evaluator-grade semantic review
- review execution still does not have full backend review/gate-engine parity
- archive inside `/work` is still the narrow checkpoint path, not the full promotion/disposition ceremony
- shared blocker taxonomy now exists in backend surfaces, but still needs later dual-host validation

## Recommended next slice

Stay inside the same Phase 3 row boundary and keep hardening backend-canonical
`/work` boundaries, but aim deeper into review semantics rather than adding more
adapter ceremony.

Target shape:

1. deeper review/gate evidence surfaces
2. richer implement/review artifact validation
3. fuller archive ceremony beyond narrow backend preconditions
4. later validation of the blocker taxonomy across Pi and Claude-compatible flows

## Read first next session

- `README.md`
- `docs/architecture/workflow-power-preservation.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/pi-parity-ladder.md`
- `docs/architecture/pi-almanac-operating-model.md`
- `docs/handoffs/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/handoffs/post-review-pi-step-ceremony-and-artifact-enforcement.md`
- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/implementation-plan.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/spec.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md`

## Next-session prompt seed

Start with validation, not assumptions:

- verify the current `/work` loop, artifact-validation surfaces, checkpoint evidence, and archive boundary behavior against the live repo
- use the backend as authority for any supported row mutations
- keep seed/almanac follow-ups attached to `seeds-concept` and `pi-almanac-operating-model`
- keep the next increment focused on deeper backend-canonical boundary semantics inside `/work`, not another adapter-promotion pass
