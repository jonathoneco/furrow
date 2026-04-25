# Specs index — pre-write-validation-go-first

Per-deliverable specs in spec.md template format. Each spec contains: Interface Contract, Acceptance Criteria (Refined), Test Scenarios, Implementation Notes, Dependencies.

| Wave | Spec file | Deliverable |
|---|---|---|
| 1 | [blocker-taxonomy-schema.md](blocker-taxonomy-schema.md) | D3 — schema + Go envelope helper |
| 2 | [validate-definition-go.md](validate-definition-go.md) | D1 — Go validator for definition.yaml |
| 3 | [validate-ownership-go.md](validate-ownership-go.md) | D2 — Go validator for file ownership |
| 4 | [pi-validate-definition-handler.md](pi-validate-definition-handler.md) | D4 — Pi tool_call handler + Pi test scaffold |
| 5 | [pi-ownership-warn-handler.md](pi-ownership-warn-handler.md) | D5 — Pi tool_call handler + parity-verification.md scaffold |
| 6 | [claude-ownership-warn-parity.md](claude-ownership-warn-parity.md) | D6 — Claude shell hook + parity-verification.md Claude rows |

## Reading order

For implementation, read top-to-bottom (waves 1 → 6). Each spec's Dependencies section names the prior deliverables required.

## Resolved decisions from spec step

These were the 4 plan-step open questions; spec resolves each:

1. **D3 exact 10 codes + interpolation** — locked in `blocker-taxonomy-schema.md` AC #4 (table) and Implementation Notes (interpolation = `strings.Replace` per `{key}`; missing key → test failure).
2. **D2 canonical-artifact carve-out path list** — expanded in `validate-ownership-go.md` AC #4: state.json, definition.yaml, summary.md, learnings.jsonl, research.md, plan.json, team-plan.md, parity-verification.md, plus any file under `specs/`, `reviews/`, `gates/` subpaths of a row. Non-row canonical paths (e.g., `schemas/`, `docs/`) are NOT carved out — they are always evaluated against ownership.
3. **parity-verification.md exact 3 scenarios** — locked in `pi-ownership-warn-handler.md` and `claude-ownership-warn-parity.md`: in_scope match, out_of_scope, not_applicable (no row). Edge cases (multi-deliverable glob match, focused-row fallback) are covered by D2's unit tests, not by parity verification — parity needs only the cross-runtime UX comparison.
4. **D4 package.json + tsconfig.json minimum** — locked in `pi-validate-definition-handler.md` Interface Contract: bun runtime is zero-config for tests; package.json declares only the `test` script and `type: module`; tsconfig.json declares ES2022 target with bun-types.
