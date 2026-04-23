# Team Plan — agent-host-portability-research

**Row**: `agent-host-portability-research`
**Step**: plan (artifact)
**Purpose**: Specialist briefings per deliverable. Works with `plan.json` (wave ordering + file ownership) to fully specify implementation delegation.

## Shared context for all specialists

Every specialist working this row must have read:
- `docs/research/pi-migration-gap-analysis.md` (Wave 1 output — the rolled-up research context)
- `docs/architecture/pi-adapter-interface.md` (Wave 2 output — the contract being implemented)
- `definition.yaml` (the 6-deliverable contract)

Every specialist must respect:
- **Dual-host parity**: any host-independent improvement must apply to CC + Pi; Pi-only capabilities require CC shim or upstream-ask path documented in the gap-analysis
- **CC stays functional throughout**: breaking CC at any step is blocker-grade failure
- `file_ownership` boundaries from `plan.json` — writes outside boundary trigger `ownership-warn`
- CLI-mediation: state mutation via `rws`/`alm` only, never direct file edits

---

## Wave 1 — `pi-migration-gap-analysis`

**Specialist**: `systems-architect`

**Briefing**: Consolidate R1 (Furrow surface inventory), R2 (Pi deep-dive), R8 (Pi ecosystem), R9 (Pi technical), R10 (ecosystem learn-from) into a single decision-bearing document. Not a re-write of the research — a synthesis that the interface deliverable builds on.

**Output**: `docs/research/pi-migration-gap-analysis.md`

