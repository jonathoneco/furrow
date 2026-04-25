# Pre-write validation: Go-first commands + Pi handlers -- Summary

## Task
Two co-equal goals: (1) close the empirical-pain top-2 from research §8 (validate-definition timing, ownership-warn timing) by shipping Go-first pre-write validators consumed by Pi tool_call handlers and the existing Claude shell hook; and (2) lay the canonical schemas/blocker-taxonomy.yaml foundation — bounded to D1/D2-emitted codes only — that future enforcement-parity rows extend by adding codes and migrating other emission sites.

## Current State
Step: review | Status: completed
Deliverables: 6/6
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/pre-write-validation-go-first/definition.yaml
- state.json: .furrow/rows/pre-write-validation-go-first/state.json
- plan.json: .furrow/rows/pre-write-validation-go-first/plan.json
- research.md: .furrow/rows/pre-write-validation-go-first/research.md
- specs/: .furrow/rows/pre-write-validation-go-first/specs/
- team-plan.md: .furrow/rows/pre-write-validation-go-first/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Ideate gate: definition.yaml validates (frw validate-definition pass); 6 deliverables across 2 waves; same-model review (reviews/ideation-same-model.md) APPROVE-WITH-NOTES with 4 findings, all addressed via R1-R4 revisions; cross-model codex review (reviews/ideation-cross.json) framing_quality:sound with 3 new findings addressed via R5-R7; follow-up todo pi-adapter-binary-caching added to almanac; summary.md populated with 5 carry-forward open questions, key findings, and recommendations; user explicitly approved transition
- **research->plan**: pass — Research gate: research.md addresses all 5 ideate Open Questions with primary-source evidence (in-tree file inspection, latency measurements, grep across tests/+git). Key surprise: row_workflow.go is the actual emitter (9 codes), not row_semantics.go — D3 boundary should be tightened in plan. summary.md updated with 5 key findings, 4 plan-step open questions, 6 recommendations. User explicitly approved transition.
- **plan->spec**: pass — Plan gate: plan.json (4 waves, schema-valid), team-plan.md (AD-1..AD-7 grounded in research), definition.yaml amended (D3 boundary cites row_workflow.go, D1 shim continuity test added). Dual review: same-model APPROVE-WITH-NOTES 3+1 findings → all addressed; codex framing_quality:sound, overall:fail on file-ownership static analysis → 2 intentional AD-5 serialization, 1 real conflict resolved via wave split (D6 → wave 4). 4 carry-forward open questions are tactical content-design for spec.
- **plan->spec**: pass — Plan gate (retry after wave restructure): plan.json now 6 single-deliverable sequential waves; resolves harness file_ownership validator rejection of same-wave overlaps. AD-5 reframed: same-specialist consecutive waves replace single-agent-in-one-wave. Same-model + cross-model dual review findings all addressed; reviews recorded in reviews/plan-same-model.md and reviews/plan-cross.json.
- **spec->decompose**: pass — Spec gate: 6 per-deliverable specs at specs/ with Interface Contract + Refined ACs + Test Scenarios + Implementation Notes + Dependencies; specs/README.md indexes set + resolves 4 plan-step open questions. Dual review: same-model APPROVE-WITH-NOTES 3 findings addressed (JSON Schema vendoring → hand-coded; D6 yq malformed-YAML → AC #9; D5/D6 modify-region → AC #10); cross-model codex 2 fail dimensions resolved (D3 11-codes consistency, 6 new test scenarios). Locked: 11 initial blocker codes, hand-coded validation per go.mod, canonical-artifact carve-out paths, parity-verification.md schema.
- **decompose->implement**: pass — Decompose gate: plan.json (6 single-deliverable waves, schema-valid, file_ownership conflict-free) + team-plan.md (Coordination section added covering handoff protocol, per-wave prompt template, escalation paths, vertical-slicing check, skills injection). All open items from earlier steps resolved. Implement step begins with wave 1 (D3 blocker-taxonomy-schema).
- **implement->review**: pass — Implement gate: 6/6 deliverables complete with 0 corrections each; 25 Go unit tests + 7 Pi contract tests + 3 shim integration tests all pass; shellcheck clean; manual verification documented in parity-verification.md and commits. Two mid-implement adaptations recorded in summary Open Questions for review scrutiny: D1 placeholder heuristic tightening (substring → first-token), D6 architecture (shell glob → Go-shell-out delegation for true parity).

## Context Budget
Measurement unavailable

## Key Findings
- All 6 deliverables shipped across 6 sequential waves with 0 in-implement corrections per deliverable. Empirical pain (validate-definition timing, ownership-warn timing per research §8) is closed: D4/D5 surface backend verdict at write time, both Pi and Claude runtimes share Go-validator semantics.
- Cross-model review status: D2, D3, D4, D5, D6 all overall:pass on round-N. D1 went 7 rounds; each surfaced 2-4 more nested schema rules that the hand-coded validator hadn't covered.
- D1 review loop diagnosis: the schema (schemas/definition.schema.json) carries optional/edge-case rules that the project barely uses (per-deliverable gate=0 rows, supersedes=1 row, source_todo singular=10 redundant rows, context_pointers symbols=5 of 44 rows). Each unused optional field is a separate validator branch + a separate finding the reviewer can cite. With a JSON Schema library this would be 5 lines; the no-new-deps constraint exposes the cost.
- Decision: stop chasing individual D1 schema rules. Re-scope the AC to "empirical-pain-prevention" (the rules from research §8) rather than "full schema parity." Defer full schema enforcement to a sweeping schema audit (almanac todo sweeping-schema-audit-and-shrink) that addresses root cause (schema breadth) by removing dead/under-used fields rather than chasing individual nested rules.
- Test surface: 37 Go cli tests, 37 Pi adapter tests, 5 D6 shell integration cases, 3 D1 shim continuity cases, all pass. Shellcheck clean across new shell artifacts. Gofmt clean across all touched Go files.
- Architectural shifts captured in spec amendments + commit bodies (not redirects): D6 yq → Go-shell-out (true parity over shell-glob approximation), D2 dispatcher extraction to validate.go (joint D1+D2 ownership), D5 prompt text + return shape match.
- 3 reusable learnings recorded in learnings.jsonl: schema-breadth-IS-validator-size, spec-amendment-vs-redirect for mid-implement architectural shifts, cross-model review diff_scope misattribution on multi-deliverable fix commits.

## Open Questions
- D1 cross-model verdict will remain "fail" on the strict "full schema validation" interpretation; user has accepted this with the understanding that the sweeping-schema-audit-and-shrink follow-up addresses root cause. Document this explicitly in archive evidence.
- Should this row's archive ceremony surface the 5/6 cross-model passes as the relevant signal (rather than blocking on D1's last-mile review fail)? Lean: yes, with explicit rationale.

## Recommendations
- Approve archive. Empirical-pain top-2 closed; 5/6 deliverables review-pass; D1 remaining gap is documented and assigned to the sweeping-schema-audit-and-shrink follow-up todo.
- After archive: pi-adapter-binary-caching todo stays in almanac for a future row when real Pi sessions report perceptible cold-start regression. sweeping-schema-audit-and-shrink should be triaged against the broader migration roadmap.
- Promote the 3 review-step learnings to the project's promoted-learnings collection during archive: (a) schema-breadth-IS-validator-size, (b) spec-amendment-vs-redirect for mid-implement design shifts, (c) cross-model diff_scope tooling limitation on multi-deliverable fix commits.
- Future rows that ship hand-coded validators against existing JSON Schemas should adopt the "scope to empirical-pain-prevention" framing in the AC text from the start, not retroactively after a 7-round review loop.
