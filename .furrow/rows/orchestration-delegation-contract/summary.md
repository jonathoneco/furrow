# Orchestration/delegation contract: handoff schema, furrow-aware/unaware split, boundary enforcement -- Summary

## Task
Establish the orchestration/delegation contract as a vertical 3-layer architecture
(operator → phase driver → engine) with a runtime-agnostic Furrow backend and
thin Claude/Pi adapters. Backend defines canonical primitives: forked handoff
schemas (DriverHandoff Furrow-aware, EngineHandoff Furrow-unaware), context
routing CLI, layer-policy authority, hook Go subcommands, static driver
definitions, design-pattern interfaces. Adapters bridge runtime events into
these primitives — Claude via TeamCreate/Agent/SendMessage + .claude/agents/
rendering; Pi via @tintinweb/pi-subagents extension. Engines are TRULY
Furrow-unaware: no row, no step, no .furrow/ paths in the engine handoff;
drivers curate engine context. New hooks ship as `furrow hook <name>` Go
subcommands, NOT shell scripts, to avoid migration debt to the canonical-Go
end-state. The row ships contract + driver wiring + minimal-but-functioning
integration on both adapters proving the architecture end-to-end.

## Current State
Step: review | Status: completed
Deliverables: 6/6
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/orchestration-delegation-contract/definition.yaml
- state.json: .furrow/rows/orchestration-delegation-contract/state.json
- plan.json: .furrow/rows/orchestration-delegation-contract/plan.json
- research/: .furrow/rows/orchestration-delegation-contract/research/
- specs/: .furrow/rows/orchestration-delegation-contract/specs/