**Must deliver**:
- Per-surface gap table (Furrow's CC host surface → concrete Pi primitive → gap assessment)
- Eliminated-candidate footnotes (≤1 line each) for Agent SDK, goose, opencode, CC+routing
- Ecosystem composition matrix (every candidate extension: compose / supersede / ignore / monitor)
- Host-parity column — for every improvement, mark host-independent or Pi-only with CC shim path
- Deferred-items cross-reference (the 9 almanac TODOs tracking behavior-level improvements)

**Reasoning emphasis**: identify trade-offs, not prescribe solutions. Each gap row should note alternative bindings considered and the criterion used to pick one.

---

## Wave 2 — `pi-adapter-interface`

**Specialist**: `systems-architect`

**Briefing**: Produce the portable Host Adapter Interface as prose + JSON Schema (per P4 plan). 8 surfaces per P2-1 (commands, hooks, subagents, context-injection, tool-metadata, programmatic, install, compaction). Fresh draft — do not reconcile with vestigial `adapters/` tree (per P-2 staged decision).

**Outputs**:
- `docs/architecture/pi-adapter-interface.md` (prose)
- `schemas/host-adapter-interface.schema.json` (machine-verifiable)

**Must deliver**:
- Pi binding + CC binding per surface, so dual-host is explicit not implicit
- Every CC-coupled file from `.furrow/almanac/rationale.yaml` maps to exactly one surface. Unmapped entries get flagged for deletion.
- Core-preferred with host-override pattern (per P-1) — compaction is the first concrete override example
- Schema is the source of truth; prose explains it

**Reasoning emphasis**: component boundaries, dependency direction, override-point governance. A surface is well-designed if it's easy to audit parity across hosts.

---

## Wave 3 — `harness-schema-upgrades` (TWO-PHASE DELIVERABLE)

Per Plan P4-3(c), this deliverable has two sequential specialist phases within one deliverable. Handoff is explicit, documented in the output.

### Phase A — Schema design sign-off
**Specialist**: `systems-architect`

**Briefing**: Design the JSON Schemas that the harness-schema-upgrades deliverable implements. The design must be reviewed and signed off before Phase B begins.

**Phase A outputs**:
- `schemas/alm-rationale.schema.json`
- `schemas/alm-roadmap.schema.json`
- `schemas/alm-todos.schema.json`
- `schemas/alm-seeds.schema.json` (if feasible — optional)
- `schemas/specialist-frontmatter.schema.json`
- Definition.yaml schema extension for `produces:` (per P3-3 option c — map with structured values)

**Must deliver**:
- Schema additions compatible with existing schemas (no breaking change to definition.yaml structure)
- Migration strategy documented per P3-2(c): one-shot normalization, then strict
- Specialist frontmatter schema per P3-6(c): `dispatch:` required, `consumes:`/`produces:` optional

**Handoff**: write `docs/architecture/harness-schema-design-signoff.md` summarizing decisions and explicitly signing off Phase A → Phase B.

### Phase B — Implementation, migration, specialist backfill
**Specialist**: `harness-engineer`

**Briefing**: Wire Phase A's schemas into the harness. Run one-shot migrations to bring existing data into conformance. Backfill all 22 existing specialists.

**Phase B outputs**:
- Schema validation wired into `bin/alm` at write-time AND load-time (per P3-1(c) defense-in-depth)
- Schema validation wired into `bin/rws` for `produces:` (new field)
- `alm specialists validate` subcommand (per P3-8)
- One-shot normalization pass cleaning existing almanac drift (9 entries with `open_questions`, any others)
- All 22 specialist frontmatter migrated: script-generated `dispatch:` defaults with human-review pass (per P3-7(c))

**Must deliver**:
- `alm validate` passes post-migration
- All 22 specialists parse, validate, dispatch on both CC + Pi
- Breaking-change notes for `definition.yaml` `produces:` consumers (none exist yet, so just document)

**Scope discipline**: `specialists/**` access is FRONTMATTER-ONLY. Do not touch specialist body content — that's out of scope (per P4-4 constraint).

**Reasoning emphasis**: migration safety, backward-compat where the schema allows it, fail-loud where it doesn't. The row is blocked if CC host breaks during migration.

**Scope watch (from plan review)**: this wave bundles 5 large concerns (schema authoring, almanac migration, `produces:` extension, specialist frontmatter contract, 22-specialist backfill). Any one could be its own row. Watch for scope bleed during execution; re-split if genuinely independent sub-waves emerge.

---

## Wave 4 — `pi-adapter`

**Specialist**: `harness-engineer`

**Briefing**: Implement the working Pi adapter at `adapters/pi/` per the interface from Wave 2 and schemas from Wave 3. TypeScript event handling, shell-CLI state mutation (per P2-7). One extension, internal module tree (per P2-2).

**Outputs**:
- `adapters/pi/src/index.ts` (extension entry point)
- `adapters/pi/src/commands/` (slash command registration)
- `adapters/pi/src/hooks/` (lifecycle event handlers)
- `adapters/pi/src/subagents/` (pi-subagents wrapping layer)
- `adapters/pi/src/compaction/` (session_before_compact handler)
- `bin/frw.d/hooks/pi-*.sh` (shell bridges for state mutation)

**Must deliver**:
- state-guard / correction-limit / ownership-warn via `pi.on("tool_call", ...)` with `{ block: true, reason }` — supersedes pi-permission-system
- Subagent dispatch via `@tintinweb/pi-subagents` with config per P2-3(c) specialist-as-data — reads `dispatch:` frontmatter from specialist markdown
- `session_before_compact` handler (Pi-native, strictly stronger than CC's post-compact)
- Cross-model review path: `pi -p --no-session --no-extensions --no-skills --no-context-files`
- T4 evidence: one-line experiment confirming hooks fire in `pi --mode rpc` before cross-model is committed
- Exact Pi version pin in install script; no `pi.dev/packages` dependency; preflight `pi --version`; graceful extension-install failure (per R9)
- `/furrow:work` ideate + research steps run end-to-end on Pi

**Reasoning emphasis**: composability with pi-subagents and optional ecosystem extensions; minimal footprint; each surface independently testable.

**Specialist consultation (from plan review)**: harness-engineer owns the deliverable, but `adapters/pi/src/**` is TypeScript work and harness-engineer's stated domain is shell + hook infrastructure. Consult `typescript-specialist` for non-trivial TS design decisions (type architecture, module boundaries, async patterns). `bin/frw.d/hooks/pi-*.sh` shell bridges stay harness-engineer's native domain.

---

## Wave 5 — `pi-ecosystem-integration`

**Specialist**: `harness-engineer`

**Briefing**: Compose upstream Pi + `@tintinweb/pi-subagents` into a reproducible install. Document rejected integrations (MCP, memory, pi-permission-system) and anti-patterns (non-blocking cycles, auto-cascade).

**Outputs**:
- `adapters/pi/ecosystem/` (install recipe, optional-extension wrapper where relevant)
- `docs/architecture/pi-ecosystem-integration.md` (prose doc)

**Must deliver**:
- Fresh-machine install recipe verified reproducible (upstream Pi → Furrow adapter → pi-subagents)
- `install.sh --host pi` as global install (per P2-4 divergence) — matches Pi's preferred install model
- Optional enhancements documented (pi-sandbox, pi-rewind, pi-tool-display) with integration notes
- Deferred-to-follow-ups section listing the 9 almanac TODOs and citing each ID
- Anti-patterns documented: non-blocking cycle warnings, auto-cascade subagents

**Reasoning emphasis**: keep ecosystem surface honest. Every composition has a reversibility story.

---

## Wave 6 — `dual-host-migration-validation`

**Specialist**: `harness-engineer`

**Briefing**: Prove the dual-host end state. Full-cycle row on Pi with no CC side effects; same row on CC unchanged; host-switch mechanism works; context-overhead measured per host.

**Outputs**:
- `docs/architecture/dual-host-validation.md`
- `bin/frw.d/scripts/host-switch.sh`

**Must deliver**:
- Full-cycle throwaway row (ideate → archive) on Pi — evidence captured
- Same cycle on CC, zero regression — evidence captured
- Every host-independent improvement (schema upgrades, typed `produces:`, specialist contract) verified on BOTH hosts with evidence
- Pi-only capabilities (session_before_compact, tool_call input mutation) — CC shim paths verified
- `host-switch.sh` switches default host with rollback tested
- `frw measure-context` reports per-host overhead numbers — verifies the Anthropic-quota-escape motivation quantitatively
- RPC-mode hook-firing T4 evidence recorded

**Reasoning emphasis**: evidence-based validation, not assertions. Every AC has a shell command or log excerpt.

---

## Cross-wave dependencies

- Wave 2 cannot start until Wave 1's gap-analysis is reviewed
- Wave 3 Phase A cannot start until Wave 2's interface is reviewed
- Wave 3 Phase B cannot start until Phase A signoff document is reviewed
- Wave 4 cannot start until Wave 3 migration completes (schemas enforced)
- Wave 5 cannot start until Wave 4's adapter passes `frw doctor --host pi`
- Wave 6 cannot start until both Wave 4 and Wave 5 are complete

All transitions go through `rws transition` with evidence recorded in gate.
