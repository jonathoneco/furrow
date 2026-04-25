# Team Plan: pre-write-validation-go-first

## Scope Analysis

6 deliverables across 6 single-deliverable sequential waves. The harness `file_ownership` validator enforces no overlap within a wave; shared files (app.go between D1/D2, furrow.ts between D4/D5, parity-verification.md between D5/D6) require sequential waves. AD-5's "single-agent serializes" idea worked operationally but couldn't satisfy the static validator — sequential waves are correct.

- Wave 1: D3 (blocker-taxonomy-schema) — must ship first; D1/D2 panic without registered codes.
- Wave 2: D1 (validate-definition-go) — registers `validate` command group + `definition` subcommand in app.go.
- Wave 3: D2 (validate-ownership-go) — extends app.go with the `ownership` subcommand.
- Wave 4: D4 (pi-validate-definition-handler) — bootstraps Pi adapter test scaffold (Q1 confirmed zero infra) + first tool_call handler in furrow.ts.
- Wave 5: D5 (pi-ownership-warn-handler) — extends furrow.ts with second handler + authors parity-verification.md (header + table scaffold + Pi rows).
- Wave 6: D6 (claude-ownership-warn-parity) — updates ownership-warn.sh + appends Claude rows to parity-verification.md.

Same-specialist consecutive waves (go-specialist for waves 2-3, typescript-specialist for waves 4-5) preserve context across the wave boundary without merge friction.

## Team Composition

| Wave | Deliverable | Specialist | Model | Scenario Match |
|------|-------------|-----------|-------|----------------|
| 1 | blocker-taxonomy-schema | harness-engineer | sonnet | "Workflow harness infrastructure — shell scripts, hooks, schemas, validation pipelines" |
| 2 | validate-definition-go | go-specialist | sonnet | "Go idioms, concurrency patterns, interface design, and error propagation" |
| 3 | validate-ownership-go | go-specialist | sonnet | (same as above; consecutive wave preserves agent context) |
| 4 | pi-validate-definition-handler | typescript-specialist | sonnet | "TypeScript type system design, narrowing patterns, module boundaries" |
| 5 | pi-ownership-warn-handler | typescript-specialist | sonnet | (same as above; consecutive wave preserves agent context) |
| 6 | claude-ownership-warn-parity | shell-specialist | sonnet | "Non-harness shell scripting — install scripts, integration tests, command libraries" |

3 distinct specialists; total 6 deliverable assignments. Single go-specialist agent handles both wave-2 deliverables (or two parallel sub-agents if dispatched concurrently). Same pattern for the typescript-specialist's two wave-3 deliverables.

## Architecture Decisions

Grounded in `research.md`. Each decision is traceable to a research finding.

### AD-1 — D3 boundary tightened: row_workflow.go is the real emitter
**Research citation**: research.md §Q4. `internal/cli/row_workflow.go:1005-1084` (`rowBlockers()`) emits 9 hardcoded blocker codes. `internal/cli/row_semantics.go:46-77` is a helper template (`blocker()` constructor + `blockerConfirmationPath()` map) with zero call sites. definition.yaml's D3 boundary now names both files explicitly.

