# Research

## Questions

1. What materially landed in the repo for `pi-step-ceremony-and-artifact-enforcement`?
2. How closely does the current repo match the implementation report?
3. What remains missing before the `/work` loop is Furrow-strong at the next level?

## Findings

### Landed in the repo

The minimum usable slice is real in `../furrow`.

Backend:
- `furrow row init`
- `furrow row focus`
- `furrow row scaffold`
- richer `furrow row status` with:
  - blockers
  - seed state
  - checkpoint state
  - current-step artifact expectations
- stricter `furrow row transition`
  - adjacent forward only
  - requires `step_status=completed`
  - blocks on incomplete active-step scaffold artifacts
  - syncs linked seed status on transition
- stricter `furrow row complete`
  - blocks on incomplete active-step scaffold artifacts

Pi:
- repo-owned adapter at `adapters/pi/furrow.ts`
- primary `/work` command that can:
  - resolve/select/focus rows
  - initialize rows through the backend
  - scaffold only the active step artifact on use
  - surface blockers, seed state, checkpoint state, and current-step artifacts
  - require explicit confirmation before supervised advancement

### Validated behavior

- `go test ./...` passes.
- `furrow row status pi-step-ceremony-and-artifact-enforcement --json` surfaces the expected blocker, seed, and checkpoint data.
- `furrow row focus --json` reports the focused row correctly.
- `furrow row scaffold pi-step-ceremony-and-artifact-enforcement --json` is a no-op when the current-step artifact already exists.
- `furrow row complete pi-step-ceremony-and-artifact-enforcement --json` blocks on the incomplete `research.md` scaffold as expected.
- Headless Pi `/work --switch pi-step-ceremony-and-artifact-enforcement` surfaces the same blocker/seed/checkpoint state.
- Headless Pi `/work --switch pi-step-ceremony-and-artifact-enforcement --complete --confirm` fails through the backend because the current-step artifact is still incomplete.

### Mismatches found

1. Leaf-command `--help` is not implemented for the newly added backend commands.
   - `go run ./cmd/furrow row init --help`
   - `go run ./cmd/furrow row focus --help`
   - `go run ./cmd/furrow row scaffold --help`
   all fail with `unknown flag --help`.
   Help is currently available through `go run ./cmd/furrow row` or `go run ./cmd/furrow row help`.

2. Planning/handoff docs were stale relative to the landed repo.
   - `docs/handoffs/pi-step-ceremony-and-artifact-enforcement.md` still read like a pre-implementation brief.
   - `docs/architecture/pi-parity-ladder.md` still emphasized the earlier pre-`/work` state.
   - `README.md` still described Furrow as primarily Claude-shaped rather than an active dual-host migration with a repo-owned Pi adapter.

### Remaining gap after this slice

The next weakness is not row selection/init/scaffold anymore. It is boundary hardening inside the landed `/work` loop:

- richer per-step artifact validation beyond scaffold detection
- stronger checkpoint / gate evidence surfaces
- review/archive semantics inside the same loop
- explicit blocker taxonomy shared across Pi and Claude-compatible flows

## Sources consulted

- `README.md`
- `docs/architecture/workflow-power-preservation.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/architecture/pi-almanac-operating-model.md`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/pi-parity-ladder.md`
- `docs/handoffs/pi-step-ceremony-and-artifact-enforcement.md`
- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml`
- `adapters/pi/furrow.ts`
- `internal/cli/app.go`
- `internal/cli/row.go`
- `internal/cli/row_workflow.go`
- `internal/cli/app_test.go`
