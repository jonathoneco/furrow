# Research

## Questions
- Why did supported `furrow row init --source-todo ...` fail in the live repo even though `furrow almanac validate --json` passed?
- What existing row artifacts and review shapes already exist in Furrow that the backend can validate instead of inventing new TypeScript semantics?
- How can the next slice deepen review/archive evidence and implement/review validation while staying inside the existing Phase 3 boundary?

## Findings
- The live repo had a real backend mismatch: `furrow almanac validate --json` used tolerant YAML loading and passed `.furrow/almanac/todos.yaml`, while `row init` used a stricter direct YAML unmarshal path and failed on the historically duplicated `updated_at` keys in that same file. This blocked supported creation of the next in-scope row.
- Existing durable Furrow review artifacts already live under `reviews/`. The repo contains several compatible shapes the backend can validate without inventing new adapter-owned semantics, including per-deliverable review JSON with `overall`, synthesized review JSON with `synthesized_verdict`, and aggregate review files such as `reviews/all-deliverables.json`.
- Existing row layout docs already describe `plan.json`, `team-plan.md`, and `reviews/{deliverable}.json` as durable artifacts. That makes them good candidates for stronger backend validation during implement and review without creating a parallel artifact track.
- The narrow archive path already had a passing `implement->review` gate precondition. The natural next move is to require actual review artifacts to pass as part of archive readiness and to surface richer archive evidence such as latest gate evidence, source-link context, and learnings presence.
- The Pi adapter can stay thin because it already renders backend checkpoint and current-step artifact data. Adding richer backend evidence surfaces automatically strengthens `/work` output without moving lifecycle rules into TypeScript.

## Sources Consulted
- README.md — current dual-host frame and adapter boundary
- .furrow/almanac/roadmap.yaml — Phase 3 row and row-local sequencing
- .furrow/almanac/todos.yaml — `work-loop-boundary-hardening` scope and live duplicate-key reality
- docs/architecture/go-cli-contract.md — current backend contract and Slice 2 remaining work
- docs/architecture/pi-parity-ladder.md — current parity gaps and recommended sequencing
- docs/architecture/pi-step-ceremony-and-artifact-enforcement.md — prior slice and fast-follow scope
- docs/handoffs/post-review-pi-step-ceremony-and-artifact-enforcement.md — recommended next slice
- references/row-layout.md — durable artifact contract for plan and review files
- references/review-methodology.md — expected review result structure and pass/fail semantics
- internal/cli/row_workflow.go, internal/cli/row.go, internal/cli/row_semantics.go — current backend implementation truth
