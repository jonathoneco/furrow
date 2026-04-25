# Spec

## Scope
- Add backend normalization for durable review artifacts so Furrow can reason about Phase A, Phase B, overall verdicts, dimensions, synthesized overrides, and actionable findings from the review files that already exist in the repo.
- Implement backend review surfaces for the active row, centered on `furrow review status --json` and `furrow review validate --json`, without moving review semantics into TypeScript.
- Reuse the normalized review summary in `furrow row status --json` and archive-readiness evidence so `/work` can surface evaluator-grade review status plus follow-up or disposition signals.
- Limit Pi adapter work to rendering any newly exposed backend evidence fields needed for `/work`.

## Acceptance Criteria
- Review artifact validation is stricter than "recognizable JSON with pass-backed fields" and instead checks semantic consistency such as:
  - recognizable Phase A and Phase B verdicts
  - dimensions or acceptance-criteria evidence where the artifact shape claims them
  - consistency between phase verdicts, synthesized verdicts, totals, and overall verdict
  - meaningful timestamp and finding surfaces
- `furrow review status <row> --json` returns normalized per-artifact review summaries, aggregate verdict or finding counts, and archive-readiness implications for `pi-adapter-foundation` and historical rows.
- `furrow review validate <row> --json` returns success for semantically passing review artifacts and a validation failure for malformed or non-passing review evidence.
- `furrow row status pi-adapter-foundation --json` exposes the richer normalized review/archive evidence without TS-owned lifecycle logic.
- If the Pi adapter output changes, `adapters/pi/furrow.ts` only renders backend-provided fields.

## Verification
- `go test ./...`
- `go run ./cmd/furrow doctor --host pi --json`
- `go run ./cmd/furrow almanac validate --json`
- `go run ./cmd/furrow row status pi-adapter-foundation --json`
- `go run ./cmd/furrow review status pi-adapter-foundation --json`
- `go run ./cmd/furrow review validate pi-adapter-foundation --json`
- `go run ./cmd/furrow review status review-archive-boundary-hardening --json`
- `go run ./cmd/furrow review validate review-archive-boundary-hardening --json`
- `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-adapter-foundation'`
