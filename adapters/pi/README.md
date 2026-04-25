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

## Pre-write validation handlers

The adapter registers `tool_call` handlers that intercept Write/Edit and shell
out to the Go backend before allowing the write to proceed:

- `validate-definition` — fires on writes to `*/definition.yaml`; calls
  `furrow validate definition --path <file> --json` and blocks on `verdict: invalid`.
- `ownership-warn` — fires on every Write/Edit; calls
  `furrow validate ownership --path <file> --json` and surfaces a
  `ctx.ui.confirm` prompt on `verdict: out_of_scope`.

Each call invokes `go run ./cmd/furrow ...` per write, with ~45 ms cold start
per call. On a write to a `definition.yaml` that triggers both handlers, the
double-fire compounds (~90 ms wall clock). Optimization is tracked under the
almanac todo `pi-adapter-binary-caching` (build the binary once at adapter init,
exec the binary path).

Tests for these handlers live in `adapters/pi/furrow.test.ts`. Run with
`bun test` from `adapters/pi/`.

## Promotion intent

This promotion is a stabilization step, not a semantic expansion step.

Non-goals of this layout:
- no Pi-owned lifecycle semantics
- no generic adapter framework
- no package publishing exercise unless needed later
- no broadened backend contract beyond the already proven Level 2 slice
