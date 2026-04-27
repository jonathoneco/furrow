# Research Synthesis — `blocker-taxonomy-foundation`

This synthesis consolidates findings from three parallel research deliverables:
- `research/hook-audit.md` — per-hook audit and code-name mapping
- `research/status-callers-and-pi-shim.md` — `furrow row status` caller inventory + Pi adapter landscape
- `research/test-infra-and-contradiction-passages.md` — test runner conventions + verbatim contradiction passages

Cross-references the contract at `.furrow/rows/blocker-taxonomy-foundation/definition.yaml`.

## Headline findings

1. **Hook migration target is 10, not 11.** `gate-check.sh` is dead code (body is `return 0`). Implement step deletes it; D3's "no domain logic remains" criterion is trivially satisfied by removal.
2. **5/5 mechanical-vs-non-trivial split.** Within the row's no-hybrid-state constraint, all 10 are migratable in implement. Two deferral candidates are named (`script-guard.sh` 100-line awk parser; `work-check.sh` `updated_at` timestamp side-effect) only as escape valves if implement-step time forces a cut.
3. **D1 ≥15 codes target is over-cleared.** 11 new codes from hook migration + ~10 from Go-side enforcement (`rws transition`, `sds`, archive flow) = ≥21 codes total. Registry coverage extends beyond the hook-emit set.
4. **`furrow row status` migration is a single-point fix.** The `blocker(...)` constructor at `internal/cli/row_semantics.go:46-58` is the only producer; today's shape diverges on 4 axes (severity hardcoded `"error"`, `confirmation_path` prose, no `remediation_hint`, arbitrary detail keys). One file, one Pi render-side update at `adapters/pi/furrow.ts:395-402`. **No backward-compat shim required.**
5. **No new Pi shim — use existing `adapters/pi/validate-actions.ts`.** `migration-stance.md:110-116` explicitly forbids parallel Pi adapters. The existing factoring with `ValidationErrorEnvelope` is already the legitimate consumer for the parity-test driver. Live Pi-runtime invocation is correctly captured as the existing follow-up TODO `pi-tool-call-canonical-schema-and-surface-audit`.
6. **Test wiring is automatic.** `tests/integration/run-all.sh` auto-discovers `test-*.sh` via glob. **No `Makefile` and no `.github/workflows/` exist** in this repo. D4's `file_ownership: Makefile` is incorrect and should be removed.
7. **D5 meta-pattern threshold is met.** Contradictions (1) and (3) share an anti-pattern: target/implementation doc states broader scope than contract doc with no precedence rule. D5 AC.4 fires — `documentation-authority-taxonomy.md` gets a small update.
8. **Source-TODO citation error.** `doc-contradiction-reconciliation` cites `go-cli-contract.md:385-388` as the "does NOT enforce" block; the real block is at `go-cli-contract.md:392-399`. Implement step uses the corrected range. Lines 385-388 are actually the *does-enforce* list and are not in scope for reconciliation.

## Definition.yaml amendments warranted

These are mechanical corrections from research findings, not scope changes:

- **D3 inventory**: replace `gate-check.sh` in the candidate list with a separate note "`gate-check.sh` is dead code — deleted, not migrated." 10 emit-bearing migrations remain.
- **D4 `file_ownership`**: remove `Makefile` entry; auto-discovery via `run-all.sh` makes wiring automatic. Add `adapters/pi/**` for the Pi-side test driver (consuming existing `validate-actions.ts`, not authoring new shim).
- **D5 AC.4**: research confirms meta-pattern threshold is met; AC will fire (the AC stays as written; this is just confirming the trigger condition).

## Open questions resolved

- **Audit-report location**: row-local `research/hook-audit.md` already exists. Recommend **keeping it row-local** (not promoting to `docs/architecture/blocker-emission-audit.md`) — its value is row-scoped guidance for implement, not enduring canonical reference. D3's audit-report AC should accept the row-local form.
- **Pi adapter shim location**: resolved — no new shim. Existing `adapters/pi/furrow.ts` + `validate-actions.ts` is the consumer.
- **Hook complexity threshold**: 5/5 split is comfortable for N1; no scope-cut required. Both deferral candidates remain available if implement step exceeds budget.
- **`furrow row status` caller inventory**: 1 envelope-tolerant consumer (Pi), 0 needing migration, 6 plain-text-opaque (don't surface blockers), ~15 doc/prompt mentions. Migration plan is bounded.

## Plan-step inputs

The plan step should consume:
- `research/hook-audit.md` for the per-hook migration order (mechanical first, then non-trivial), helper extraction sequence, and dead-code deletion.
- `research/status-callers-and-pi-shim.md` Section A for the single-point `blocker(...)` migration.
- `research/test-infra-and-contradiction-passages.md` Section C for fixture layout and Section D for verbatim contradiction passages with corrected line ranges.

## Recommended deliverable execution order (for plan)

1. **D1 canonical taxonomy** — extend `schemas/blocker-taxonomy.yaml` to ≥21 codes; update `blocker(...)` constructor at `row_semantics.go:46-58`; update Pi render at `furrow.ts:395-402`.
2. **D2 normalized event + Go emission path** — schema, schema validator, Go entry point.
3. **D3 hook migration** (depends on D2) — sequence: delete `gate-check.sh`; migrate 5 mechanical hooks; migrate 5 non-trivial; quality-audit deltas recorded inline.
4. **D5 doc reconciliation** — runs in parallel with D2/D3 (no code dependency).
5. **D4 coverage + parity tests** — final validation; depends on all of D1–D3.

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|--------------|
| `.furrow/rows/blocker-taxonomy-foundation/research/hook-audit.md` | primary (this row) | Per-hook audit, complexity classification, helper extraction |
| `.furrow/rows/blocker-taxonomy-foundation/research/status-callers-and-pi-shim.md` | primary (this row) | Status caller inventory, Pi adapter landscape |
| `.furrow/rows/blocker-taxonomy-foundation/research/test-infra-and-contradiction-passages.md` | primary (this row) | Test runner conventions, verbatim contradiction passages |
| `.furrow/rows/blocker-taxonomy-foundation/definition.yaml` | primary (this row) | Work contract; cross-referenced for AC fitment |
