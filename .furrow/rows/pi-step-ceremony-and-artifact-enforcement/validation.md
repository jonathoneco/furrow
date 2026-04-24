# Validation

## Automated

### `go test ./...`
- Result: pass
- Evidence:
  - `?    github.com/jonathoneco/furrow/cmd/furrow [no test files]`
  - `ok   github.com/jonathoneco/furrow/internal/cli (cached)`

## Backend command checks

### `go run ./cmd/furrow row focus --json`
- Result: pass
- Evidence: returns the focused row `pi-step-ceremony-and-artifact-enforcement` via backend JSON.

### `go run ./cmd/furrow row status pi-step-ceremony-and-artifact-enforcement --json`
- Result: pass
- Evidence:
  - surfaces seed state (`furrow-7427`, `researching`, consistent)
  - surfaces active blocker (`artifact_scaffold_incomplete` for `research.md`)
  - surfaces checkpoint (`research->plan`, approval required, not ready)
  - surfaces current-step artifact list with scaffold/incomplete status

### `go run ./cmd/furrow row scaffold pi-step-ceremony-and-artifact-enforcement --json`
- Result: pass earlier in the session
- Evidence: created `definition.yaml` only for the active `ideate` step, marked it incomplete, and did not create downstream step artifacts.

### `go run ./cmd/furrow row complete pi-step-ceremony-and-artifact-enforcement --json`
- Result: blocked as expected after transition
- Evidence: backend returns `blocked` with the active-step artifact details while `research.md` still contains the incomplete scaffold marker.

## Pi headless command checks

### `/work --switch pi-step-ceremony-and-artifact-enforcement`
- Command:
  - `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-step-ceremony-and-artifact-enforcement'`
- Result: pass
- Evidence:
  - prints row / step / blockers / seed / checkpoint / active-step artifacts in headless mode
  - shows the incomplete `research.md` scaffold as a blocker

### `/work --switch pi-step-ceremony-and-artifact-enforcement --complete --confirm`
- Command: run earlier in the session after replacing the ideation scaffold with a real `definition.yaml`
- Result: pass
- Evidence:
  - marked the ideate step complete through the backend
  - advanced `ideate -> research` only with explicit confirmation
  - scaffolded `research.md` on entry to the new step
  - updated the linked seed from `ideating` to `researching`

### `/furrow-next pi-step-ceremony-and-artifact-enforcement`
- Command:
  - `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/furrow-next pi-step-ceremony-and-artifact-enforcement'`
- Result: pass
- Evidence: secondary guidance command now includes blockers, seed state, checkpoint data, and current-step artifact status.

## Create-on-use scaffolding discipline
- Verified by backend scaffold output and by the `/work --complete --confirm` transition flow:
  - `definition.yaml` scaffolded only while `ideate` was active
  - `research.md` scaffolded only after explicit transition into `research`
  - downstream artifacts such as `spec.md` and `plan.json` were not created (`spec-missing`, `plan-missing` in manual checks)

## Lightweight review pass
- `git diff --check -- adapters/pi/furrow.ts internal/cli/app.go internal/cli/row.go internal/cli/row_workflow.go internal/cli/app_test.go docs/architecture/go-cli-contract.md docs/architecture/pi-step-ceremony-and-artifact-enforcement.md .furrow/rows/pi-step-ceremony-and-artifact-enforcement`
- Result: pass (no whitespace or merge-marker issues in the touched files)
