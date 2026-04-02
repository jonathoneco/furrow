# Narrative Assessment: V2 Harness Implementation

## Overall Verdict

The v2 harness has successfully built the **structural foundation** — the convention layer, file-based state, context tiers, and step-aware workflow. Where it falls short is in **runtime enforcement**: the mechanisms that catch misbehavior while it happens rather than after the fact. The architecture is right; the teeth are missing.

---

## Insight 1: Convention Layer, Not Engine

**Research said**: The harness should define WHAT work looks like, HOW to evaluate, WHERE context lives, WHEN humans involve. Everything else is platform.

**Implementation delivers**: This is the clearest win. The harness explicitly avoids reimplementing any platform capability. `_rationale.yaml` documents exactly why each component exists and when it should be deleted. There's no agent loop, no state machine, no tool manager, no session manager. The `adapters/` split cleanly separates platform bindings from harness conventions.

**Concern**: The 7-step sequence (ideate→research→plan→spec→decompose→implement→review) is itself a process engine. The research warned against process-shaped guardrails in favor of outcome-shaped ones. The fixed sequence means a quick bug fix traverses the same steps as a multi-week initiative. The `auto-advance.sh` script mitigates this by skipping trivial steps, but the underlying assumption is that all work is sequential — which contradicts the research finding that work decomposition should emerge from complexity, not be prescribed.

**Rating**: Strong alignment with minor philosophical tension.

---

## Insight 2: Dual-Runtime Abstraction

**Research said**: Only way to serve both Claude Code and Agent SDK is a declarative layer above both.

**Implementation delivers**: The `adapters/shared/` directory contains the right abstraction — schemas, conventions, and gate records that both runtimes consume. `adapters/claude-code/` has a working progressive-loading map. `adapters/agent-sdk/` has a functional `config.py` with schema validation and work unit auto-discovery.

**Gap**: The Agent SDK adapter is ~50% stubs. `coordinator.py`, `specialist.py`, and `reviewer.py` are framework boilerplate marked "TODO: customize." This means the harness is currently **Claude Code-only in practice**. The dual-runtime aspiration is architecturally sound but only half-delivered.

**Rating**: Architecture correct, execution half-complete.

---

## Insight 3: Eval-First — Evals Define Behavior

**Research said**: Eval is the source of truth. Eval + description + prompt (optimized against eval). No separate prose spec.

**Implementation delivers**: Eight evaluation dimension YAML files exist with binary pass/fail criteria per step. The review skill defines a Phase A (artifact validation) + Phase B (quality review) pipeline. The `skills/shared/eval-protocol.md` provides evaluator guidelines.

**Gap**: This is the widest deviation from research intent. The research envisioned:
- An **eval runner** that executes evaluations automatically
- **LLM-as-judge** capability with weighted criteria and evidence requirements
- **Calibration** tracking with storage and recalibration triggers
- A **bootstrap sequence** (Phase 0→1→2→3→4) deploying eval levels progressively
- **Behavioral trace** analysis from structured traces

None of this automation exists. The eval dimensions are static rubrics that a human or agent reads and interprets manually. There's no eval runner, no trace infrastructure, no calibration storage, no LLM-judge orchestration.

The research explicitly warned: "eval-first means evals define behavior." Without automation, evals are documentation — advisory at best. The gap review placed eval triggering at severity "High" with "Hard gate" enforcement needed.

**Rating**: Significant gap. The eval dimensions are well-designed but inert.

---

## Insight 4: Context Tiers Map to Management Mechanisms

**Research said**: Three tiers (ambient > work > session) with different lifespans, mechanisms, and storage.

**Implementation delivers**: This is exceptionally well-implemented. The budget enforcement is explicit and measurable:
- Ambient: <=100 lines (CLAUDE.md + rules/)
- Work: <=150 lines (skills/work-context.md)
- Step: <=50 lines (skills/{step}.md, replaced at boundaries)
- Total injected: <=300 lines