**Trade-off**: precision-in-contract over brevity. The original constraint cited only row_semantics.go (which doesn't actually emit blockers); future readers would have been misled. Amendment is minimal but materially correct.

### AD-2 — Pi test runner: bun test, not vitest
**Research citation**: research.md §Q1 (zero test infra in adapters/pi/) and §Q3 (runFurrowJson uses child-process exec — bun's process model matches the existing pattern with no new deps).

**Trade-off**: minimal-deps + style-match (bun) vs. broader Node ecosystem compatibility (vitest). Rationale: this row's scope is the Pi adapter only; if future work needs broader Node compat, the test runner can be swapped (the test files are runner-agnostic if written against `expect`/`describe`/`it`).

### AD-3 — parity-verification.md: row-local path + tabular-markdown schema
**Research citation**: research.md §Q2 (no prior pattern; row-local path matches the row-self-contained model) and §Q5 (this row sets the precedent).

**Schema (locked here)**:

```markdown
| Scenario | Input path | Input row | D1/D2 verdict | Pi outcome | Claude outcome | Parity OK? | Notes |
|---|---|---|---|---|---|---|---|
| in_scope match | internal/cli/validate_definition.go | pre-write-validation-go-first | in_scope, matched=validate-definition-go, glob=internal/cli/validate_definition.go | silent allow | silent | yes |  |
| out_of_scope | tests/adversarial/foo.go | pre-write-validation-go-first | out_of_scope, code=ownership_outside_scope | confirm prompt fires | log_warning fires | yes | Pi UX is interactive; Claude is non-interactive. Both fire on the same trigger. |
| not_applicable | random/path.txt | (none) | not_applicable, reason=no_active_row | silent allow | silent allow | yes |  |
```

D5 commits the Pi rows; D6 commits the Claude rows. Both contribute via shared file_ownership. Minimum 3 paired scenarios as the existing AC requires.

**Trade-off**: row-local markdown (lightweight, easily reviewed) vs. shared-fixture test runner (DRY, future-proof). Rationale: shared-fixture infra doesn't exist yet (research §Q5); building it would dilute scope. Future row can promote this format.

### AD-4 — Cold-start follow-up stays background
**Research citation**: research.md §Q3 — 45ms median per call, 90ms double-fire. Per-call latency is below the 100ms threshold the ideate Recommendations set for promoting `pi-adapter-binary-caching`. Follow-up todo stays low-priority unless real Pi sessions report perceptible regression.

**Trade-off**: shipping speed (defer) vs. UX polish (cache binary now). Rationale: empirical measurement says current latency is acceptable; the optimization adds a build step that affects all runFurrowJson callers (not just D4/D5) and belongs in its own row.

### AD-5 — Sequential single-deliverable waves where files overlap; same-specialist agent across consecutive waves
**Original framing** (from earlier dual review): single agent serializes two deliverables in one wave to avoid merge friction on shared files. **Validator override**: the harness's plan-artifact validator hard-rejects in-wave file_ownership overlap regardless of specialist assignment — it can't see the single-agent convention. **Resolution**: deliverables that share files are placed in *consecutive single-deliverable waves* (D1 wave 2, D2 wave 3 — both go-specialist, shared app.go; D4 wave 4, D5 wave 5 — both typescript-specialist, shared furrow.ts/furrow.test.ts; D5 wave 5, D6 wave 6 — different specialists, shared parity-verification.md). Same-specialist consecutive waves preserve context across the boundary without violating the validator. **Trade-off**: explicit sequencing (verifiable, validator-friendly) over implicit parallelism (operationally faster but invalidator-blind).

### AD-6 — README footnote on pi-adapter-binary-caching follow-up
**Research citation**: research.md Recommendation #6.

In wave 3, the pi-validate-definition-handler deliverable adds a one-line note in `adapters/pi/README.md` (not in this deliverable's file_ownership currently — see AD-7 below) pointing at the pi-adapter-binary-caching todo so the convention propagates without being implicit.

### AD-7 — adapters/pi/README.md ownership: D4
README is the discoverable surface; AD-6's one-line footnote is worth the 2 lines of inline pointer. `adapters/pi/README.md` is included in D4's file_ownership in both `definition.yaml` and `plan.json`. (Decision applied; no follow-up.)

## Task Assignment

### Wave 1 — blocker-taxonomy-schema (harness-engineer)

1. Design `schemas/blocker-taxonomy.yaml` structure — top-level `version` + `blockers[]` with code/category/severity/message_template/remediation_hint/confirmation_path/applicable_steps fields.
2. Author `schemas/blocker-taxonomy.schema.json` (JSON Schema for the schema, additionalProperties:false at all levels).
3. Populate the 10 initial codes (9 D1 codes + 1 D2 code) — see AD-1 list in research §Q4 for the future taxonomy expansion that this row does NOT do.
4. Implement `internal/cli/blocker_envelope.go`: Go struct mirroring schema, `LoadTaxonomy()` parser, `EmitBlocker(code, interp)` emitter.
5. Author `internal/cli/blocker_envelope_test.go`: every D1/D2 code resolves to a registered entry; unknown code panics in test mode; interpolation works.
6. Add a one-line reference in `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md` under the Blocker baseline section. Do NOT modify any other doc.

### Wave 2a — validate-definition-go (go-specialist)

1. `internal/cli/validate_definition.go` — port `bin/frw.d/scripts/validate-definition.sh` semantics to Go. Use `EmitBlocker()` from D3 for every error path.
2. `internal/cli/validate_definition_test.go` — table-driven tests covering: happy, missing objective, invalid gate_policy, invalid mode, missing/bad-pattern deliverable name, placeholder AC, schema-invalid YAML, unknown top-level keys, empty deliverables.
3. `internal/cli/app.go` — register the `validate` command group + `definition` subcommand.
4. `bin/frw.d/scripts/validate-definition.sh` — rewrite as thin shim that exec-delegates to `furrow validate definition`.

### Wave 2b — validate-ownership-go (go-specialist, parallel with 2a)

1. `internal/cli/validate_ownership.go` — read `definition.yaml.deliverables[].file_ownership` globs; match `--path`; emit verdict (in_scope / out_of_scope / not_applicable). Step-agnostic.
2. `internal/cli/validate_ownership_test.go` — table-driven tests covering: in_scope, out_of_scope, no-focused-row, missing-row, multi-deliverable globs, nested patterns, canonical-artifact carve-out, focused-row fallback.
3. `internal/cli/app.go` — register the `ownership` subcommand under the validate group (shared file with 2a; same agent serializes the two registrations).

### Wave 3a — pi-validate-definition-handler (typescript-specialist; same agent serializes 3a and 3b)

1. Bootstrap `adapters/pi/package.json` (bun test) + `tsconfig.json` + `furrow.test.ts` if absent — confirmed absent per research §Q1.
2. Add `tool_call` handler to `adapters/pi/furrow.ts`: intercept Write/Edit on `*/definition.yaml`; call `runFurrowJson<ValidateDefinitionData>(['validate', 'definition', '--path', filePath])`; on invalid → `{block: true, reason}` + `ctx.ui.notify(message, 'error')`.
3. `furrow.test.ts` — exercise valid/invalid branches against fixture row.
4. Add the AD-6 README footnote: one-line pointer to `pi-adapter-binary-caching` follow-up todo.

### Wave 3b — pi-ownership-warn-handler (typescript-specialist, parallel with 3a)

1. Add `tool_call` handler to `adapters/pi/furrow.ts`: intercept all Write/Edit; call `runFurrowJson<ValidateOwnershipData>([...])`; on out_of_scope → `ctx.ui.confirm(...)` with proceed/block branches; on in_scope/not_applicable → silent allow. Step-agnostic.
2. Extend `furrow.test.ts` — cover in_scope, out_of_scope confirmed, out_of_scope rejected, not_applicable.
3. Author `parity-verification.md` Pi-side rows for ≥3 paired scenarios per AD-3 schema.

### Wave 4 — claude-ownership-warn-parity (shell-specialist; runs after wave 3 so parity-verification.md scaffold exists)

1. Update `bin/frw.d/hooks/ownership-warn.sh` to read `definition.yaml.deliverables[].file_ownership` via `yq`. Drop step gating. Preserve warn-not-block.
2. Graceful no-op on missing/empty definition.yaml or unresolvable row.
3. Shellcheck passes.
4. Author `parity-verification.md` Claude-side rows for the same ≥3 paired scenarios per AD-3 schema.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `app.go` shared between D1 and D2 | Sequential waves 2 and 3; harness validator confirms no in-wave overlap |
| `furrow.ts` and `furrow.test.ts` shared between D4 and D5 | Sequential waves 4 and 5; harness validator confirms no in-wave overlap |
| `parity-verification.md` shared between D5 and D6 across distinct specialists | Sequential waves 5 and 6; D5 authors the file in wave 5, D6 appends Claude rows in wave 6 |
| D3 schema design churn could delay wave 2 | Lock schema fields up front (AD-1 + research §Q4 expansion vocabulary already informs the field set); spec step pins the exact YAML structure before D3 implements |
| Pi test runner choice (bun vs vitest) regret | AD-2 picks bun; if future work demands vitest, swap is mechanical (test files are runner-agnostic with `expect`/`describe`/`it`) |
| Per-write cold-start UX regression | Below 100ms threshold per AD-4; pi-adapter-binary-caching follow-up tracks |

## Coordination

### Wave handoff protocol

After each wave completes, the orchestrator:
1. Verifies the deliverable's acceptance criteria via `rws complete-deliverable <row> <name>` (which runs the artifact validators).
2. Commits the wave's work atomically with a conventional-commit message referencing the deliverable name (e.g., `feat: add furrow validate definition Go command (D1)`).
3. Loads the next wave's specialist agent with: (a) the deliverable's spec from `specs/<name>.md`, (b) the relevant prior-wave artifacts the spec lists in its Dependencies section, (c) file_ownership globs from plan.json.
4. Does NOT pass conversation history across waves — each agent starts fresh with the spec as primary context.

### Per-wave agent prompt template

Each wave's specialist receives:
- **Goal**: Implement the deliverable per spec at `specs/<name>.md`.
- **Reading list**: Spec file (primary); spec's Dependencies section names secondary context (e.g., D2 reads D3's `internal/cli/blocker_envelope.go` to understand `EmitBlocker()`).
- **Constraints**: file_ownership globs from plan.json wave assignment; AC list from definition.yaml + spec refinements.
- **Verification**: each scenario's verification command; the deliverable's acceptance gates the wave transition.
- **Excluded context**: prior-wave conversations (decompose isolates per-wave context); other deliverables' specs (single-deliverable waves don't need them).

### Escalation protocol

- **Spec ambiguity**: agent flags via `// SPEC-CHECK:` comment + escalates to orchestrator. Orchestrator amends spec, re-dispatches.
- **Boundary violation** (e.g., D3 needing to modify row_workflow.go): hard escalation. Orchestrator decides: amend definition.yaml constraint (re-pass plan gate?) or descope.
- **Test failure beyond expected**: agent retries up to correction limit (default 3 per deliverable). At limit, escalates with full diff + failing test output. Orchestrator decides: redirect, amend spec, or human escalation.
- **Cross-wave blocker** (e.g., D2 finds D1's app.go registration is incompatible): hard escalation. Re-open the prior wave; re-spec if needed.

### Vertical slicing check

Each deliverable is independently testable per the spec skill's red-flag check:
- D1: `go test ./internal/cli/ -run TestValidateDefinition*` + integration shim test.
- D2: `go test ./internal/cli/ -run TestValidateOwnership*`.
- D3: `go test ./internal/cli/ -run TestBlockerEnvelope*` + `TestBlockerTaxonomy*`.
- D4: `cd adapters/pi && bun test furrow.test.ts -t "validate definition"`.
- D5: `cd adapters/pi && bun test furrow.test.ts -t "ownership"`.
- D6: `bash bin/frw.d/hooks/ownership-warn.sh < fixture.json` + `shellcheck`.

No deliverable depends on a *behavioral* output of another beyond what its spec lists in Dependencies (typed Go imports, shared CLI subcommand registration). All are testable in isolation given their dependencies.

### Skills injection

`plan.json` `skills: []` for every assignment. Each specialist agent loads:
- The specialist template at `specialists/<specialist>.md` (specialist behavior).
- `skills/implement.md` (current step's skill, loaded by `rws load-step` at wave start).
- The deliverable's spec at `specs/<name>.md` (passed in agent prompt as primary context).

No additional skill injections needed; the specialist template + spec is sufficient context per spec skill's "implementation-ready" gate.

## Open Items for Decompose Step

(All resolved during spec step — see specs/README.md "Resolved decisions" section.)

- ~~D3 schema final field list~~ → locked in `specs/blocker-taxonomy-schema.md`
- ~~D3 11 initial codes' message_templates~~ → locked in `specs/blocker-taxonomy-schema.md` AC #4 table; interpolation rules in Implementation Notes
- ~~D1 validation function signatures~~ → locked in `specs/validate-definition-go.md` (hand-coded validation walking schema's properties/required/additionalProperties)
- ~~D2 canonical-artifact carve-out~~ → expanded in `specs/validate-ownership-go.md` AC #4
- ~~D4 package.json minimum~~ → locked in `specs/pi-validate-definition-handler.md` Interface Contract (bun-zero-config)
- ~~parity-verification.md exact 3 scenarios~~ → locked in `specs/pi-ownership-warn-handler.md` Interface Contract (in_scope, out_of_scope, not_applicable)
