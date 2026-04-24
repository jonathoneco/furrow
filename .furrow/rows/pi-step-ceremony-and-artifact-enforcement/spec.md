# Spec

## Scope
- Harden the backend-owned `/work` loop boundaries in the existing Furrow Pi adapter and Go CLI.
- Keep `.furrow/` canonical and route all supported lifecycle mutations through backend commands.
- Add richer current-step artifact validation for the artifacts the backend already understands, including a plan-step `implementation-plan.md` artifact.
- Expose stronger checkpoint evidence in `furrow row status`, including checkpoint action, artifact-validation summaries, and gate history/evidence paths.
- Add narrow review/archive semantics by implementing backend `furrow row archive` preconditions and letting `/work` consume the same backend checkpoint.
- Keep TypeScript thin by rendering backend-produced blocker, artifact, and checkpoint metadata rather than re-encoding workflow rules.

## Acceptance Criteria
- `furrow row status --json` exposes current-step artifact validation details, checkpoint action/evidence, and transition history suitable for adapter rendering.
- `furrow row complete --json` and `furrow row transition --json` block when the active step artifact exists but still fails backend validation.
- The plan step recognizes `implementation-plan.md` as a scaffoldable required artifact and validates it structurally.
- `furrow row transition --json` writes narrow checkpoint evidence artifacts under the row's `gates/` directory.
- `furrow row archive --json` exists, requires a completed review step plus a passing `->review` gate, and records durable archive checkpoint evidence.
- The existing Pi adapter in `adapters/pi/furrow.ts` can consume the backend checkpoint action/evidence and drive the narrow `review->archive` path without introducing parallel domain logic.
- `go test ./...` passes and validation covers the affected backend/Pi surfaces.

## Verification
- `go test ./...`
- `go run ./cmd/furrow row status pi-step-ceremony-and-artifact-enforcement --json`
- `go run ./cmd/furrow row scaffold pi-step-ceremony-and-artifact-enforcement --json`
- `go run ./cmd/furrow row archive pi-step-ceremony-and-artifact-enforcement --json` (expected blocker while not at review)
- `go run ./cmd/furrow row status backend-mediated-row-bookkeeping --json`
- `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-step-ceremony-and-artifact-enforcement'`
- `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-step-ceremony-and-artifact-enforcement --complete --confirm'`
