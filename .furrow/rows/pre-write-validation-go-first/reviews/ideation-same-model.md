# Same-model ideation review (sonnet, fresh context subagent)

Verdict: APPROVE-WITH-NOTES

## Findings

1. **D3 framing — scope creep, but defensible.** Research §9 listed 4 deliverables; D3 was added because D1/D2's panic-on-unregistered-code invariant requires the taxonomy to exist. D3 is a hard prerequisite the research undercounted. Objective should acknowledge taxonomy-foundation as co-equal to validation-fix.

2. **D6 parity claim is overstated.** Constraint claimed "identical step-agnostic warn-with-confirm semantics" but D6's AC said `log_warning` only — that is warn-only, not warn-with-confirm. Claude shell hooks are non-interactive at write time. Honest framing: Pi confirms (interactive UX); Claude logs (non-interactive). Both are step-agnostic, both fire on the same trigger conditions, neither blocks. UX divergence is host-capability-driven and intrinsic.

3. **Feasibility gap: D4/D5 testing infrastructure.** `ls adapters/pi/` shows only `furrow.ts`, `_meta.yaml`, `README.md` — no test runner, no `package.json`, no `*.test.ts`. D4/D5 acceptance presumed infrastructure that doesn't exist. Hidden dependency.

4. **Risk not acknowledged: runFurrowJson cold-start latency.** `adapters/pi/furrow.ts:322` does `go run ./cmd/furrow` per call. D4+D5 double-fire on every Write/Edit. Per-tool-call latency could regress UX measurably.

## Resolution applied

- R1: objective rewrite to name taxonomy foundation co-equal goal
- R2: D6 acceptance + parity constraint reworded to honest UX divergence framing
- R3: Pi test scaffolding folded into D4 (file_ownership adds package.json + tsconfig.json)
- R4: cold-start latency acknowledged in constraint; follow-up todo `pi-adapter-binary-caching` added to almanac
