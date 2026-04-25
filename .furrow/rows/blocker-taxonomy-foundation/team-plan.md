# Team Plan — `blocker-taxonomy-foundation`

## Wave 1 (parallel)

### `canonical-blocker-taxonomy` — migration-strategist

Expand-contract migration discipline: extend the canonical taxonomy registry, evolve the producer-side `BlockerEnvelope` shape across Go callers, and update the Pi render so adapters consume the new shape — all without breaking the 11 backward-compat codes. Multi-language scope (YAML + Go × 4 files + TS × 1 file) handled as a single coherent migration.

**Tasks**:
1. Extend `schemas/blocker-taxonomy.yaml` to ≥21 codes (11 from hook-emit + ~10 from Go-side enforcement) per `research/hook-audit.md`.
2. Update `schemas/blocker-taxonomy.schema.json` if any new top-level fields are introduced (e.g., `applicable_steps` is already supported per existing schema).
3. Update `internal/cli/blocker_envelope.go` `LoadTaxonomy` to validate the extended file; update `_test.go` golden cases.
4. Migrate `blocker(...)` constructor at `internal/cli/row_semantics.go:46-58` to emit canonical `BlockerEnvelope` shape (severity enum, confirmation_path enum, remediation_hint required, no arbitrary keys). Update callers in `row_workflow.go:1005-1085` and `row.go:603-663`. **Audit transition output sites** (`runRowTransition`, `runRowStatus`, any sibling JSON-emitting commands in `internal/cli/`) for free-text blocker emissions and migrate them to canonical envelope shape. AC at definition.yaml:19 covers status AND sibling status/transition outputs.
5. Update Pi render at `adapters/pi/furrow.ts:395-402` — small enum→prose mapping sourced from the new `remediation_hint` field. Pi may decorate the rendered string but does not maintain its own enum→prose dictionary.
6. Update "Blocker baseline" section in `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md` to cite `schemas/blocker-taxonomy.yaml` as canonical, removing prose duplicating registry content.

**Constraints recap**: adapter-agnostic (no Claude/Pi fields in taxonomy); backward-compat 11 codes; canonical envelope on `furrow row status`.

**Hand-off to wave 2**: `Taxonomy` and `BlockerEnvelope` types must compile; `LoadTaxonomy` must pass against the new file; canonical envelope shape ratified.

### `doc-contradiction-reconciliation` — documentation-generator:technical-writer

Three reconciliation notes + meta-pattern update. No code dependency. Runs in parallel with D1.

**Tasks**:
1. **Contradiction (1)**: amend `docs/architecture/pi-almanac-operating-model.md` (around lines 148-159) with explicit transitional rule: TODOs remain authoritative until Phase 5 cutover; rows must read TODOs and may consult seeds, never the inverse. Use the verbatim passages from `research/test-infra-and-contradiction-passages.md` Section D.
2. **Contradiction (2)**: amend `docs/architecture/migration-stance.md` (around lines 86-89) noting the split is closed by deliverables D1+D2+D3+D4 of this row, citing `tests/integration/test-blocker-parity.sh` as the durable anti-drift mechanism. **Known forward citation**: this path does not exist until W4 lands; the row commit history makes it valid by row-completion. Document the forward reference inline so a reader doesn't chase a missing file mid-row.
3. **Contradiction (3)**: amend `docs/architecture/go-cli-contract.md` at the **corrected** line range **392-399** (NOT 385-388 as the source TODO incorrectly cited) with explicit deferral note dated 2026-04-25, naming TODO `artifact-validation-per-step-schema` as the closing work.
4. **Meta-pattern**: contradictions (1) and (3) share an anti-pattern (target/implementation doc states broader scope than contract doc with no precedence rule). Add a small canonical-class note to `docs/architecture/documentation-authority-taxonomy.md` documenting this anti-pattern with explicit precedence rule (contract docs win when scope language conflicts).

