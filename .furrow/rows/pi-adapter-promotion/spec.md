# Spec: Pi adapter promotion

## Scope
Promote the proven Pi Furrow operating slice out of `.pi/extensions/furrow.ts`
into a repo-owned adapter layout while keeping the TypeScript layer thin,
backend-driven, and semantically subordinate to the Go CLI.

## Target layout
- `adapters/pi/furrow.ts` — canonical repo-owned adapter implementation
- `adapters/pi/_meta.yaml` — adapter metadata
- `adapters/pi/README.md` — minimal usage/install notes
- `.pi/extensions/furrow.ts` — thin compatibility shim for project-local
  auto-discovery

## Success criteria
- The promoted adapter still exposes `/furrow-overview`, `/furrow-next`,
  `/furrow-transition`, and `/furrow-complete`.
- Backend subprocess usage remains `go run ./cmd/furrow ... --json`.
- Artifact-aware guidance and direct-state mutation guardrails remain intact.
- Validation is recorded against the promoted adapter location, not only the old
  project-local file.

## Validation summary
- The promoted adapter loaded directly from `adapters/pi/furrow.ts`.
- The compatibility shim still loaded from `.pi/extensions/furrow.ts`.
- Overview and next-guidance flows worked through the promoted adapter.
- Transition and completion flows were exercised in a disposable temp repo copy
  so the backend-mediated path could be validated without mutating live repo
  state.
- Follow-up backend status in the temp copy confirmed the expected review/
  completed state after the promoted-adapter flow.

## Deferred work
This promotion intentionally did not add:
- a broader package publishing framework
- Pi-only lifecycle semantics
- speculative portability abstractions
- backend expansion beyond what real adapter use proves necessary

## Follow-on guidance
Keep `adapters/pi/furrow.ts` thin, continue validating Pi against backend
contracts, and add only the next backend-driven capability that real usage
proves necessary.
