# Phase 4 Merge Map: blocker-taxonomy-foundation + orchestration-delegation-contract

**Date:** 2026-04-27  
**Branches:** `origin/work/blocker-taxonomy-foundation` (268 files, +18148/-817) + `origin/work/orchestration-delegation-contract` (151 files, +27510/-653)  
**Overlap:** 4 files (all classified below)

---

## Per-File Zone Classification

### Summary Statistics
- **CLEAN** (single-side, take as-is): 415 files
  - blocker-taxonomy-foundation only: 264 files
  - orchestration-delegation-contract only: 147 files
- **TRIVIAL_UNION** (disjoint additions, auto-mergeable): 2 files
  - `.claude/settings.json`: Hook removal (blocker) + hook additions (orchestration) don't collide
  - `schemas/blocker-taxonomy.yaml`: 16 blocker codes (blocker) + 9 codes (orchestration) with zero name overlap
- **SEMANTIC_CONFLICT** (overlapping semantics, decision required): 2 files
  - `.furrow/almanac/todos.yaml`: Identical TODO in both branches + different source rows mark different todos as done
  - `internal/cli/app.go`: stdin field added by both; struct signature conflict on NewWithStdin; CLI architecture divergence (guard as top-level vs hook subcommand)

---

### CLEAN Files (Representative Sample)

**blocker-taxonomy-foundation only (264 files):**

