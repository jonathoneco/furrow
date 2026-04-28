# Codex Session 2 Handoff: Completion Evidence Gates

## Landed In Session 1

- New rows are marked with `truth_gates_version: 1`; historical rows remain grandfathered unless explicitly opted in with `truth_gates_required` or `retrospective_audit`.
- Harness-owned artifact materialization now lives in `internal/cli/row_artifacts.go`, with scaffold rendering backed by embedded templates under `internal/cli/scaffolds/`.
- Completion-evidence artifacts are enforced for gated rows:
  - `ask-analysis.md`
  - `test-plan.md`
  - `completion-check.md`
- Archive readiness blocks:
  - missing/incomplete/invalid completion-evidence artifacts,
  - `completion-check.md` verdict `incomplete`,
  - row-local `follow-ups.yaml` entries with `deferral_class: required_for_truth` and `truth_impact: blocks_claim`.
- Archive readiness now exposes PR prep data in `archive_ceremony.pr_prep`.
- Review validation for completion-evidence rows requires `harness_process_risks` or equivalent coverage.
- Prompt guidance was updated for:
  - real option spread and scout/dive research,
  - worktree discipline,
  - deferral classification,
  - specialists as skills rather than registered agent types,
  - parity as claim-surface equivalence.
- Durable architecture framing now lives in `docs/architecture/completion-evidence-and-claim-surfaces.md`.

## Verified

- `go test ./internal/cli/...`
- `go test ./...`
- `go run ./cmd/furrow almanac validate --json`

## Remaining Hardening

- Promote `follow-ups.yaml` into a named artifact with scaffold support if row-local follow-ups become common.
- Make claim-surface parity more structured than prose parsing, likely via a small artifact schema or a `claim_surfaces` block.
- Enforce `complete-with-downgraded-claim` against actual summary/roadmap/docs wording changes, not just completion-check evidence.
- Add adapter-side consumption checks if Pi/Claude wrappers bypass the Go archive readiness surface.
- Add dedicated integration shell fixtures if desired; current coverage is in Go CLI tests.
