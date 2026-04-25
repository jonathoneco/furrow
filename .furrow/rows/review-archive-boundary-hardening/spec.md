# Spec

## Scope
- Make `furrow row init` consume the canonical planning file through the same tolerant YAML path that powers `furrow almanac validate`, so supported row creation can proceed inside the live repo without hand-editing almanac state.
- Extend backend current-step artifact semantics so coordinated implementation work validates carried decompose artifacts during `implement`, and review work validates durable review JSON artifacts during `review`.
- Enrich backend checkpoint and archive evidence with parsed latest-gate evidence, review-artifact summary, source-link context, and learnings presence or count.
- Keep adapter work limited to rendering backend evidence in the existing `adapters/pi/furrow.ts` `/work` flow.

## Acceptance Criteria
- `readTodoList` tolerates the live duplicate-key planning-file shape and `furrow row init <name> --source-todo work-loop-boundary-hardening --json` succeeds through supported backend ceremony.
- `furrow row status --json` for an `implement` row can surface and block on missing or invalid carried decompose artifacts when the row shape implies coordinated implementation work.
- `furrow row status --json` for a `review` row can surface and block on missing, malformed, or non-passing review artifacts under `reviews/`.
- `furrow row status --json` exposes richer checkpoint evidence including latest gate evidence details and archive-readiness ceremony summary.
- `furrow row archive --json` records the richer archive ceremony summary in both the response payload and the durable archive checkpoint evidence.
- The Pi adapter renders the new backend checkpoint fields without moving lifecycle semantics out of Go.

## Verification
- `go test ./...`
- `go run ./cmd/furrow doctor --host pi --json`
- `go run ./cmd/furrow almanac validate --json`
- `go run ./cmd/furrow row init review-archive-boundary-hardening --title 'Review/archive boundary hardening' --source-todo work-loop-boundary-hardening --json`
- `go run ./cmd/furrow row status review-archive-boundary-hardening --json`
- `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch review-archive-boundary-hardening'`
- `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch review-archive-boundary-hardening --complete --confirm'`
