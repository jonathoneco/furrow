# Minimum shared Go backend slice -- Summary

## Task
Implement the minimum shared Go backend slice for Furrow without introducing
Pi-only semantics, while keeping durable row context in canonical row artifacts.

## Current State
Step: implement | Status: in_progress
Deliverables: 5/5 complete
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/go-backend-slice/definition.yaml
- state.json: .furrow/rows/go-backend-slice/state.json
- summary.md: .furrow/rows/go-backend-slice/summary.md
- spec.md: .furrow/rows/go-backend-slice/spec.md

## Settled Decisions
- The backend slice remains intentionally narrow and truthful rather than
  pretending to be full Furrow lifecycle parity.
- Live repo document shapes are authoritative for almanac validation.
- Tolerant row reads are preferred over strict historical normalization.
- Durable context for this row now lives in canonical artifacts (`summary.md`
  and `spec.md`) instead of ad hoc progress, validation, and handoff files.

## Context Budget
Not measured

## Key Findings
- `furrow almanac validate --json` now validates the real current almanac files
  in this repo and returns structured findings.
- `furrow row list --json` and `furrow row status --json` now provide
  adapter-consumable browse/status data without requiring strict row-state
  normalization.
- `furrow row transition --json` is real but deliberately narrow: adjacent
  forward mutation only, with explicit limitation text persisted in state.
- `furrow doctor --json` now answers backend structural readiness rather than
  trying to mirror shell-era repo hygiene.

## Open Questions
- Should `furrow row list --json` continue defaulting to `all` rows for adapter
  usefulness, or switch to `active` for closer shell compatibility?
- Should the narrow-real transition limitations be surfaced even more directly
  in `docs/architecture/go-cli-contract.md`?

## Recommendations
- Keep the current narrow-real transition semantics until a real gate engine or
  stronger shared lifecycle need exists.
- Use this slice as the shared backend base for Pi and future thin adapters.
- If this row is resumed, advance it by producing canonical review evidence
  rather than recreating ad hoc handoff artifacts.