`scripts/measure-context.sh` verifies budgets. `adapters/claude-code/progressive-loading.yaml` maps steps to skills. `hooks/post-compact.sh` re-injects context after compaction. The `references/` directory (10 protocol docs, ~600 lines) is explicitly NOT injected — it's on-demand only.

**Rating**: Fully aligned and well-executed. This is the harness's strongest feature.

---

## Insight 5: Generator-Evaluator Separation

**Research said**: Self-review fails. Structural separation with fresh context, separate prompt, sees output only.

**Implementation delivers**: The review step is structurally separate from implementation. Specialist templates exist for domain-specific review. The `harness.yaml` config has a `cross_model.provider` field for cross-model evaluation.

**Gap**: There's no runtime mechanism that enforces separation. Nothing prevents a review agent from having the same context as the implementer. Nothing reads the `cross_model.provider` config to route evaluation to a different model. The enforcement is entirely advisory — the review skill says "use a separate evaluator" but nothing makes it happen.

The research was clear: "self-evaluation unreliable" and "agents confidently praise mediocre work." Without structural enforcement, the harness relies on the model following instructions to separate concerns — exactly the failure mode the gap review identified.

**Rating**: Architecturally prepared, not enforced.

---

## Insight 6: Outcome-Based Decomposition

**Research said**: Define WHAT + WHEN, not HOW. Over-specification hurts.

**Implementation delivers**: The `definition.schema.json` captures objective, deliverables with acceptance_criteria, constraints, and gate_policy. The schema explicitly doesn't specify implementation approach. The decompose skill produces wave-based execution plans from dependency graphs.

**Minor tension**: The 6-part ideation ceremony in `skills/ideate.md` is process-heavy (brainstorm, premise challenge, questions, cross-model review, section-by-section approval, hard gate). For simple work, this is over-specification. The research warned: "keep planning high-level" and "over-specification" was listed as a failure mode in the Anthropic blog analysis.

**Rating**: Good alignment at the schema level, ceremony may be over-specified.

---

## Insight 7: Harness Should Be Mostly Files

**Research said**: Dual-runtime + thin convention layer + file-based communication converge on files.

**Implementation delivers**: Perfect adherence. Every artifact is a file:
- `definition.yaml` (work contract)
- `state.json` (progress tracking)
- `summary.md` (handoff context)
- `plan.json` (execution plan)
- `reviews/` (review results)
- `learnings.jsonl` (captured insights)
- `gates/` (gate evidence)

Git is the audit trail. No external dependencies. Shell scripts for lifecycle operations. Even the evaluation dimensions are YAML files.

**Rating**: Fully aligned.

---

## Insight 8: Design for Deletion, Not Extension

**Research said**: Every component encodes a model assumption with a half-life. Annotate rationale. Remove → run evals → see what breaks.

**Implementation delivers**: `_rationale.yaml` is comprehensive (522 lines, 80+ components). Each entry has `exists_because` (current justification) and `delete_when` (removal condition). Examples:
- `hooks/state-guard.sh`: delete when "Claude Code natively enforces state.json write protection"
- `skills/ideate.md`: delete when "Claude Code has a native ideation ceremony"
- `install.sh`: delete when "platform-native harness installation exists"

**Gap**: The deletion conditions are documented but untestable. There's no automation to check whether conditions are met — no "deletion testing" as the research described. The research envisioned automated tests: remove component → run evals → keep if evals degrade. Without eval automation (Insight 3), deletion testing is impossible.

**Rating**: Documentation excellent, automation absent (blocked by eval infrastructure gap).

---

## Implementation-Originated Innovations

Things the harness does well that no research document explicitly anticipated:

### 1. Learnings Capture as First-Class Artifact
The `learnings.jsonl` format with categories (pattern, pitfall, preference, convention, dependency) and the promotion protocol (`commands/lib/promote-learnings.sh`) create a knowledge accumulation loop. The research mentioned "self-improvement" abstractly but didn't design this specific mechanism.

