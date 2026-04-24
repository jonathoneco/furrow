# Pi adapter promotion into repo-owned layout -- Summary

## Task
Promote the proven Pi Furrow extension into a repo-owned adapter layout while keeping the TypeScript layer thin and backend-driven

## Current State
Step: review | Status: completed
Deliverables: 3/3
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/pi-adapter-promotion/definition.yaml
- state.json: .furrow/rows/pi-adapter-promotion/state.json
- spec.md: .furrow/rows/pi-adapter-promotion/spec.md

## Settled Decisions
- **implement->review**: pass — archival backfill gate recorded during follow-up archive pass; summary.md and spec.md capture the completed adapter promotion and validation evidence

## Context Budget
Measurement unavailable

## Key Findings
- The promoted adapter preserves `/furrow-overview`, `/furrow-next`,
`/furrow-transition`, and `/furrow-complete`.
- Validation from the promoted adapter location confirmed the repo-owned path is
sufficient for normal Pi use.
- Temp-repo validation confirmed transition and completion still go through the
backend rather than through direct state edits.
- The promotion cleanly advances the active `pi-adapter-package` migration work
without thickening the TypeScript layer.

## Open Questions
- Which baseline Pi extension patterns should remain composed versus replaced as
the adapter matures?
- How should workflow-power preservation, step ceremony, and review surfaces be
layered on top of the promoted adapter without reimplementing Furrow in TS?

## Recommendations
- Keep `adapters/pi/furrow.ts` thin and treat backend output as the contract.
- Use this row as the canonical record of the adapter promotion outcome.
- Drive future Pi work from real workflow-power gaps rather than from adapter
abstraction for its own sake.