**Constraint**: scoped doc edits only; no opportunistic cleanup of unrelated drift.

## Wave 2

### `normalized-blocker-event-and-go-emission-path` — go-specialist

Establish the host-agnostic event contract and the Go emission path that adapters invoke.

**Tasks**:
1. Define `schemas/blocker-event.yaml` with `version: "1"`, plus `event_types[]` declaring per-type payload contracts (event_type, target_path, step, row, payload).
2. Define `schemas/blocker-event.schema.json` for validation.
3. Add Go entry point — design choice: `furrow guard <event-type>` reading normalized event JSON on stdin, emitting canonical `BlockerEnvelope` JSON on stdout (or empty + exit 0 if no condition triggers). Wire into `cmd/furrow/main.go`.
4. Add table-driven tests in `internal/cli/` covering at least one code per blocker category.
5. Land `bin/frw.d/lib/blocker_emit.sh` — shared shell helper that hooks source. Helpers: `emit_canonical_blocker(event_type, target_path)` (calls `furrow guard ...` via subprocess and forwards JSON stdout), `parse_tool_input_path()`, `parse_tool_input_command()`, `precommit_init()`. **D2 lands these first; D3 sources them.**

**Hand-off to wave 3**: `furrow guard` accepts every emit-bearing event type from the hook audit; `bin/frw.d/lib/blocker_emit.sh` exports the four helpers; subprocess invocation pattern documented in a header comment.

## Wave 3

### `hook-migration-and-quality-audit` — shell-specialist

Reduce 10 emit-bearing hooks to ≤30-line shims; delete 1 dead hook; record audit findings.

**Sequenced tasks**:
1. **Delete `bin/frw.d/hooks/gate-check.sh`** (dead code — body is `return 0`). Update any harness references.
2. **Migrate 5 mechanical hooks** (≤30 min each per audit): `state-guard.sh`, `verdict-guard.sh`, `pre-commit-bakfiles.sh`, `pre-commit-script-modes.sh`, `pre-commit-typechange.sh`. Each becomes: `parse_tool_input_path()` → `emit_canonical_blocker(<event-type>, <path>)` → exit code translation.
3. **Migrate 5 non-trivial hooks**: `correction-limit.sh`, `script-guard.sh` (heaviest — port the 100-line awk parser to Go), `stop-ideation.sh`, `validate-summary.sh`, `work-check.sh`. Logic moves into Go; shell shim becomes thin.
4. **Quality audit findings**: write **row-local** `research/hook-audit-final.md` (decision per `research/synthesis.md` — audit value is row-scoped, not enduring canonical reference) with per-hook before/after line counts, helpers extracted, and any deferral rationale. Definition.yaml D3 AC accepts the row-local form.
5. **Deferral candidates** with concrete thresholds: `script-guard.sh` Go port — defer if >4h; `work-check.sh` `updated_at` timestamp side-effect split — defer if >2h. Default: migrate both. Deferral, if triggered, lands a named follow-up TODO **before W4 starts** so D4's parity-test surface is stable (no late churn).

**Constraint reminder**: ≤30-line shims; no domain logic in shell; no conditional emission of free-form text.

## Wave 4

### `coverage-and-parity-tests` — test-engineer

Two integration tests + per-code fixtures. Auto-discovered by `tests/integration/run-all.sh`.

