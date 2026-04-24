# Spec: minimum shared Go backend slice

## Scope
Implement the smallest real Go backend surface that Pi can consume without
introducing Pi-only semantics. The slice is intentionally narrow: it should be
backend-canonical, artifact-canonical, and honest about what it does not yet do.

## Deliverables
- `furrow almanac validate --json`
- `furrow row list --json`
- `furrow row status --json`
- `furrow row transition --json` with narrow adjacent forward mutation only
- `furrow doctor --json`

## Command contract snapshot

### `furrow almanac validate --json`
- Validates `.furrow/almanac/todos.yaml`, `observations.yaml`, and `roadmap.yaml`.
- Returns per-file findings plus a global summary.
- Treats the current repo's live document shapes as authoritative.

### `furrow row list --json`
- Tolerantly enumerates `.furrow/rows/*/state.json`.
- Supports `--active`, `--archived`, and `--all`.
- Defaults to `all` for early adapter usefulness.
- Returns normalized browse metadata rather than raw state dumps.

### `furrow row status --json`
- Resolves rows in this order: explicit row, focused row, latest active row.
- Returns normalized row metadata, deliverable summaries, gate summaries,
  artifact paths, and backend-advertised next transitions.
- Prefers tolerant reads over strict historical normalization.

### `furrow row transition --json`
- Supports active rows only.
- Allows adjacent forward transitions only.
- Performs atomic state writes and preserves unknown fields.
- Writes an explicit gate-like record describing the mutation's limits.
- Does not claim artifact validation, seed sync, summary regeneration, or full
  gate-policy semantics.

### `furrow doctor --json`
- Reports backend structural readiness only.
- Checks `.furrow` roots, canonical directories, row-state parseability,
  focused-row sanity, and almanac validation summary.
- Does not try to reproduce shell-era repo hygiene checks.

## Validation summary
- `go test ./...` passed for the slice.
- Manual spot checks passed for almanac validation, row listing, row status, and
  doctor output.
- A real transition was validated in an isolated temp root and confirmed:
  adjacent forward mutation works, unknown fields are preserved, and the backend
  records its limitations explicitly.

## Deferred semantics
This slice intentionally does not implement:
- artifact validation
- full gate-policy enforcement
- seed sync
- summary regeneration
- review/archive lifecycle behavior
- broader mutation APIs

## Follow-on guidance
Use this slice as the shared backend base for thin adapters. The next work
should widen backend semantics only when real adapter usage reveals a concrete
shared need.
