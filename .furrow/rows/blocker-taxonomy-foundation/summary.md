# Canonical blocker schema + Claude-side audit + contradiction reconciliation -- Summary

## Task
Establish a canonical adapter-agnostic blocker taxonomy and a Go-first emission path that both runtimes invoke through normalized events, prove no silent divergence via parity tests, and reconcile the three open doc-vs-doc contradictions in one pass.

## Current State
Step: review | Status: completed
Deliverables: 5/5
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/blocker-taxonomy-foundation/definition.yaml
- state.json: .furrow/rows/blocker-taxonomy-foundation/state.json
- plan.json: .furrow/rows/blocker-taxonomy-foundation/plan.json
- research/: .furrow/rows/blocker-taxonomy-foundation/research/
- specs/: .furrow/rows/blocker-taxonomy-foundation/specs/
- team-plan.md: .furrow/rows/blocker-taxonomy-foundation/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Definition validated; summary complete with key-findings/open-questions/recommendations; dual outside-voice review complete (fresh reviewer + codex cross-model rated framing sound); all material review findings applied (status canonical envelope AC, sharper D3 ACs with line-count + subprocess-only constraints, versioned event schema, parity-test subprocess-invocation assertion, meta-pattern threshold). User approved transition.
- **research->plan**: pass — Three parallel research agents completed; synthesis.md consolidates findings. Hook target confirmed at 10 emit-bearing (gate-check.sh dead code), 5/5 mechanical/non-trivial split. Status migration is single-point at row_semantics.go:46-58. Pi adapter consumer (validate-actions.ts) already canonical — no new shim per migration-stance. Test wiring auto-discovered via run-all.sh glob. Meta-pattern threshold met for D5. Citation error in source TODO caught (go-cli-contract.md:392-399 not 385-388). Definition.yaml amended (D3 inventory, D4 Makefile out + adapters/pi/** in) and revalidated. User approved transition.
- **plan->spec**: pass — Plan step complete. plan.json (4 waves) + team-plan.md + amended definition.yaml all validate. Dual review applied: fresh reviewer flagged D1 specialist mismatch + scope sprawl + D5 forward citation (all applied — D1 reassigned to migration-strategist, file_ownership expanded, forward citation documented); cross-model codex flagged D3 audit-doc alignment + D4 emit-site inventory gate + W3 fallback thresholds (all applied — D3 row-local at research/hook-audit-final.md, D4 inventory AC added, W3 thresholds 4h/2h with TODO-before-W4). Three plan decisions locked: _warn suffix convention, D2 lands lib helpers first, Pi prose from remediation_hint. User approved transition.
- **spec->decompose**: pass — Five per-deliverable specs authored in parallel; dual reviewer flagged 8 cross-spec drifts; resolved via specs/shared-contracts.md (C1-C9) which takes precedence over individual specs (C9 rule). Locked: 10 per-hook event types, furrow guard CLI (no flags, array stdout, exit 0/1 only), 6-field BlockerEnvelope with caller-owned details, blocker_emit.sh contract with 4 named exports, hook shim canonical 4-step pattern <=30 lines, single internal/cli/guard.go layout, taxonomy walk via .blockers[].code, Pi-handler-absent skip rule. Each individual spec carries a precedence note. Summary updated. User approved transition.
- **decompose->implement**: pass — Decompose confirmed plan.json wave structure (4 waves, 5 deliverables); team-plan.md amended with shared-contracts coordination notes (C1 parity check, C2 CLI anti-cheat, C5 line-count discipline, C7 Pi skip rule, W3 fallback mechanics); internal/cli/** ownership cleanly partitioned (D1 edits existing, D2 adds new siblings per C6); vertical slicing confirmed; branch work/blocker-taxonomy-foundation already exists. User approved transition.
- **implement->review**: pass — All 5 deliverables completed with zero corrections across 4 waves. 7 commits on branch. D1 canonical taxonomy 11->40 codes with envelope cutover; D2 furrow guard CLI + blocker_emit.sh per shared-contracts C1-C9; D3 10 hooks to canonical 4-step shims (avg 5 exec lines vs 43 pre-migration), gate-check.sh deleted; D4 coverage+parity tests (244+59+14+6 assertions pass, 13 logged Pi skips per pi-tool-call-canonical-schema-and-surface-audit TODO); D5 4 doc reconciliations + new authority-taxonomy section. Coordinator settings.json gate-check unregister landed. All anti-cheats verified. go test, frw validate-definition, all integration tests PASS. User approved transition.

## Context Budget
Measurement unavailable

## Key Findings
- **All 5 deliverables PASS dual-reviewer protocol** (Phase A in-session + Phase B fresh-context + cross-model). 7 commits on `work/blocker-taxonomy-foundation` ahead of `main`.
- **Phase A (in-session)**: every changed file maps to exactly one deliverable's `file_ownership`; `rws transition` confirmed "no unplanned changes detected". Coordinator-level `.claude/settings.json` fix (gate-check unregister) committed separately and explicitly out of any deliverable's ownership.
- **Phase B fresh-context reviews (5/5 PASS)**:
- D1 canonical-blocker-taxonomy: 9/9 dimensions PASS — 40 codes; canonical envelope shape; backward-compat 11 frozen via `TestBlockerTaxonomyBackwardCompat11`; Pi render uses `remediation_hint`.
- D2 normalized-event + Go emission: 8/8 PASS — 10 event types verbatim per §C1; CLI accepts no flags; stdout always JSON array; exit 0/1 only; drift-guard test asserts bidirectional parity.
- D3 hook migration + audit: 9/9 PASS — 10 shims at ≤13 exec lines (max), no domain logic, anti-cheat greps clean, audit report complete with 0 deferrals.
- D4 coverage + parity tests: 9/9 PASS — `yq '.blockers[].code'`; 40 fixture sets; subprocess-invocation + emit-site inventory anti-cheats verified; Pi-handler-absent skip rule logs follow-up TODO.
- D5 doc reconciliation: 6/6 PASS — three reconciliation notes + meta-pattern §5; corrected line range 392-399 used; D5/D1 file-ownership boundary respected (pi-step-ceremony doc untouched).
- **Cross-model reviews (4 PASS, 1 hallucination invalidated)**:
- D1: PASS 4/5 (soft test-coverage flag on new helpers `candidateTaxonomyPaths` and `moduleSourceRoot` — exercised indirectly via every `LoadTaxonomy` test, no direct unit tests; documented as soft, not blocking).
- D2: PASS 6/6 on retry (initial run failed due to argv overflow in cross-model script).
- D3: initial cross-model claimed `test-precommit-block.sh` fails 8/14 — **invalidated** by local re-run showing 14/14 PASS. Sandbox env hallucination.
- D4: PASS 5/7 on retry — one real soft flag (`correction_limit_reached` has SKIP_REASON despite being shim-emitted; covered by `internal/cli/correction_limit_test.go` unit test, integration fixture is named follow-up TODO `correction-limit-integration-fixture`); one false fail (codex sandbox /tmp read-only).
- D5: PASS 5/5.
- **Soft flags documented** (none blocking archive):
- D1: new taxonomy-path helpers lack direct unit tests (covered indirectly).
- D3: pre-commit shims contain a 4-line empty-payload short-circuit (commit `d5935e3`) that is borderline against the "no shell-side conditional" AC; documented as pragmatic deviation working around a Go `requireArray` rejection. Decision: accept as-is; if Go relaxes, the short-circuit can be removed.
- D4: `correction_limit_reached` integration fixture deferred to follow-up TODO; behavior covered by Go unit test.
- **Learnings captured** at `.furrow/rows/blocker-taxonomy-foundation/learnings.jsonl` (7 entries) including: shared-contracts as cross-spec arbiter; per-hook event types over collapsed categories; JSON-array stdout uniformly; cross-model hallucinations are real (verify locally); backend-owns-enforcement boundary; parity anti-cheat patterns; Pi-handler-absent skip rule.

## Open Questions
- **No open questions blocking archive**. All deliverables PASS both Phase A and Phase B with documented soft flags.
- **Follow-up TODOs already named** in the row's research/audit artifacts:
- `pi-tool-call-canonical-schema-and-surface-audit` (existing) — wires per-code Pi handlers, activating the 13 currently-skipped parity invocations.
- `correction-limit-integration-fixture` (new from D4) — promote integration fixture for `correction_limit_reached` once trigger plumbing is materializable in test sandbox.
- CI wiring of `tests/integration/run-all.sh` (if not already covered by existing TODO).
- **Decision-review observations**: none of the locked decisions in this row are conditional on post-ship evidence; no `alm observe add --kind decision-review` entries needed.

## Recommendations
- **Ready to archive**. All 5 deliverables PASS dual-reviewer protocol; soft flags documented and named as follow-up TODOs.
- **At archive (`/furrow:archive`)**: present 7 learnings for promotion review (see `learnings.jsonl`); promote follow-up TODOs (`correction-limit-integration-fixture`) into `.furrow/almanac/todos.yaml` if not already; verify branch is clean.
- **Branch state**: `work/blocker-taxonomy-foundation` carries 7 commits (5f4fd59 D1, fff5fa4 D5, dc06f79 D2, 781681b D3, d5935e3 D3-fix, d5bc32d coordinator settings.json, 4c76d90 D4). Ready for `/furrow:merge` after archive.
- **Net effect on the codebase**:
- Canonical 40-code blocker registry; adapter-agnostic; schema-validated; backward-compat 11 frozen.
- Single Go emission entry point (`furrow guard <event-type>`) consuming normalized event JSON, emitting canonical envelope JSON arrays.
- 10 thin Claude shims (avg 5-13 exec lines vs 43 pre-migration); 540 lines removed; gate-check.sh dead code deleted.
- Three doc-vs-doc contradictions reconciled inline; new authority-taxonomy §5 captures the meta-pattern.
- 244+59+14+6 integration assertions guard the canonical envelope, fixture coverage, parity, and pre-commit-hook semantics. Anti-cheat: subprocess-invocation grep + emit-site inventory enumerate.
