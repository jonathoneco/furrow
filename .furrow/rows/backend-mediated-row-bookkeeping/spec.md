# Spec: backend-mediated row bookkeeping for Pi parity

## Scope
Close the remaining manual state-edit gap in the supported Pi-driven Furrow
workflow by adding one narrow backend bookkeeping command.

## Supported command
- `furrow row complete <row-name> --json`

## Intended behavior
- Load canonical `.furrow/rows/<row>/state.json`.
- Block archived rows.
- Mark `step_status=completed`.
- Mark object-shaped deliverables as `status=completed`.
- Preserve unknown fields.
- Write atomically.
- Return structured JSON suitable for thin Pi consumption.
- Remain explicit that this is bookkeeping only, not review/archive/gate
  semantics.

## Why this shape
This is the smallest truthful backend addition that removes the demonstrated
manual-edit requirement from the current Pi workflow. It avoids broad generic
mutation APIs and does not widen `row transition` into a larger lifecycle
engine.

## Validation summary
- `go test ./...` passed with new coverage for `furrow row complete`.
- Existing `row list`, `row status`, and `row transition` behavior remained
  intact after the change.
- The supported Pi flow (`/furrow-next`, `/furrow-transition`,
  `/furrow-complete`) was exercised end to end without direct state edits.
- Sequential re-checks confirmed the final canonical row state after a
  transition/completion race was observed during validation.

## Deferred work
This command intentionally does not imply:
- review approval
- archive semantics
- gate enforcement expansion
- summary regeneration
- broader generic row mutation APIs

## Follow-on guidance
Treat this as the Level 2 bookkeeping primitive for the supported existing-row
Pi flow. Add broader lifecycle behavior only when real use proves it belongs in
the shared backend.