- `.furrow/rows/blocker-taxonomy-foundation/` (new row, all contents): definition.yaml, state.json, plan.json, research/*.md, specs/*.md, reviews/*.json, learnings.jsonl, team-plan.md, summary.md
- `bin/frw.d/hooks/correction-limit.sh` (+100 lines): New hook for correction-limit enforcement
- `bin/frw.d/hooks/script-guard.sh` (+210 lines): Canonical Go-routed shim
- `bin/frw.d/lib/blocker_emit.sh` (+216 lines): New library for blocker event emission
- `bin/frw.d/lib/precommit_payloads.sh` (+135 lines): New payload factory
- `bin/frw.d/lib/stop_payloads.sh` (+262 lines): New payload factory
- `internal/cli/blocker_envelope.go` (updated -98 lines): Canonical envelope struct with 6-field shape
- `internal/cli/blocker_envelope_test.go` (new, +235 lines): Comprehensive envelope + backward-compat tests
- `internal/cli/correction_limit.go` (new, +204 lines): Correction-limit tracking
- `internal/cli/guard.go` (new, +309 lines): Blocker envelope emission logic
- `internal/cli/guard_test.go` (new, +554 lines): Guard tests
- `internal/cli/precommit.go` (new, +151 lines): Pre-commit shim coordinator
- `internal/cli/shellparse.go` (new, +258 lines): Shell script parsing for hook shims
- `internal/cli/stop_ideation.go` (new, +116 lines): Stop-step ideation guard
- `internal/cli/validate_summary.go` (new, +150 lines): Summary validation
- `internal/cli/work_check.go` (new, +90 lines): Work-step guard
- `schemas/blocker-event.schema.json` (new, +47 lines): Normalized blocker event schema
- `schemas/blocker-event.yaml` (new, +115 lines): Event structure definition
- `docs/architecture/documentation-authority-taxonomy.md` (new, +23 lines): Doc authority framework
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md` (+43 lines): Updated with blocker baseline section
- `tests/integration/test-blocker-coverage.sh` (new, +236 lines): Comprehensive blocker coverage
- `tests/integration/test-blocker-parity.sh` (new, +301 lines): Cross-adapter parity tests
- `tests/integration/fixtures/blocker-events/` (~60+ fixture sets): Test data for all blocker codes
- `.furrow/almanac/learnings/blocker-taxonomy-foundation.jsonl` (+4 lines): Captured learnings

**orchestration-delegation-contract only (147 files):**

- `.furrow/rows/orchestration-delegation-contract/` (new row): definition.yaml, state.json, plan.json, research/*.md, specs/*.md, reviews/*.json
- `.furrow/rows/context-routing-test-fixture/` (test fixture row): definition.yaml, state.json, summary.md
- `.furrow/drivers/driver-*.yaml` (7 files): ideate, research, plan, spec, decompose, implement, review
- `.claude/agents/driver-*.md` (7 files): Agent skills for each driver
- `.furrow/layer-policy.yaml` (new, +78 lines): Layer authority policy
- `internal/cli/context/` (6 Go packages, ~2000 lines): Context routing implementation
  - `builder.go` (+125 lines): Bundle builder
  - `builder_test.go` (+33 lines): Builder tests
  - `chain.go` (+269 lines): Context chain assembly
  - `chain_test.go` (+211 lines): Chain tests
  - `cmd.go` (new, +304 lines): Context CLI dispatcher
  - `contracts.go` (+532 lines): Context contracts (interfaces)
  - `contracts_test.go` (+168 lines): Contract tests
  - `registry.go` (+53 lines): Strategy registry
  - `source.go` (+367 lines): Context source loaders
  - `strategies/decompose.go` et al. (7 strategy files, ~600 lines): Per-step strategies
  - `strategies_test.go` (+422 lines): Strategy tests
  - `structure_test.go` (+232 lines): Structure tests
- `internal/cli/handoff/` (6 Go files, ~2500 lines): Handoff render/validate
- `internal/cli/hook/` (4 Go files, ~900 lines): Hook implementations (layer-guard, presentation-check)
- `internal/cli/layer/` (2 Go files, ~450 lines): Layer policy enforcement
- `internal/cli/render/` (2 Go files, ~570 lines): Runtime-specific rendering
- `schemas/context-bundle.schema.json` (new, +149 lines): Context bundle schema
- `schemas/driver-definition.schema.json` (new, +33 lines): Driver definition schema
- `schemas/handoff-driver.schema.json` (new, +46 lines): Driver handoff schema
- `schemas/handoff-engine.schema.json` (new, +91 lines): Engine handoff schema
- `schemas/layer-policy.schema.json` (new, +71 lines): Layer policy schema
- `skills/shared/layer-protocol.md` (new, +146 lines): Layer protocol documentation
- `skills/shared/specialist-delegation.md` (+142 lines): Updated with delegation patterns
- `templates/handoff-driver.md.tmpl` (new, +27 lines): Driver handoff template
- `templates/handoff-engine.md.tmpl` (new, +42 lines): Engine handoff template
- `tests/integration/test-boundary-leakage.sh` (new, +169 lines): Boundary enforcement tests
- `tests/integration/test-context-routing.sh` (new, +372 lines): Context routing tests
- `tests/integration/test-driver-architecture.sh` (new, +256 lines): Driver architecture tests
- `tests/integration/test-layer-policy-parity.sh` (new, +125 lines): Layer policy tests
- `tests/integration/test-layered-dispatch-e2e.sh` (new, +171 lines): End-to-end dispatch tests
- `tests/integration/test-presentation-protocol.sh` (new, +211 lines): Presentation protocol tests
- `adapters/pi/extension/index.ts` (new, +360 lines): Pi subagent extension
- `commands/work.md.tmpl` (new, +149 lines): Runtime-templated work command
- `go.mod`: Updated Go module version
- `install.sh` (+45 lines): Updated installation script
- `docs/architecture/context-construction-patterns.md` (new, +203 lines): Architecture docs
- `docs/architecture/orchestration-delegation-contract.md` (new, +261 lines): Architecture docs

---

## Trivial Union Files (Auto-Mergeable)

### 1. `.claude/settings.json` — TRIVIAL_UNION

**blocker-taxonomy-foundation:**
```json
PreToolUse (Bash): [
  - { "type": "command", "command": "frw hook gate-check" }  // REMOVED (gate-check.sh deleted)
  { "type": "command", "command": "frw hook script-guard" }   // KEPT
]
```

**orchestration-delegation-contract:**
```json
PreToolUse (Write): [
  { "type": "command", "command": "frw hook append-learning" }
  { "type": "command", "command": "furrow hook layer-guard" }  // NEW
]
PreToolUse (Bash): [
  { "type": "command", "command": "frw hook gate-check" }
  { "type": "command", "command": "frw hook script-guard" }
  { "type": "command", "command": "furrow hook layer-guard" }  // NEW
]
SendMessage|Agent|TaskCreate|TaskUpdate (NEW matcher): [
  { "type": "command", "command": "furrow hook layer-guard" }  // NEW
]
Stop (Bash): [
  { "type": "command", "command": "frw hook validate-summary" }
  { "type": "command", "command": "furrow hook presentation-check" }  // NEW (D6)
]
```

**Merge resolution:** 
- Remove `gate-check` entry (per blocker-taxonomy-foundation's deletion of gate-check.sh)
- Add `furrow hook layer-guard` to Write, Bash, and SendMessage matchers (per orchestration)
- Add `furrow hook presentation-check` to Stop/Bash matcher (per orchestration D6)
- No conflicts; disjoint additions and deletions

---

### 2. `schemas/blocker-taxonomy.yaml` — TRIVIAL_UNION

**blocker-taxonomy-foundation adds 16 codes (research/hook-audit.md §3):**

Blocker categories (state-mutation, gate, scaffold, ideation, summary):
- `state_json_direct_write`, `verdict_direct_write`, `correction_limit_reached` (state-mutation)
- `script_guard_internal_invocation`, `precommit_install_artifact_staged`, `precommit_script_mode_invalid`, `precommit_typechange_to_symlink` (scaffold)
- `ideation_incomplete_definition_fields` (ideation)
- `summary_section_missing`, `summary_section_empty`, `summary_section_missing_warn`, `summary_section_empty_warn` (summary)
- `step_order_invalid`, `decided_by_invalid_for_policy`, `nonce_stale` (gate)
- `state_validation_failed_warn` (state-mutation, warn)

**orchestration-delegation-contract adds 9 codes (D1/D3/D6 specs):**

New categories (handoff, layer, presentation, definition):
- `handoff_schema_invalid`, `handoff_required_field_missing`, `handoff_unknown_field` (handoff)
- `skill_layer_unset`, `layer_policy_invalid`, `layer_tool_violation`, `engine_furrow_leakage` (layer)
- `driver_definition_invalid` (definition)
- `presentation_protocol_violation` (presentation)

**Merge resolution:**
- Zero code name overlap
- Append orchestration's 9 codes to blocker-taxonomy-foundation's 16 codes
- Both already define disjoint sections; concatenation is safe

**Result:** 40 total blocker codes across 9 categories

---

## Semantic Conflict Files (Decision Required)

### 1. `.furrow/almanac/todos.yaml` — SEMANTIC_CONFLICT

**Conflict signature:** Both branches add/modify the same TODO entries, but source from different rows and mark different todos as done.

**blocker-taxonomy-foundation changes:**

Adds (in order):
1. `pi-adapter-binary-caching` (created 2026-04-25) at line ~4046
   - Exact definition: Pre-build Go binary at Pi adapter init; cache for session; benchmark <50ms median
2. `sweeping-schema-audit-and-shrink` (created 2026-04-25) at line ~4180
   - Exact definition: Schema audit across all .furrow/ schemas; identify dead/under-used fields
3. Moves `ci-wiring-of-integration-test-runner` to follow ci-wiring pattern
4. Moves `correction-limit-integration-fixture` to integration fixture section

**orchestration-delegation-contract changes:**

Marks as done (status: active → done, with timestamps 2026-04-27):
1. `furrow-context-isolation-layer` (originally at line ~3290)
2. `handoff-prompt-artifact-template` (originally at line ~3320)
3. `artifact-presentation-protocol` (originally at line ~3318)
4. `delegation-boundary-enforcement` (originally at line ~3360)
5. `layer-context-routing` (originally at line ~3706)

Then adds (in order):
1. `pi-adapter-binary-caching` (created 2026-04-25) — **IDENTICAL to blocker-taxonomy**
   - Same field values, same work_needed description
2. Moves `ci-wiring-of-integration-test-runner` to follow same pattern
3. Moves `correction-limit-integration-fixture` to follow same pattern

**Conflict analysis:**

- **Same TODO, different sources:** `pi-adapter-binary-caching` appears identically in both branches with same content but different surrounding context (blocker-taxonomy adds fresh; orchestration adds fresh with identical copy). This is a dedup scenario — both rows discovered the same gap independently.

- **Different todo ownership:** blocker-taxonomy marks `sweeping-schema-audit-and-shrink` as active (own work). Orchestration doesn't touch this, meaning it's owned by the blocker row.

- **Done todos from orchestration row:** 5 todos marked done by orchestration-delegation-contract represent work OWNED BY orchestration row (D5/D1/D3 deliverables shipped). Blocker-taxonomy doesn't mark these done.

- **Reordering within sections:** Both branches move `ci-wiring-of-integration-test-runner` and `correction-limit-integration-fixture` to different positions within the file. Git merge will fail due to conflicting hunk boundaries.

**Merge strategy:**

1. Accept orchestration's "done" markings for todos it owns (furrow-context-isolation-layer, handoff-prompt-artifact-template, artifact-presentation-protocol, delegation-boundary-enforcement, layer-context-routing)
2. Keep blocker-taxonomy's `sweeping-schema-audit-and-shrink` entry (owned by blocker row, not touched by orchestration)
3. Dedup `pi-adapter-binary-caching` — keep one copy with correct source_work_unit attribution. Line 4043-4055 (blocker) and its orchestration equivalent (~4043) should become one entry referencing "blocker-taxonomy-foundation" as source_work_unit
4. Reconcile the ci-wiring and correction-limit entries — both rows independently identified the same follow-ups. Merge by keeping both source_work_unit references if present, or consolidating if they're identical

**Evidence needed:** Inspect `.furrow/rows/blocker-taxonomy-foundation/definition.yaml` and `.furrow/rows/orchestration-delegation-contract/definition.yaml` to confirm file_ownership; ensure merged todos list correctly attributes work.

---

### 2. `internal/cli/app.go` — SEMANTIC_CONFLICT (HIGH RISK)

**Conflict signature:** Both branches add stdin field and NewWithStdin constructor, but with different signatures. More critically, they have incompatible architectural visions for CLI command layout.

**blocker-taxonomy-foundation changes (~13 line diff):**

```go
type App struct {
  stdin  io.Reader      // NEW
  stdout io.Writer
  stderr io.Writer
}

// NEW: Constructor with stdin
func NewWithStdin(stdin io.Reader, stdout, stderr io.Writer) *App {
  return &App{stdin: stdin, stdout: stdout, stderr: stderr}
}

case "guard":
  return a.runGuard(args[1:])
  
func (a *App) runGuard(args []string) int {
  // Blocker envelope emission logic
}
```

**Architectural assumption:** `guard` is a TOP-LEVEL command (`furrow guard ...`)

---

**orchestration-delegation-contract changes (~78 line diff):**

```go
type App struct {
  stdout io.Writer
  stderr io.Writer
  stdin  io.Reader    // NEW (different field order!)
}

// NEW: Constructor with stdin — DIFFERENT SIGNATURE
func NewWithStdin(stdout, stderr io.Writer, stdin io.Reader) *App {
  return &App{stdout: stdout, stderr: stderr, stdin: stdin}
}

// NEW: Context routing command
case "context":
  return a.runContext(args[1:])
  
// NEW: Handoff command
case "handoff":
  return a.runHandoff(args[1:])

// NEW: Render command
case "render":
  return a.runRender(args[1:])

// NEW: Hook command with SUBCOMMANDS
case "hook":
  return a.runHook(args[1:])
  
func (a *App) runHook(args []string) int {
  switch args[0] {
  case "layer-guard":
    return hook.RunLayerGuard(...)
  case "presentation-check":
    return hook.RunPresentationCheck(...)
  }
}
```

**Architectural assumption:** `guard` is a HOOK SUBCOMMAND (`furrow hook layer-guard ...` or `furrow hook <name> ...`)

---

**Conflict details:**

1. **Constructor signature mismatch:**
   - blocker: `NewWithStdin(stdin, stdout, stderr)`
   - orchestration: `NewWithStdin(stdout, stderr, stdin)`
   - These cannot both be exported without creating an ambiguous call site. One will shadow the other.

2. **CLI layout divergence:**
   - blocker assumes: `furrow guard [args]` as top-level command
   - orchestration assumes: `furrow hook <subcommand> [args]` with guard-like logic inside hook subcommand router
   - If blocker-taxonomy's guard is merged as top-level, then "furrow guard" and "furrow hook layer-guard" become parallel commands for similar concerns (guarding/validation)
   - Per orchestration architecture, all runtime hooks should be under `furrow hook <name>` namespace to avoid CLI sprawl

3. **Scope expansion:**
   - orchestration adds 4 major commands (context, handoff, render, hook) as first-class CLI citizens
   - blocker adds only guard
   - orchestration's vision is a comprehensive CLI; blocker's is focused on one guard function

4. **Test implications:**
   - blocker's guard tests assume top-level `furrow guard` command
   - orchestration's hook tests assume `furrow hook layer-guard` and `furrow hook presentation-check` subcommands
   - Merging both will require test unification or conditional skip logic

**Decision required:**

**Option A: "Orchestration-first" (recommended)**
- Keep orchestration's hook subcommand architecture
- Move blocker-taxonomy's `guard` logic into orchestration's hook subcommand router as `furrow hook blocker-validate` or similar
- Rename `runGuard` to `runBlockerValidate` or keep it as internal but dispatch via hook router
- Update blocker-taxonomy's integration tests to call `furrow hook blocker-validate` instead of `furrow guard`
- Use orchestration's NewWithStdin signature (stdout, stderr, stdin)

**Rationale:** Orchestration's architecture is intentionally designed to avoid CLI sprawl by grouping runtime hooks under a single `furrow hook` namespace. Blocker-taxonomy's guard function fits naturally into this pattern. The hook subcommand router (orchestration) is the canonical future state per architecture/orchestration-delegation-contract.md D2 (driver-architecture).

**Option B: "Parallel commands" (not recommended)**
- Keep both `furrow guard` and `furrow hook <name>` as parallel top-level commands
- Resolve signature conflict by renaming one constructor (e.g., `NewWithStdinGuard` vs `NewWithStdin`)
- Accept CLI redundancy and maintain two command hierarchies indefinitely
- Document both paths in help text

**Rationale:** Preserves blocker-taxonomy's autonomy; simpler merge. Downside: CLI becomes inconsistent; users confused about whether to use `guard` or `hook`; future validators/hooks face same choice.

**Recommendation:** Choose Option A. Evidence: orchestration-delegation-contract's architecture docs (D2 section on `furrow hook` as the canonical hook dispatch mechanism, per specs/driver-architecture.md) and the clean separation-of-concerns between context/handoff/render/hook as first-class commands vs runtime guards relegated to subcommands.

**Implementation effort:** Medium. Requires:
1. Merge both stdin additions (struct field is identical)
2. Keep orchestration's NewWithStdin signature
3. Move blocker's guard implementation into hook.RunBlockerValidate (or wire through existing RunLayerGuard if compatible)
4. Update blocker-taxonomy's tests to call hook subcommand instead of guard top-level
5. Verify no other callers of `runGuard` in tests or main.go

**Evidence sources:**
- blocker-taxonomy-foundation: internal/cli/guard.go (lines 1-309), internal/cli/app.go (lines ~80-82), internal/cli/guard_test.go
- orchestration-delegation-contract: internal/cli/hook/layer_guard.go, internal/cli/app.go (lines ~204-232), specs/driver-architecture.md (D2 section on hook dispatch), docs/architecture/orchestration-delegation-contract.md (D3 boundary enforcement via hook)

---

## Cross-Pollination Opportunities

### 1. **orchestration's context routing as home for blocker-taxonomy's guard logic**
   - **Pattern:** orchestration's `internal/cli/context/cmd.go` dispatcher + router
   - **Blocker benefit:** Guard doesn't need standalone `runGuard`; fits into orchestration's hook subcommand dispatcher as `furrow hook blocker-validate`
   - **File:** internal/cli/app.go (hook router), internal/cli/hook/ (subcommand homes)
   - **Why:** Eliminates architectural divergence; guard becomes a first-class hook alongside layer-guard and presentation-check

### 2. **blocker-taxonomy's comprehensive test fixture infrastructure as template for orchestration's boundary tests**
   - **Pattern:** blocker-taxonomy's `tests/integration/fixtures/blocker-events/` with 60+ per-code fixtures, per-fixture SKIP_REASON logic, JSON envelope validation
   - **Orchestration benefit:** boundary-leakage (test-boundary-leakage.sh) could reuse the fixture generation pattern for reproducing layer violations
   - **File:** tests/integration/fixtures/blocker-events/, tests/integration/lib/sandbox.sh
   - **Why:** Blocker's fixture infrastructure is battle-tested; orchestration's boundary tests are still maturing (cross-model flagged corpus hallucination initially)

### 3. **orchestration's layer-policy + hook Go subcommand pattern as future home for all validators**
   - **Pattern:** orchestration's `internal/cli/hook/layer_guard.go` reads layer-policy.yaml at runtime; validates against structured policy; returns JSON or exit code
   - **Blocker benefit:** Future validators (schema-audit, state-mutation guards) should follow this pattern instead of shell script hooks. Eliminates shell parse debt documented in correction-limit.sh (+100 lines of shell argument parsing)
   - **File:** internal/cli/hook/layer_guard.go (exemplar)
   - **Why:** Go-native validators are faster, testable, and composable; shell hooks are maintenance-heavy

### 4. **blocker-taxonomy's learnings.jsonl as a model for orchestration's row-local documentation**
   - **Pattern:** blocker-taxonomy captures 7 learnings (shared-contracts as cross-spec arbiter, per-hook event types, JSON-array stdout, cross-model hallucination risk, parity anti-cheat patterns, Pi-handler-absent skip rule)
   - **Orchestration benefit:** orchestration row has similar learnings (decision-format-parseability, handoff-shape, subagent-semantics) but they're scattered across research/synthesis.md. Consolidating into learnings.jsonl makes them discoverable and reusable
   - **File:** .furrow/rows/blocker-taxonomy-foundation/learnings.jsonl (exemplar)
   - **Why:** Structured learnings enable future rows to reference and avoid repeating the same research

### 5. **orchestration's handler dispatch pattern for Pi adapter as model for blocker's Pi handler re-architecture**
   - **Pattern:** orchestration's `adapters/pi/extension/index.ts` (functions dispatchAsClaudeAgent, dispatchEngineAsSubprocess) with explicit mode selection and fallback
   - **Blocker benefit:** blocker-taxonomy's Pi handler (adapters/pi/furrow.ts) invokes `go run ./cmd/furrow` on every validate-definition + validate-summary call. Orchestration's binary-caching pattern (noted in follow-up TODO pi-adapter-binary-caching) would be faster; adoption of dispatch-style selection (subprocess vs native) makes caching explicit
   - **File:** adapters/pi/extension/index.ts (exemplar)
   - **Why:** blocker-taxonomy identified the latency regression risk but left it as a TODO; orchestration's architecture provides the solution pattern

---

## Ranked Risk List (Top 5)

### Risk #1: **CLI Architecture Divergence (app.go command layout)** — Impact: HIGH, Difficulty-to-revert: MEDIUM

**Decision:** Option A vs Option B above (promote guard to hook subcommand vs parallel commands)

**Impact on correctness:**
- If Option B chosen (parallel commands), future hook additions will face same architectural choice
- CLI becomes inconsistent; users confused about `furrow guard` vs `furrow hook <name>` semantics
- Test coverage diverges (blocker tests exercise top-level guard; orchestration tests exercise hook subcommand)

**Difficulty to revert:** Medium. If Option B initially chosen and later reversed to Option A:
- All blocker-taxonomy tests that call `furrow guard` must be rewritten to call `furrow hook blocker-validate`
- Any production code invoking guard top-level must be updated
- CLI documentation must be revised

**Evidence:**
- blocker-taxonomy-foundation: internal/cli/guard.go (309 lines), internal/cli/guard_test.go (554 lines), integration tests calling guard
- orchestration-delegation-contract: internal/cli/hook/layer_guard.go, specs/driver-architecture.md D2 (hook dispatch architecture)
- Decision: Accept Option A recommendation; move guard logic under hook dispatcher

---

### Risk #2: **Constructor Signature Mismatch (NewWithStdin)** — Impact: MEDIUM, Difficulty-to-revert: LOW

**Decision:** Choose orchestration's signature (stdout, stderr, stdin) as canonical

**Impact on correctness:**
- If blocker's signature (stdin, stdout, stderr) is kept, callers in main.go and tests must match
- Blocker's tests use stdin, stdout, stderr positional order; orchestration's tests use different order
- If both exported, callers will shadow one with the other; runtime errors emerge when wrong constructor is called

**Difficulty to revert:** Low. Constructor rename is straightforward.

**Evidence:**
- blocker-taxonomy-foundation: internal/cli/app.go (+14-51), internal/cli/guard_test.go (NewWithStdin calls)
- orchestration-delegation-contract: internal/cli/app.go (+51-59), hook_test.go and other tests (NewWithStdin calls)

**Decision:** Use orchestration's signature (stdout, stderr, stdin) as canonical. If blocker tests use different order, update them locally.

---

### Risk #3: **Todo Ownership and Deduplication (todos.yaml)** — Impact: MEDIUM, Difficulty-to-revert: MEDIUM

**Decision:** Dedup pi-adapter-binary-caching; attribute to blocker row (source_work_unit: blocker-taxonomy-foundation)

**Impact on correctness:**
- If dedup not done, same TODO appears twice with different source_work_unit; ambiguous ownership
- Future work on pi-adapter-binary-caching could start from either copy; divergence risk
- Sorting/merging todos becomes fragile (two entries with nearly identical content)

**Difficulty to revert:** Medium. If dedup done incorrectly and later expanded back to two copies, todos.yaml validator must allow duplicates or re-split logic must be transparent.

**Evidence:**
- blocker-taxonomy-foundation: .furrow/almanac/todos.yaml (pi-adapter-binary-caching at ~4046, source_work_unit: blocker-taxonomy-foundation)
- orchestration-delegation-contract: .furrow/almanac/todos.yaml (pi-adapter-binary-caching at ~4043, source_work_unit: blocker-taxonomy-foundation — same!)

**Decision:** Merge to single pi-adapter-binary-caching entry. Verify source_work_unit attribution via definition.yaml file_ownership for both rows. If both rows claim ownership, escalate for clarification.

---

### Risk #4: **Hook Settings Configuration Collision (settings.json)** — Impact: LOW, Difficulty-to-revert: LOW

**Decision:** TRIVIAL_UNION resolution above is correct; no collision

**Impact on correctness:**
- blocker removes gate-check hook (gate-check.sh deleted per migration to Go shims)
- orchestration adds layer-guard + presentation-check hooks (new Go shims)
- No contradictory assertions on the same hook

**Difficulty to revert:** Low. Settings are atomic; each hook entry is independent.

**Decision:** Apply TRIVIAL_UNION merge strategy above. No escalation needed.

---

### Risk #5: **Schema Extension Parity (blocker-taxonomy.yaml schema additions)** — Impact: LOW, Difficulty-to-revert: LOW

**Decision:** TRIVIAL_UNION resolution above is correct; no collision

**Impact on correctness:**
- blocker-taxonomy adds 16 codes (state-mutation, scaffold, ideation, summary, gate categories)
- orchestration adds 9 codes (handoff, layer, presentation, definition categories)
- Zero code name overlap; both sets are independently defined and valid

**Difficulty to revert:** Low. Blocker codes and orchestration codes are in disjoint namespaces; reverting either set doesn't affect the other.

**Decision:** Apply TRIVIAL_UNION merge strategy (append orchestration codes). No escalation needed.

---

## Final Synthesis Recommendation

### Merge Strategy Summary

| File | Classification | Recommended Approach | Confidence |
|------|---|---|---|
| `.claude/settings.json` | TRIVIAL_UNION | Remove gate-check; add layer-guard + presentation-check to specified matchers | HIGH |
| `schemas/blocker-taxonomy.yaml` | TRIVIAL_UNION | Append 9 orchestration codes to 16 blocker codes; total 40 codes | HIGH |
| `.furrow/almanac/todos.yaml` | SEMANTIC_CONFLICT | (1) Dedup pi-adapter-binary-caching to single entry (source_work_unit: blocker-taxonomy-foundation); (2) Accept orchestration's "done" marks for its-owned todos; (3) Keep blocker's sweeping-schema-audit-and-shrink (owned by blocker row) | MEDIUM |
| `internal/cli/app.go` | SEMANTIC_CONFLICT | Move blocker's guard logic under orchestration's hook subcommand dispatcher (Option A): (1) Keep orchestration's struct field order (stdin last); (2) Keep orchestration's NewWithStdin signature (stdout, stderr, stdin); (3) Integrate blocker's guard implementation as hook.RunBlockerValidate or subcommand of hook router; (4) Update blocker's tests to call `furrow hook blocker-validate` instead of `furrow guard` | MEDIUM |

### Per-File Recommendations for Semantic Conflicts

#### Recommendation 1: `.furrow/almanac/todos.yaml`

**Approach:** Context-aware merge with dedup and ownership verification

**Steps:**
1. Read `.furrow/rows/blocker-taxonomy-foundation/definition.yaml` file_ownership for blocker row (confirms blocker owns which todos)
2. Read `.furrow/rows/orchestration-delegation-contract/definition.yaml` file_ownership for orchestration row (confirms orchestration owns which todos)
3. In merged todos.yaml:
   - Keep blocker's `sweeping-schema-audit-and-shrink` (owned by blocker per definition.yaml)
   - Keep blocker's todo entries for pi-adapter-binary-caching and ci-wiring and correction-limit, but mark source_work_unit correctly
   - Accept orchestration's "done" status changes for its-owned todos (furrow-context-isolation-layer, handoff-prompt-artifact-template, artifact-presentation-protocol, delegation-boundary-enforcement, layer-context-routing)
4. Validate merged todos.yaml against schema (rws validate-summary or equivalent)

**Rationale:** Both rows legitimately discovered the same follow-up (pi-adapter-binary-caching) and should not duplicate ownership. Orchestration's done markings are accurate for its deliverables; blocker's sweeping-schema-audit is legitimate new work discovered during blocker research that orchestration didn't touch.

---

#### Recommendation 2: `internal/cli/app.go`

**Approach:** Option A — Architectural alignment on hook subcommand dispatch

**Steps:**
1. Keep struct field additions from orchestration (stdin added, final order: stdout, stderr, stdin)
2. Keep orchestration's NewWithStdin signature and implementation
3. Keep orchestration's context/handoff/render/hook command dispatchers
4. Integrate blocker's guard logic:
   - Option A1 (preferred): Extract guard logic from blocker's guard.go into a new hook subcommand handler (e.g., internal/cli/hook/blocker.go:RunBlockerValidate) and wire it into orchestration's runHook router as `case "blocker-validate"`
   - Option A2 (if blocker guard and orchestration layer-guard share logic): Consolidate into single validator dispatcher with option flags
5. Update blocker's tests:
   - Locate all test calls to `furrow guard ...` and rewrite to `furrow hook blocker-validate ...`
   - Update blocker's integration tests (internal/cli/guard_test.go) to use new hook path
6. Update help text in app.go to list `blocker-validate` under hook subcommands
7. Run `go test ./internal/cli/...` to verify no regressions

**Rationale:** Orchestration's architecture is the intentional future state per specifications. Guard is a validation hook and belongs under the hook namespace. This prevents CLI sprawl and provides a clear pattern for future validators.

**Evidence basis:**
- blocker-taxonomy-foundation spec (`specs/normalized-blocker-event-and-go-emission-path.md §C7`): "CLI contract: furrow guard CLI ... accepts ... returns JSON array ... exit 0/1 only"
- orchestration-delegation-contract spec (`specs/driver-architecture.md D2`): "`furrow hook <name>` is the canonical hook dispatch mechanism for all runtime validators"
- Review findings: orchestration-delegation-contract D2 review (reviews/driver-architecture.json) flags "no namespace pollution" as a core design principle

---

### Integration Checklist

After resolving all semantic conflicts, verify:

- [ ] `.claude/settings.json` hooks are in correct matchers (PreToolUse for Write/Bash, SendMessage, Stop)
- [ ] `schemas/blocker-taxonomy.yaml` has 40 codes with distinct names and valid categories
- [ ] `.furrow/almanac/todos.yaml` has no duplicate entries; each todo has single source_work_unit
- [ ] `internal/cli/app.go` exports one NewWithStdin signature (stdout, stderr, stdin order)
- [ ] Blocker's guard tests are rewritten to use hook subcommand
- [ ] `go test ./internal/cli/...` passes all tests
- [ ] Integration tests (`tests/integration/test-*.sh`) pass without conflicts
- [ ] Help text (`furrow help`) lists commands without duplication
- [ ] Both rows' deliverables are correctly attributed in final file_ownership checks

---

## Evidence References

**blocker-taxonomy-foundation artifacts:**
- Definition: `.furrow/rows/blocker-taxonomy-foundation/definition.yaml` (5 deliverables)
- Plan: `.furrow/rows/blocker-taxonomy-foundation/plan.json` (4 waves)
- Reviews: `.furrow/rows/blocker-taxonomy-foundation/reviews/` (5/5 PASS)
- Summary: `.furrow/rows/blocker-taxonomy-foundation/summary.md` (all 5 deliverables completed)

**orchestration-delegation-contract artifacts:**
- Definition: `.furrow/rows/orchestration-delegation-contract/definition.yaml` (6 deliverables)
- Plan: `.furrow/rows/orchestration-delegation-contract/plan.json` (6 waves)
- Reviews: `.furrow/rows/orchestration-delegation-contract/reviews/` (6/6 PASS, 1 correction)
- Summary: `.furrow/rows/orchestration-delegation-contract/summary.md` (all 6 deliverables completed)

---

**Generated:** 2026-04-27 by conflict-cartographer on integrate/phase-4 branch