**Tasks**:
1. **Fixture authoring**: for every code in `schemas/blocker-taxonomy.yaml`, create `tests/integration/fixtures/blocker-events/<code>/{normalized.json, claude.json, pi.json, expected-envelope.json}`.
2. **`tests/integration/test-blocker-coverage.sh`**: walks taxonomy; for each code, feeds `normalized.json` to `furrow guard` via subprocess and asserts the canonical envelope matches `expected-envelope.json` using `assert_json_field` from `helpers.sh`.
3. **`tests/integration/test-blocker-parity.sh`**: for each migrated code, feeds `claude.json` through the Claude hook shim (with `bin/frw.d/hooks/<hook>.sh`) AND `pi.json` through the existing Pi adapter factoring (`adapters/pi/validate-actions.ts` Node test driver invoking the same `furrow guard` subprocess), asserts both produce identical canonical envelopes.
4. **Anti-cheat assertion**: parity test independently asserts each migrated hook calls `furrow guard` via subprocess (e.g., `grep` for `furrow guard` in the shim source, or intercept with a wrapper in the test sandbox).
5. **Emit-site inventory gate**: parity test enumerates every shim under `bin/frw.d/hooks/` and fails when any shim lacks a `{claude.json, pi.json, expected-envelope.json}` fixture set. Shim-level inventory complements code-level coverage.
6. **Deferred-code skipping**: codes that map to deferred-migration hooks (per W3 fallback threshold) are explicitly skipped with logged reason.

**Pi-side test driver**: a small Node script under `adapters/pi/` that imports the existing `validate-actions.ts` factoring, replays Pi-shape `tool_call` fixtures, and writes envelopes for the bash test to diff. **No new Pi shim authored.**

**Constraint reminder**: Pi runtime not required (fixture-driven). Live-Pi invocation is `pi-tool-call-canonical-schema-and-surface-audit` follow-up TODO.

## Specialist conflict map

| Wave | File-glob overlap | Resolution |
|------|-------------------|------------|
| 1 (D1+D5) | `docs/architecture/**` (D1 owns `pi-step-ceremony-and-artifact-enforcement.md`; D5 owns the other four) | Disjoint by file name — no conflict. |
| 1→2 (D1 then D2 on `internal/cli/**`) | D1 edits `row_semantics.go`, `row_workflow.go`, `row.go`, `blocker_envelope.go`, `blocker_envelope_test.go`. D2 adds `guard.go` + sibling files (`shellparse.go`, `correction_limit.go`, `work_check.go` per shared-contracts §C6). | Sequential by wave dependency; D2 only adds new files in `internal/cli/`, does not edit D1's targets. |
| 2→3 (D2 then D3 on `bin/frw.d/lib/**`) | D2 lands `blocker_emit.sh` per shared-contracts §C4 (4 named exports with locked signatures); D3 sources it. | Sequential by wave dependency; D3 may add new helpers in `bin/frw.d/lib/` if shared by ≥2 shims, but cannot modify D2's exported signatures. |
| 4 (D4 on `adapters/pi/**`) | D4 adds Node test driver under `adapters/pi/` | D4 only adds new files; does not modify D1's edit at `furrow.ts:395-402`. |

## Implement-time coordination notes (decompose-step additions)

- **Shared-contracts canonicality**: implement agents read `specs/shared-contracts.md` first, then their per-deliverable spec. On any conflict, shared-contracts wins (rule C9).
- **C1 catalog parity check**: the 10 event-type names in `specs/shared-contracts.md` table must match verbatim across `schemas/blocker-event.yaml` (D2), `bin/frw.d/hooks/*.sh` invocations (D3), and `tests/integration/fixtures/blocker-events/<code>/` references (D4). Treat any drift as a structural failure.
- **C2 CLI contract**: agents may NOT introduce a `--json` flag on `furrow guard`, NOT emit a bare object on stdout, NOT exit 2 from the Go binary. These are recurring temptations during implement; the test harness asserts each.
- **C5 ≤30-line shim discipline** (D3): the line-count test is mechanical; agents should run it locally during migration, not wait for D4.
- **C7 Pi skip rule** (D4): for codes whose Pi handler doesn't exist in `validate-actions.ts`, parity test logs skip with TODO reference. Implement must wire this skip explicitly.
- **W3 fallback thresholds** (script-guard.sh >4h, work-check.sh updated_at split >2h): if triggered, deferral TODO lands in `.furrow/almanac/todos.yaml` via `alm todo add` BEFORE D4 starts (per CLI-mediation rule).
