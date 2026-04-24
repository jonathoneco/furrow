# Handoff

## Summary
This slice restored the first usable supervised `/work` loop in Pi without moving lifecycle semantics into TypeScript. The Go backend now owns row init/focus/scaffold support, seed-visible status surfaces, and blocker-aware transition/completion checks for the active step. The Pi adapter now exposes `/work` as the primary entrypoint and keeps secondary commands available.

## Files intentionally changed in this session
- `adapters/pi/furrow.ts`
- `internal/cli/app.go`
- `internal/cli/row.go`
- `internal/cli/row_workflow.go`
- `internal/cli/app_test.go`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `.furrow/.focused`
- `.furrow/seeds/seeds.jsonl`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/state.json`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/definition.yaml`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/research.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/implementation-plan.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/execution-progress.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md`

## Current limitations
- Active-step validation is still intentionally shallow: presence plus the explicit incomplete-scaffold sentinel, not full semantic artifact validation.
- Plan, implement, review, and archive still rely on secondary commands and do not yet have richer backend gate/archive semantics.
- `/work` can initialize and progress rows, but it does not yet subsume every secondary Furrow command.
- Existing legacy rows without linked seeds are surfaced loudly, but the backend currently hard-blocks only linked-seed invalidity, not every historical missing-seed case.

## Recommended next slice
Deepen backend-canonical boundary enforcement beyond scaffold detection:
- richer artifact validation per step
- stronger checkpoint / gate evidence surfaces
- review/archive semantics for the same `/work` loop
- explicit blocker taxonomy shared across Pi and future Claude compatibility layers
