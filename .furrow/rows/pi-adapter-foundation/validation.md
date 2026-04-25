# Validation

## Repo-truth checks at session start

### `go test ./...`
- Result: pass
- Evidence:
  - `?    github.com/jonathoneco/furrow/cmd/furrow [no test files]`
  - `ok   github.com/jonathoneco/furrow/internal/cli`

### `go run ./cmd/furrow doctor --host pi --json`
- Result: pass
- Evidence:
  - `summary.pass=9`
  - focused row usable: `pi-adapter-foundation`

### `go run ./cmd/furrow almanac validate --json`
- Result: pass
- Evidence:
  - all canonical almanac files valid
  - `summary.valid=true`

### `go run ./cmd/furrow row focus --json`
- Result: pass
- Evidence:
  - focused row: `pi-adapter-foundation`

### `go run ./cmd/furrow row status pi-adapter-foundation --json`
- Result before new changes: pass
- Evidence:
  - current step: `plan`
  - current-step artifact: `implementation-plan.md`
  - blockers: `[]`

### `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-adapter-foundation'`
- Result before new changes: pass
- Evidence:
  - `/work` regrounded the canonical row at `plan`
  - surfaced the plan artifact and next boundary through backend truth

## Ceremony-first row progression in this session

### `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-adapter-foundation --complete --confirm'`
- Result for `plan -> spec`: pass
- Evidence:
  - completed plan bookkeeping
  - advanced to `spec`
  - scaffolded `spec.md`

### `go run ./cmd/furrow row status pi-adapter-foundation --json`
- Result after replacing `spec.md`: pass
- Evidence:
  - spec artifact validation `pass`
  - next boundary: `spec->decompose`

### `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-adapter-foundation --complete --confirm'`
- Result for `spec -> decompose`: pass
- Evidence:
  - completed spec bookkeeping
  - advanced to `decompose`
  - scaffolded `plan.json` and `team-plan.md`

### `go run ./cmd/furrow row status pi-adapter-foundation --json`
- Result after replacing `plan.json` and `team-plan.md`: pass
- Evidence:
  - both decompose artifacts validate as `pass`
  - next boundary: `decompose->implement`

### `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-adapter-foundation --complete --confirm'`
- Result for `decompose -> implement`: pass
- Evidence:
  - completed decompose bookkeeping
  - advanced to `implement`

## Backend feature validation after implementation

### `go test ./...`
- Result: pass
- Coverage added in this session:
  - `furrow review status --json` summary surfaces
  - `furrow review validate --json` semantic rejection of inconsistent passing artifacts
  - row-status archive follow-up/disposition signals

### `go run ./cmd/furrow review status review-archive-boundary-hardening --json`
- Result: pass
- Evidence:
  - normalized review summaries for the archived historical row
  - surfaced:
    - `overall_verdicts`
    - `phase_a_verdicts`
    - `phase_b_verdicts`
    - `synthesized_overrides`
    - `follow_ups`

### `go run ./cmd/furrow review validate review-archive-boundary-hardening --json`
- Result: pass
- Evidence:
  - archived historical row review artifacts validate successfully under the richer semantic rules

### `go run ./cmd/furrow review status pi-adapter-foundation --json`
- Result: pass
- Evidence:
  - current row review expectations are visible even before the row reaches review
  - expected review artifacts are currently `missing`, which is truthful while the row remains at `implement`

### `go run ./cmd/furrow row status pi-adapter-foundation --json`
- Result after implementation work: pass
- Evidence:
  - row remains active at `implement / not_started`
  - current-step artifacts `plan.json` and `team-plan.md` validate as `pass`
  - blockers: `[]`
  - next boundary: `implement->review`

### `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-adapter-foundation'`
- Result after implementation work: pass
- Evidence:
  - Pi `/work` regrounds the row at `implement`
  - adapter remains backend-driven and surfaces no direct-state-edit requirement

## Conclusion
- Ceremony stayed ahead of implementation in this session: plan/spec/decompose artifacts were made substantive before advancement.
- The canonical row now sits at `implement` with the new review-status and review-validate backend surfaces landed.
- The row remains active and unarchived because additional work still belongs inside `pi-adapter-foundation`.
