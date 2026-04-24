# Spec: first usable Pi Furrow operating layer

## Scope
Build the first thin but real Pi-side Furrow operating layer over the Go
backend. Pi should own runtime UX integration only; the Go CLI remains semantic
authority over canonical `.furrow/` state.

## Supported command surface
- `furrow-overview`
- `furrow-next`
- `furrow-transition`

## Interaction model
- `furrow-overview` calls `furrow row list --json` and renders focused, active,
  and archived row context.
- `furrow-next` calls `furrow doctor --json` plus `furrow row status --json` and
  renders backend warnings, artifact paths, and recommended next action.
- `furrow-transition` resolves the row through backend status, requires explicit
  confirmation, and mutates state only through `furrow row transition ... --json`.
- Pi adds a lightweight status indicator for the resolved row and a guardrail
  against direct edits to `.furrow/.focused` and `.furrow/rows/*/state.json`.

## Validation summary
- Backend contract spot checks passed for `doctor`, `row list`, and `row status`.
- The Pi extension loaded headlessly and handled overview/next guidance without
  invoking the model.
- Transition validation proved Pi can drive a real backend-mediated
  `implement -> review` transition and surface backend limitations honestly.
- Validation exposed one remaining gap at the time: final row bookkeeping still
  required direct state edits after transition, which became the follow-on row.

## Deferred work
This slice intentionally did not attempt:
- package/publishing polish
- richer Pi widgets or dashboards
- Pi-side lifecycle semantics beyond backend payload interpretation
- review/archive parity
- broader backend expansion

## Follow-on guidance
Keep the TypeScript layer thin. Any additional lifecycle capability should be
added to the backend only when real Pi use demonstrates that the missing
semantic belongs in the shared backend rather than in Pi UX.
