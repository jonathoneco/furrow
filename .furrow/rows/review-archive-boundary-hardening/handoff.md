# Handoff

## Outcome of this slice

This row stayed inside the existing Phase 3 `work/pi-adapter-foundation` /
`work-loop-boundary-hardening` boundary and landed the next backend-canonical
hardening slice.

What is now real in the repo:
- `furrow row init --source-todo ...` now consumes the canonical planning file
  through the same tolerant YAML path as almanac validation, fixing the live
  mismatch that blocked supported row creation
- coordinated `implement` rows now validate carried decompose artifacts
  (`plan.json`, `team-plan.md`) as current-step boundary inputs
- `review` rows now treat durable review artifacts under `reviews/` as
  first-class current-step artifacts and block archive when review evidence is
  missing, malformed, or non-passing
- `furrow row status --json` now surfaces richer checkpoint evidence including
  latest gate evidence details and archive-readiness ceremony summary
- `furrow row archive --json` now records and returns richer archive evidence
  including review summary, source-link context, and learnings presence/count
- the existing Pi adapter in `adapters/pi/furrow.ts` renders the richer backend
  checkpoint/archive evidence without re-deriving lifecycle semantics in TS

## Files changed in this slice

Code:
- `internal/cli/row_workflow.go`
- `internal/cli/row_semantics.go`
- `internal/cli/row.go`
- `internal/cli/app_test.go`
- `adapters/pi/furrow.ts`

Architecture/docs:
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/pi-parity-ladder.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`

Durable row artifacts:
- `.furrow/rows/review-archive-boundary-hardening/definition.yaml`
- `.furrow/rows/review-archive-boundary-hardening/research.md`
- `.furrow/rows/review-archive-boundary-hardening/implementation-plan.md`
- `.furrow/rows/review-archive-boundary-hardening/spec.md`
- `.furrow/rows/review-archive-boundary-hardening/plan.json`
- `.furrow/rows/review-archive-boundary-hardening/team-plan.md`
- `.furrow/rows/review-archive-boundary-hardening/reviews/*.json`
- `.furrow/rows/review-archive-boundary-hardening/gates/*.json`
- `.furrow/rows/review-archive-boundary-hardening/execution-progress.md`
- `.furrow/rows/review-archive-boundary-hardening/validation.md`
- `.furrow/rows/review-archive-boundary-hardening/handoff.md`
- `.furrow/rows/review-archive-boundary-hardening/state.json` (backend-mediated progression and archival)

## Final row state
- Row: `review-archive-boundary-hardening`
- Scope: Phase 3 / `work/pi-adapter-foundation` / `work-loop-boundary-hardening`
- Archived: yes
- Final lifecycle state: `review / completed`
- Latest gate: `review->archive`
- Archive checkpoint evidence: `.furrow/rows/review-archive-boundary-hardening/gates/review-to-archive.json`
- Focus pointer: cleared through `furrow row focus --clear --json`

## Mismatch explicitly reconciled

A real planning-vs-repo mismatch was found and fixed:
- Before the code change, `furrow almanac validate --json` passed but
  `furrow row init --source-todo work-loop-boundary-hardening --json` failed on
  the same canonical planning file because row init used a stricter YAML path.
- This slice reconciled that mismatch in backend code rather than editing the
  canonical planning file or silently normalizing the failure.

A later row-model reconciliation also established a structural mismatch:
- roadmap row `work/pi-adapter-foundation` should map to Furrow row
  `pi-adapter-foundation`
- this row therefore remains historical execution truth for one landed follow-up
  slice under that roadmap row, but it is **not** the canonical row-model match
  for the roadmap row itself
- treat this row as an archived execution anomaly/sub-slice record rather than
  the long-lived Furrow row that should carry the roadmap row forward

## Recommended next slice

Historical note: this recommendation was later superseded by row-model
reconciliation.

Do **not** continue by opening another todo-specific execution row.
Continue the remaining work inside the canonical Furrow row
`pi-adapter-foundation` instead.

Next emphasis within `work-loop-boundary-hardening`:
1. deeper evaluator-grade review semantics, not just pass-backed review-artifact validation
2. fuller archive ceremony mutations for learnings/components/follow-up disposition
3. later dual-host validation of blocker taxonomy and boundary semantics once the backend contract settles a bit further

## Constraints to preserve
- `.furrow/` remains canonical
- supported mutations go through backend/CLI authority only
- use the existing adapter only: `adapters/pi/furrow.ts`
- keep TypeScript thin and backend-driven
- do not reopen archived rows; start the next slice in a new in-scope row through supported Furrow commands