### 2. Context Budget Measurement
`scripts/measure-context.sh` provides quantitative verification of context budgets — not just guidelines but measurable enforcement. The research described tiers but didn't specify tooling to verify them.

### 3. Red Flags Catalog
`skills/shared/red-flags.md` provides a per-step anti-pattern catalog that's loaded during each step. This is a practical convention-enforcement tool that the research didn't design.

### 4. Rewind Capability
`commands/lib/rewind.sh` can rollback a step (cleanup + state reset). The research discussed error recovery abstractly but didn't specify a concrete rewind mechanism.

### 5. Hook-Based State Protection
`hooks/state-guard.sh` blocks direct writes to `state.json`, enforcing that all mutations go through `scripts/update-state.sh`. This is a practical enforcement mechanism that emerged from implementation, not from research specs.

### 6. Post-Compaction Recovery
`hooks/post-compact.sh` re-injects state, summary, and current step skill after Claude Code's context compaction. The research mentioned "context recovery" but the specific hook-based approach is an implementation innovation.

---

## Failure Mode Drift Assessment

The research warned against five specific failure modes from v1. Status:

| Failure Mode | Current Risk |
|-------------|-------------|
| **Prose-as-infrastructure** (594-line command files) | **Low** — commands are ~30 line markdown specs, logic in shell scripts |
| **Platform reimplementation** (70% duplication) | **Low** — explicit use of platform hooks, skills, teams |
| **Implicit contracts** (undocumented assumptions) | **Low** — schemas enforce structure, conventions are documented |
| **Context bloat** (849 lines/session) | **Low** — 300-line budget with measurement tooling |
| **Monolithic context** (single injection) | **Low** — progressive loading, tier separation, on-demand references |

The implementation has successfully avoided all five v1 failure modes. The remaining risks are about missing enforcement, not about architectural drift.

---

## Architectural & Functionality Gaps

Beyond enforcement, three deep audits reveal structural gaps in how the harness actually operates.

### Gap A: Multi-Agent Orchestration Exists Only as Specification

The research designed a 4-role architecture (planner, coordinator, specialist, evaluator) with parallel wave execution. The implementation has:
- **Schemas** for plan.json wave structure (validated)
- **Specialist templates** (3 domain experts)
- **Context isolation rules** (documented in prose)
- **File ownership detection** (advisory warnings, post-hoc conflict checks)

But it **completely lacks**:
- **Team composition derivation** — no algorithm reads definition.yaml deliverables and produces team assignments. A human manually interprets the definition and dispatches agents.
- **Wave executor** — plan.json defines waves but nothing reads them and launches specialists in order. No wave boundary enforcement.
- **Specialist context seeding** — the "context seeding contract" (identity, task, file ownership, input artifacts) is documented but no code constructs agent prompts from definition.yaml fields. Humans manually build prompts.
- **Coordinator logic** — `adapters/agent-sdk/templates/coordinator.py` is 156 lines with 15+ TODO comments. It can load state but has zero execution intelligence.

**Impact**: For single-deliverable work, this doesn't matter — a single agent works through the steps. For multi-deliverable work (the use case the research says is most valuable), the harness provides schemas and documentation but **zero operational machinery**. The human IS the coordinator.

### Gap B: Step Artifacts Are Not Validated Before Advancement

Each step is supposed to produce specific artifacts. The harness records gates and advances steps but **never checks that artifacts were actually produced**:

| Step | Expected Artifact | Validated? |
|------|------------------|------------|
| ideate | definition.yaml | **Yes** — schema validation via `validate-definition.sh` |
| research | research.md or research/ | **No** — no existence check |
| plan | plan.json (if >1 deliverable) | **No** — validator exists (`validate_plan_json()`) but is never called automatically |
| spec | spec.md or specs/ | **No** — no template, no schema, no existence check |
| decompose | plan.json with waves | **No** — same validator, never auto-triggered |
| implement | Code changes (git diff) | **No** — no check that diff is non-empty |
| review | reviews/{deliverable}.json | **No** — no schema, no existence check |

