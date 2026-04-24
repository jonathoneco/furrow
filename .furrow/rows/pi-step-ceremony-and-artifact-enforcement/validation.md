# Validation

## Boundary-hardening validation run

### `go test ./...`
- Result: pass
- Evidence:
  - `?    github.com/jonathoneco/furrow/cmd/furrow [no test files]`
  - `ok   github.com/jonathoneco/furrow/internal/cli`
- Coverage added in this session:
  - plan-step artifact validation blocking
  - checkpoint evidence file emission on transition
  - narrow `row archive` success/blocking semantics

### `go run ./cmd/furrow row status pi-step-ceremony-and-artifact-enforcement --json`
- Result: pass
- Evidence before advancing from `plan`:
  - current-step artifact: `implementation-plan.md`
  - artifact validation: `pass=1 fail=0 missing=0`
  - checkpoint action: `transition`
  - checkpoint boundary: `plan->spec`
  - checkpoint evidence includes latest gate, seed surface, and artifact-validation summary

### `go run ./cmd/furrow row scaffold pi-step-ceremony-and-artifact-enforcement --json`
- Result: pass
- Evidence:
  - `created: []`
  - backend reports the current plan-step artifact and its validation status
  - confirms scaffold remains current-step-only

### `go run ./cmd/furrow row archive pi-step-ceremony-and-artifact-enforcement --json`
- Result: blocked as expected
- Evidence:
  - error code: `blocked`
  - message: `row "pi-step-ceremony-and-artifact-enforcement" must be at step review before archiving`
- Meaning:
  - archive semantics are now backend-owned and refuse invalid lifecycle shortcuts

### `go run ./cmd/furrow row status backend-mediated-row-bookkeeping --json`
- Result: pass
- Evidence:
  - archived row reports `checkpoint.action=null`
  - checkpoint evidence marks `archived=true`
  - no blockers are surfaced for the archived row state itself

### `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-step-ceremony-and-artifact-enforcement'`
- Result: pass
- Evidence:
  - headless `/work` renders the backend-produced plan-step artifact validation result
  - checkpoint output includes action, artifact-validation counts, and latest-gate summary
  - recommended action remains backend-driven (`/work --complete` when step work is done enough)

### `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-step-ceremony-and-artifact-enforcement --complete --confirm'`
- Result: pass, with expected canonical mutations
- Evidence:
  - backend marked the plan step complete
  - backend advanced the row through the supervised `plan->spec` boundary
  - backend scaffolded `spec.md` on entry to `spec`
  - Pi surfaced the new blocker taxonomy and artifact validation failure for the scaffolded `spec.md`
- Follow-up:
  - replaced the scaffolded `spec.md` with a real spec artifact so the durable row state no longer depends on an artificial scaffold blocker

### `go run ./cmd/furrow row status pi-step-ceremony-and-artifact-enforcement --json` (post-spec sync)
- Result: pass
- Evidence:
  - current row step: `spec`
  - current-step artifact: `spec.md`
  - artifact validation now passes
  - seed status aligned to `speccing`
  - checkpoint boundary is `spec->decompose`
  - `ready_to_advance=false` because the current step has not been canonically completed yet

## Known mismatch retained

### `go run ./cmd/furrow row init --help`
### `go run ./cmd/furrow row focus --help`
### `go run ./cmd/furrow row scaffold --help`
- Result: still mismatch
- Evidence:
  - stderr: `unknown flag --help`
- Note:
  - leaf-command `--help` is still not implemented for these new row subcommands
  - help remains available through `go run ./cmd/furrow row` or `go run ./cmd/furrow row help`

## Conclusion

The landed `/work` loop was reconfirmed, and the repo now also has a first real backend-canonical hardening pass for artifact validation, checkpoint evidence, blocker taxonomy, and archive-boundary handling. The remaining gaps are deeper review/gate semantics and fuller archive ceremony, not another adapter-promotion pass.
