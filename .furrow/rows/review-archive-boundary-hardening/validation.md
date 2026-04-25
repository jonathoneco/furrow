# Validation

## Repo truth before implementation

### `go test ./...`
- Result: pass
- Evidence:
  - `?    github.com/jonathoneco/furrow/cmd/furrow [no test files]`
  - `ok   github.com/jonathoneco/furrow/internal/cli`

### `go run ./cmd/furrow doctor --host pi --json`
- Result: pass with warning only
- Evidence:
  - backend checks passed
  - warning was only `no focused row set`

### `go run ./cmd/furrow almanac validate --json`
- Result: pass
- Evidence:
  - all canonical almanac files valid
  - `summary.valid=true`

### `go run ./cmd/furrow row init review-archive-boundary-hardening --title 'Review/archive boundary hardening' --source-todo work-loop-boundary-hardening --json`
- Initial result before the backend fix: blocked by mismatch
- Evidence:
  - `furrow almanac validate --json` passed
  - `row init` failed on duplicate `updated_at` keys in `.furrow/almanac/todos.yaml`
- Meaning:
  - repo reality exposed a real backend inconsistency inside supported row-init flow

## Row creation and supported ceremony

### `go run ./cmd/furrow row init review-archive-boundary-hardening --title 'Review/archive boundary hardening' --source-todo work-loop-boundary-hardening --json`
- Final result: pass
- Evidence:
  - row directory created under `.furrow/rows/review-archive-boundary-hardening/`
  - linked seed `furrow-3254`
  - proves the row-init mismatch was fixed through backend code rather than manual state edits

### `go run ./cmd/furrow row focus review-archive-boundary-hardening --json`
- Result: pass
- Evidence:
  - focused row set through backend command

### `go run ./cmd/furrow row scaffold review-archive-boundary-hardening --json`
- Result: pass at each step
- Evidence:
  - current-step-only scaffolding for `definition.yaml`, `research.md`, `implementation-plan.md`, `spec.md`, `plan.json`, and `team-plan.md`
  - backend surfaced incomplete scaffold blockers until substantive artifacts replaced them

### Supported step progression
- Result: pass through supported backend commands only
- Evidence:
  - `row complete` + `row transition` used for:
    - `ideate -> research`
    - `research -> plan`
    - `plan -> spec`
    - `spec -> decompose`
    - `decompose -> implement`
    - `implement -> review`
  - durable gate evidence written under `.furrow/rows/review-archive-boundary-hardening/gates/`

## Backend hardening behavior

### `go test ./...`
- Result: pass after code changes
- Coverage added in this slice:
  - row-init tolerance for live duplicate-key planning file shape
  - implement-step blocking on carried decompose artifact failures
  - review-step blocking on failing review artifacts
  - richer archive response payload

### `go run ./cmd/furrow row status review-archive-boundary-hardening --json` (review-ready state)
- Result: pass
- Evidence:
  - review current-step artifacts include three `reviews/*.json` files
  - each review artifact validates as `pass`
  - checkpoint action is `archive`
  - checkpoint evidence includes:
    - latest gate summary
    - latest gate evidence path and parsed summary
    - review-artifact summary (`required=3`, `pass=3`)
    - source TODO context for `work-loop-boundary-hardening`
    - learnings presence/count surface

### `go run ./cmd/furrow row status review-archive-boundary-hardening --json` (archived state)
- Result: pass
- Evidence:
  - `archived=true`
  - latest gate is `review->archive`
  - archive checkpoint evidence path is `gates/review-to-archive.json`

### `go run ./cmd/furrow row list --active --json`
- Result: pass
- Evidence:
  - active rows list is empty after archival

## Pi headless validation

### `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch review-archive-boundary-hardening'`
- Result before archive: pass
- Evidence:
  - rendered backend-produced review artifact validation
  - rendered latest gate evidence path and summary
  - rendered archive review evidence summary, source TODO context, and learnings surface
  - recommended action was backend-driven archive confirmation

### `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch review-archive-boundary-hardening --complete --confirm'`
- Result: pass
- Evidence:
  - backend completed review bookkeeping
  - backend archived the row through `review->archive`
  - Pi rendered the archived result without adapter-owned lifecycle logic

### `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch review-archive-boundary-hardening'` (post-archive)
- Result: blocked as expected
- Evidence:
  - message: `row "review-archive-boundary-hardening" is archived`

## Cleanup validation

### `go run ./cmd/furrow row focus --clear --json`
- Result: pass
- Evidence:
  - cleared focus after archival through supported backend command

### `go run ./cmd/furrow doctor --host pi --json`
- Result: pass with warning only
- Evidence:
  - warning is only `no focused row set`, which is expected after clearing focus

### `go run ./cmd/furrow almanac validate --json`
- Result: pass
- Evidence:
  - almanac remained valid after row creation, seed-link backfill, and archival

## Conclusion
- The next in-scope Phase 3 slice landed and was archived through supported Furrow ceremony.
- The real mismatch discovered at row init was fixed rather than normalized.
- Implement/review validation and archive evidence are stronger, while lifecycle semantics remain backend-owned and the Pi adapter remains thin.