`step-transition.sh` only does: record gate → regenerate summary → advance step → update timestamp. It does not call any artifact validation. A step can advance with zero artifacts produced.

**Additionally missing**:
- No `plan.json` schema file (the validator in `hooks/lib/validate.sh` hard-codes the structure, but there's no standalone JSON schema)
- No spec template in `templates/` (only research templates exist)
- No `reviews/{deliverable}.json` schema
- `init-work-unit.sh` doesn't create `reviews/` despite docs saying it should

### Gap C: Trust Gradient and Work Modes Are ~90% Prose

The research described three trust levels (supervised/delegated/autonomous) and two work modes (code/research) with distinct runtime behaviors. Audit findings:

**Trust gradient — what's actually wired**:
- `auto-advance.sh`: supervised mode blocks all auto-advance (~20 lines of shell)
- `hooks/stop-ideation.sh`: autonomous mode skips ideation marker validation

**Trust gradient — what's only prose**:
- Gate decision routing (supervised waits for human, delegated auto-advances on pass, autonomous auto-advances on pass/conditional) — all described in `skills/gate-prompt.md` as instructions, not enforced
- Per-deliverable gate override (`definition.schema.json` has the field, nothing reads it)
- Evaluator vs. human decision routing — no executable logic

**Work mode — what's actually wired**:
- `auto-advance.sh`: research mode blocks research step auto-advance (~5 lines)

**Work mode — what's only prose**:
- Output directory selection (research → `.work/{name}/deliverables/`, code → git) — skill instructions only
- Eval dimension selection (research uses `research-implement.yaml`, code uses `implement.yaml`) — `reviewer.py` hardcodes `implement.yaml`
- Mode flag persistence — `init-work-unit.sh` hardcodes `mode: "code"`, the `--mode research` flag from `/work` command **is never passed through**

**Impact**: The harness behaves identically regardless of trust level or work mode, except for auto-advance blocking. An agent in "autonomous" mode gets the same harness experience as "supervised" — the difference is only in what the skill prose tells the agent to do. This is "trust the agent to follow instructions" rather than "enforce different behavior by trust level."

### Gap D: Missing Schemas for Core Artifacts

The harness has thorough schemas for `definition.yaml` and `state.json` but is missing schemas for other artifacts that the workflow produces:

| Artifact | Schema Exists? | Template Exists? |
|----------|---------------|-----------------|
| definition.yaml | **Yes** (JSON Schema) | N/A (human-authored) |
| state.json | **Yes** (JSON Schema) | N/A (harness-generated) |
| plan.json | **No** (validator exists in validate.sh but no schema file) | **No** |
| spec.md | **No** | **No** |
| team-plan.md | **No** | **No** |
| reviews/{deliverable}.json | **No** (schema defined in `adapters/shared/schemas/review-result.schema.json` — exists!) | **No** |
| gate evidence | **No** (gate-record schema exists in `adapters/shared/schemas/`) | **No** |
| learnings.jsonl | **No** (format in prose in `learnings-protocol.md`) | **No** |

The `adapters/shared/schemas/` directory has `plan.schema.json` and `review-result.schema.json` — but these are in the adapter layer, not in the main `schemas/` directory, and no validation script references them. They're disconnected from the harness's validation pipeline.

### Gap E: No End-to-End Workflow Wiring

The individual components are well-built but several cross-component connections are missing:

1. **`--mode research` flag → state.json**: The work command describes passing this flag, but `init-work-unit.sh` doesn't accept it. Mode is always "code".
2. **`cross_model.provider` config → review agent dispatch**: Config field exists in `harness.yaml`, nothing reads it.
3. **`plan.schema.json` in adapters/shared → validation in step-transition**: Schema exists, validation function exists in `hooks/lib/validate.sh`, but step-transition never calls it.
4. **`review-result.schema.json` → review output validation**: Schema exists, no script validates review outputs against it.
5. **Eval dimensions → review agent**: Dimensions are YAML files in `evals/dimensions/`, the review skill says to load them, but no automation selects the right dimension file based on current step or mode.
