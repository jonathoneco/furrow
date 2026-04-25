# Research

## Questions
- What Furrow row should canonically correspond to roadmap row `work/pi-adapter-foundation`?
- Does the current repo history already follow roadmap-row ⟷ Furrow-row mapping, or is it still split across todo-shaped rows?
- Was `review-archive-boundary-hardening` structurally correct, or is it a historical anomaly within the same roadmap row?
- Was the prior follow-up session ceremony-first, or did it use post-hoc artifact and stage catch-up after implementation had already begun?
- Where should the remaining work now live truthfully?

## Findings
- The roadmap already says what the canonical row should be: Phase 3 row index 1 has branch `work/pi-adapter-foundation`, description and todo set covering `pi-adapter-package`, `backend-mediated-row-bookkeeping`, `workflow-power-preservation`, `pi-step-ceremony-and-artifact-enforcement`, `work-loop-boundary-hardening`, and `parallel-orchestration-and-launch-surfaces`. Under the stated row model, that roadmap row should map to Furrow row `pi-adapter-foundation`.
- The repo did not previously have a Furrow row named `pi-adapter-foundation`. Instead, the historical execution record is split across multiple narrower Furrow rows under the same roadmap row, including `pi-step-ceremony-and-artifact-enforcement` and `review-archive-boundary-hardening`. That means the current repo history is still structurally row-modeled closer to per-todo or per-slice execution than the desired roadmap-row ⟷ Furrow-row model.
- `review-archive-boundary-hardening` is therefore not structurally the canonical Furrow row for roadmap row `work/pi-adapter-foundation`. It is best treated as a historical execution anomaly or sub-slice row under that roadmap row: real implementation landed there, but it does not satisfy the intended row-model mapping by itself.
- The prior follow-up session was not ceremony-first in the strong Furrow sense. Even though it used backend commands for lifecycle mutations, the historical evidence shows retrospective catch-up behavior:
  - the row was minted specifically for `work-loop-boundary-hardening`, not for the roadmap row
  - the step progression from ideate through implement-to-review happened within minutes, which is inconsistent with genuine stage-shaped work discovery for a real backend slice
  - the row's own artifacts describe retrospective decomposition and reconciliation after work had effectively already landed
  - the session used the Pi adapter as validation and archival path, but not as the primary ceremony surface that shaped the work from the beginning
- `pi-step-ceremony-and-artifact-enforcement` remains valid historical truth for the earlier slice, but its handoff recommendation to open a new in-scope row under the same roadmap row helped continue the narrower per-slice row pattern rather than the stronger roadmap-row ⟷ Furrow-row mapping.
- The truthful next location for remaining work is now this canonical row, `pi-adapter-foundation`. Remaining work inside it still includes at least:
  - deeper evaluator-grade review semantics beyond pass-backed review-artifact validation
  - fuller archive promotion or disposition ceremony beyond readiness evidence
  - later dual-host validation of blocker taxonomy and boundary semantics
  - and potentially `parallel-orchestration-and-launch-surfaces` once the row explicitly chooses to shift emphasis inside the same row rather than spawning another Furrow row

## Sources Consulted
- `README.md`
- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/pi-parity-ladder.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/architecture/migration-stance.md`
- `docs/architecture/workflow-power-preservation.md`
- `docs/handoffs/post-review-pi-step-ceremony-and-artifact-enforcement.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/state.json`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/execution-progress.md`
- `.furrow/rows/review-archive-boundary-hardening/state.json`
- `.furrow/rows/review-archive-boundary-hardening/handoff.md`
- `.furrow/rows/review-archive-boundary-hardening/execution-progress.md`
- `.furrow/rows/review-archive-boundary-hardening/validation.md`
