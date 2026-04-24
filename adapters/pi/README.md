# Pi adapter

This directory contains the **repo-owned** Pi adapter for Furrow.

## Scope

The adapter is intentionally thin.

It owns Pi-specific runtime integration only:
- slash command registration
- lightweight Pi rendering/status output
- confirmation UI where available
- direct-state mutation guardrails for canonical Furrow state files

It does **not** own Furrow workflow semantics.

The Go backend remains semantic authority, and `.furrow/` remains canonical state.
All supported mutations continue to go through backend commands such as:

- `go run ./cmd/furrow row list --json`
- `go run ./cmd/furrow row status --json`
- `go run ./cmd/furrow row transition ... --json`
- `go run ./cmd/furrow row complete ... --json`
- `go run ./cmd/furrow doctor --json`

## Commands exposed

- `/furrow-overview`
- `/furrow-next`
- `/furrow-transition`
- `/furrow-complete`

## Canonical entrypoint

The canonical implementation is:

- `adapters/pi/furrow.ts`

For direct loading/testing:

```sh
pi --no-extensions -e ./adapters/pi/furrow.ts --no-session -p "/furrow-overview"
```

## Project-local auto-discovery compatibility

Pi auto-discovers project-local extensions from `.pi/extensions/`.
To preserve the current workflow without keeping the implementation there,
this repo also keeps a tiny compatibility shim at:

- `.pi/extensions/furrow.ts`

That shim only re-exports `adapters/pi/furrow.ts` so the repo-owned adapter is
canonical while existing project-local discovery still works.

## Promotion intent

This promotion is a stabilization step, not a semantic expansion step.

Non-goals of this layout:
- no Pi-owned lifecycle semantics
- no generic adapter framework
- no package publishing exercise unless needed later
- no broadened backend contract beyond the already proven Level 2 slice
