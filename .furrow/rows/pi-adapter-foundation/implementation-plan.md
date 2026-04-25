# Implementation Plan

## Objective
- Continue the canonical row `pi-adapter-foundation` by deepening backend-owned review semantics inside `work-loop-boundary-hardening`, then surface archive disposition signals through the same backend-first contract without minting another row.

## Planned work
1. Normalize review artifacts semantically in the backend.
   - Parse existing review JSON shapes into a normalized summary instead of treating them as mere pass-backed blobs.
   - Enforce richer consistency checks for Phase A, Phase B, overall verdicts, dimensions, synthesized verdicts, and evidence fields while staying compatible with historical repo artifacts.
2. Surface evaluator-grade review status.
   - Add backend review-status/summary surfaces that expose per-artifact verdicts, finding counts, and archive-readiness implications.
   - Reuse those normalized surfaces in `furrow row status` so `/work` gets stronger review context without TS-owned lifecycle logic.
3. Expand archive disposition signals.
   - Derive actionable follow-up or disposition candidates from review evidence and expose them in backend archive-readiness surfaces.
   - If adapter output changes are needed, keep them rendering-only in `adapters/pi/furrow.ts`.
4. Validate and keep the row active.
   - Advance `pi-adapter-foundation` through spec and decompose with substantive artifacts before implementation.
   - Land backend code, tests, and any thin adapter/doc sync needed for truthful repo state.
   - Do not archive the row just because this slice lands; keep `pi-adapter-foundation` as the active roadmap-row work unit.

## Validation
- `go test ./...`
- `go run ./cmd/furrow doctor --host pi --json`
- `go run ./cmd/furrow almanac validate --json`
- `go run ./cmd/furrow row status pi-adapter-foundation --json`
- `go run ./cmd/furrow review status pi-adapter-foundation --json` if landed
- `go run ./cmd/furrow review validate pi-adapter-foundation --json` if landed
- `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-adapter-foundation'`
- `pi --no-session --no-context-files --no-extensions -e ./adapters/pi/furrow.ts -p '/work --switch pi-adapter-foundation --complete --confirm'` at supported boundaries