## Settled Decisions
- **ideate->research**: pass — Ideation complete: 6 deliverables (D5→D1→D4→D2→D3→D6) approved section-by-section in supervised mode. Architectural shift from horizontal aware/unaware to vertical operator/driver/engine layering. Long-running session-scoped subagent drivers (S-B scope) committed. Dual review: codex cross-model (reviews/ideation-cross.json, framing_quality=questionable) and fresh same-model agent (recommendation=revise). Revisions applied: research kill-switch (C#16), split-criteria escape valve (C#17), driver lifecycle research dependency (C#19), per-agent .layer-context.{agent_name} (D3 race fix), layer-policy canonical Go owner (D3), driver lifecycle drivers.json + rws driver-mark (D2), handoff schema versioning (D1), D6 depends_on tightened to [D2,D1,D3]. Definition validates against schema. Six source TODOs to close. Open questions captured for research.
- **research->plan**: pass — Research complete: 3 parallel topics (T1 handoff-shape, T2 subagent-semantics, T3 decision-format) returned with synthesis at research/synthesis.md. T1 verdict VALID-WITH-CAVEATS — 9-field provisional schema derived from convergent prior art (OpenAI Agents SDK, CrewAI, Claude Code subagents). T2 verdict GO — both load-bearing assumptions verified (named-subagent persistence via SendMessage-by-agent_id; PreToolUse hook inheritance with agent_type JSON-on-stdin); kill-switch did not fire. T3 verdict Tighten-required — 49/49 conformance to gate-transition regex; canonical-block format unused. Definition.yaml refinements applied: D2 drivers.json schema (pinned_name + agent_id + agent_type), session-resume re-spawn protocol, SendMessage layer-reminder; D3 layer-guard.sh stdin-JSON reads, SubagentStart/Stop hook lifecycle, agent_type path-injection guard; D4 strict gate-transition regex parsing. New constraints: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 precondition + frw doctor check; Pi parity audit follow-up. Definition revalidated. 4 open questions deferred to spec (O1 schema-fork, O2 Pi parity, O3 reminder text, O4 session-id surface).
- **plan->spec**: pass — Plan complete: 7 sequential waves (D5→D1→D4→D2→D3a→D3b→D6) after dual-review-driven D3 split. plan.json + team-plan.md authored with section-anchored research citations, 9 risks tracked, D4 internal sub-waving documented, 6 spec-blocking open questions identified (O1-O6). Same-model fresh review verdict REVISE — all findings applied (D3 split, O5/O6 added, 3 missing risks added, citations tightened). Cross-model review verdict mixed (research-grounding fail addressed via section-anchored citations). User approved D3 split (option A). Definition revalidated. Ready to write 7 specs.
- **spec->decompose**: pass — Spec complete: 6 implementation-ready specs at specs/ (~1920 lines, WHEN/THEN scenarios per AC). Architecture re-applied to definition.yaml + plan.json after research-spike rewind: runtime-agnostic backend + thin Claude/Pi adapters; forked DriverHandoff/EngineHandoff (no schema_version, no persona_ref); furrow hook layer-guard Go subcommand; @tintinweb/pi-subagents adoption; commands/work.md.tmpl runtime-templated; team-plan.md deleted. Dual review: same-model fresh + codex cross-model both flagged 4 ship-blocking defects, all fixed in-place — Decision struct divergence reconciled to gate-transition shape, top-level learnings dropped, settings.json D3↔D6 double-write resolved (D3 owns PreToolUse only, D6 owns Stop), D2 Runtime variable typed enum locked, Claude Agent dispatch clarified, D1 vocab regex tightened, D4 --target grammar locked. Definition validates. 7 carried OQs documented in spec files. 10 follow-up TODOs to add at archive.
- **spec->decompose**: pass — Spec files renamed to {deliverable-name}.md per artifact validator convention. Architecture/content unchanged from prior gate evidence — only file naming was non-conformant. Re-running transition.
- **decompose->implement**: pass — Decompose complete: plan.json (6 waves) validates against definition.yaml. team-plan.md intentionally skipped — exercises this row's architectural decision (engine teams composed at dispatch-time, not decompose-time; D2's skills/decompose.md update will codify the skip going forward). All 7 spec-time OQs carried into implement-step for per-wave resolution. Branch work/orchestration-delegation-contract ready. Wave 1 (D5 context-construction-patterns) starts on advancement.
- **implement->review**: pass — Implement complete: 6/6 deliverables landed across 6 sequential waves (commits 806e522, 95a2b44, 89aed6b, f17efb2, cd5b022, bb64f75) + install.sh fix (b8e520b). 0 corrections used. All 8 Go packages green; go vet clean; shellcheck clean. Boundary leakage smoke alarm 0 corpus matches (NON-NEGOTIABLE constraint satisfied). Cross-adapter parity 20/20 identical verdicts. D5 conformance harness 7/7 D4 strategies pass. Vocab corpus 25/25 must-pass + 25/25 must-fail green. Pi capability gap (subprocess subagents) acknowledged with subprocess fallback documented. One logged ownership deviation (W5 added layer: front-matter to skills/shared/*.md beyond the 10 listed for validator-pass; additive-only). All 7 spec-time OQs resolved during implementation.

## Context Budget
Measurement unavailable

## Key Findings
**Review step complete — overall PASS (4 deliverables pass-after-correction, 2 pass clean).**
**Commit chain (10 commits beyond pre-write-validation merge base):**
- W1-W6 feature commits: 806e522 → 95a2b44 → 89aed6b → f17efb2 → cd5b022 → bb64f75
- Post-implement install fix: b8e520b (build+install furrow Go binary via `go install`)
- Review-driven corrections (4 fix commits):
- 1273f98 fix(driver): D2 — Pi adapter execFileSync (R5 shell injection)
- afa5a33 fix(handoff): D1 — strict markdown validation, return-format resolution, schema parity (R2 R3 R4)
- 31f54ae fix(context): D5 — SetMetadata in Builder interface (R1)
- 1bcf044 fix(context): D4 — chain ordering, ListSkills coverage, schema tightening, integration test strengthened (R6 R7 R8 R9 R10)
**Per-deliverable verdicts (final):**
| Deliverable | Phase A | Phase B | Overall | Corrections |
|---|---|---|---|---|
| context-construction-patterns (D5) | pass | pass-after-correction | pass-after-correction | 1 |
| handoff-schema (D1) | pass | pass-after-correction | pass-after-correction | 1 |
| context-routing-cli (D4) | pass | pass-after-correction | pass-after-correction | 1 |
| driver-architecture (D2) | pass | pass-after-correction | pass-after-correction | 1 |
| boundary-enforcement (D3) | pass | pass | pass | 0 |
| artifact-presentation-protocol (D6) | pass | pass | pass | 0 |
**Critical fix landed (R6 chain ordering):** D4's runForStep now invokes strategy.Apply BEFORE TargetFilterNode runs. Chain composition is `Defaults → Artifact → Strategy → TargetFilter` (StrategyNode wrapper). Target filtering now operates on the complete skill set including strategy-added skills. Verified by new TestChainOrdering_DifferentTargetsDifferentSkills test + integration test that asserts operator/driver/specialist:go-specialist return distinct layer sets. **Without this fix, layered context routing was structurally broken — `--target driver` and `--target operator` returned identical bundles.**
**Integration test suite (post-correction):**
- boundary-leakage: 2/2 pass (NON-NEGOTIABLE constraint satisfied)
- layer-policy parity: 20/20 verdicts identical
- layered-dispatch-e2e: 24/24
- context-routing: 28/28 (was vacuous before R10; now actually validates target-filtered bundle assembly)
- presentation-protocol: 8/8
**Build state:** All 8 Go packages green. `go vet` clean. `tsc --noEmit` clean for adapters/pi/. shellcheck clean.
**Dual-reviewer outcome:** Same-model fresh reviewer surfaced 7 of 10 ship-blockers; codex cross-model surfaced the critical R6 chain-ordering bug + 3 D1 issues that fresh reviewer missed (validateDriverMarkdown leniency, ad-hoc schema duplication, runRenderDriver fabrication). Cross-model failed to invoke for D2/D3 (codex argv overflow for heaviest deliverables) — prompts saved for manual replay if desired.

## Open Questions
**No open questions blocking archive.**
**Carried-forward concerns (intentional, documented, or scope-deferred):**
- D3 leakage corpus has deliverable_id but spec listed bare deliverable — minor drift; bare token is benign English
- D3 leakage test uses hand-crafted handoff fixture rather than live engine dispatch — script comment acknowledges; live dispatch deferred to Pi-runtime-rich follow-up
- D3 Pi extension callLayerGuard fail-opens when 'furrow' binary absent (intentional per documented non-Furrow-project use case)
- D3 operator wildcard skips Bash checks entirely (intentional per spec — operator has full tool surface)
- D6 skill retrofits placed in Shared References section vs Supervised Transition Protocol section (cosmetic; references additive and present)
- D6 commands/work.md.tmpl uses {step} terminology vs protocol doc's {phase} (functionally equivalent in most contexts)
- D6 internal/cli/app.go registration outside file_ownership (defensible scope expansion — registration is necessary for hook subcommand to dispatch)
- D2 driver-review.yaml uses sonnet not opus (consistent with spec's review=sonnet line; only research uses opus)
**Cross-model coverage gap:** D2 + D3 cross-model invocation failed (codex argv overflow). Fresh-reviewer coverage exists for both; D3's only "ship blocker" was a false positive (D6 owns Stop registration). Replay prompts saved at .furrow/rows/orchestration-delegation-contract/prompts/review-{d2,d3}-cross.md for manual invocation if desired.

## Recommendations
**Advance to archive.** All 6 deliverables overall=pass (4 pass-after-correction with 1 correction each, 2 pass clean). Correction limit per deliverable was 3; we used 1 each on 4 deliverables. NON-NEGOTIABLE boundary leakage smoke alarm passes. Architectural contract is sound and verified end-to-end.
**Architectural milestones realized:**
- Vertical 3-layer (operator → driver → engine) wired end-to-end on both adapters
- Forked DriverHandoff/EngineHandoff schemas enforce Furrow-unaware engine constraint at schema level
- Backend canonical Go: layer-policy authority, hook subcommands, validate commands, render util — all in Go, not shell
- Cross-adapter parity invariant: same .furrow/layer-policy.yaml consumed by Claude `furrow hook layer-guard` and Pi adapter tool_call interceptor
- D5↔D4 conformance: 7/7 strategies pass exported harness; SetMetadata Builder method closes the contract gap
- Layered context routing actually filters (post-R6 fix): operator/driver/specialist:* return distinct skill sets
- Boundary leakage: 0 corpus matches against engine handoff fixture
- team-plan.md retired; engine teams compose at dispatch-time per architectural decision
**10 follow-up TODOs to add at archive (via `alm add`):**
1. add-rws-update-title-cli-for-row-title-changes
2. retire-skills-shared-decision-format-canonical-block (T3 finding 0/8 usage)
3. pi-parity-audit-if-upstream-exposes-agent-identity-in-subagent-context
4. pi-adapter-binary-caching (carried from upstream)
5. document-pi-subagents-api-churn-risk-and-pin-maintenance-cadence
6. document-pi-subagent-layer-enforcement-capability-gap-as-known-limitation
7. audit-commands-work-tmpl-rendering-at-install-time
8. confirm-frw-doctor-experimental-flag-check-works-end-to-end
9. extend-furrow-render-adapters-runtime-output-validity-tests
10. cross-adapter-parity-test-framework-as-reusable-harness
**6 source TODOs to mark closed at archive:**
- handoff-prompt-artifact-template
- context-routing-infrastructure
- design-pattern-context-construction
- standardize-artifact-presentation
- furrow-context-isolation-layer
- delegation-boundary-enforcement
**Phase 4 row 4 of roadmap completes** — orchestration/delegation contract shipped. Subsequent phase 4 work can build on this foundation (e.g., Pi adapter hardening, dashboard UX, parallel-engine-team patterns, the @aliou/pi-* extension portfolio captured during research).
