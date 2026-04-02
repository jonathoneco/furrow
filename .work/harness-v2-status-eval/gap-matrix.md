# Gap Matrix: V2 Harness Implementation vs. Research & Plans

## A. Research Insights (Findings Synthesis) vs. Implementation

| # | Research Insight | Implementation Artifact(s) | Status |
|---|-----------------|---------------------------|--------|
| 1 | **Convention Layer, Not Engine** — harness defines WHAT, not reimplements platform | `_rationale.yaml` (deletion conditions), thin adapters, no agent loop/state machine/tool manager | **Implemented** — architecture correctly avoids platform reimplementation. ~23 core files, all declarative/convention. |
| 2 | **Dual-Runtime Abstraction** — declarative layer above both Claude Code and Agent SDK | `adapters/claude-code/`, `adapters/agent-sdk/`, `adapters/shared/` | **Partial** — Claude Code adapter is production-ready (progressive-loading.yaml, skills, hooks). Agent SDK adapter has config.py + state_mutation.py functional, but coordinator/specialist/reviewer templates are stubs. |
| 3 | **Eval-First: Evals Define Behavior** — eval is source of truth, not prose | `evals/dimensions/` (8 dimension YAMLs), `skills/shared/eval-protocol.md`, review skill Phase A/B | **Partial** — Evaluation dimensions exist with binary pass/fail criteria. No eval runner, no LLM-judge runner, no calibration system. Evals are human-interpreted rubrics, not automated. |
| 4 | **Context Tiers Map to Management Mechanisms** — ambient > work > session | CLAUDE.md (ambient <=100 lines), `skills/work-context.md` (work <=150 lines), `skills/{step}.md` (step <=50 lines), `scripts/measure-context.sh` | **Implemented** — three tiers with explicit budgets, progressive loading via `adapters/claude-code/progressive-loading.yaml`, post-compaction hook for recovery. |
| 5 | **Generator-Evaluator Separation** — self-review fails, structural separation works | `specialists/` templates, review skill (Phase A/B), cross-model config in `harness.yaml` | **Partial** — Architecture supports separation (review is a distinct step with separate agents). But no mechanism to enforce fresh-context or different-model for evaluator. Cross-model config exists in harness.yaml but nothing reads/uses it at runtime. |
| 6 | **Outcome-Based Decomposition** — define WHAT + WHEN, not HOW | `schemas/definition.schema.json` (deliverables with acceptance_criteria), `skills/decompose.md` (wave planning) | **Implemented** — definition schema enforces deliverable-level acceptance criteria. Decompose skill produces wave-based execution plans. |
| 7 | **Harness Should Be Mostly Files** — work definitions, evals, context, progress all files | `.work/` directories, definition.yaml, state.json, summary.md, plan.json, reviews/ | **Implemented** — entire state is file-based. No database, no external service dependencies. Git as audit trail. |
| 8 | **Design for Deletion, Not Extension** — every component annotated with removal condition | `_rationale.yaml` (522 lines, 80+ components with `exists_because` + `delete_when`) | **Implemented** — comprehensive rationale manifest. Every component has explicit deletion condition. No deletion testing automation exists yet (expected, Phase 4+). |

**Summary**: 5/8 fully implemented, 3/8 partial. The partials cluster around eval automation and runtime enforcement — the "teeth" of the system.

---

## B. Gap Review Behaviors (15) vs. Enforcement Mechanisms

| # | Behavior | Planned Enforcement | Implementation Artifact | Status |
|---|----------|-------------------|------------------------|--------|
| 1 | Load work definition at start | Hard gate (hook) | `hooks/work-check.sh` detects active tasks at session start | **Implemented** |
| 2 | Execute deliverables respecting dependencies | Structural (coordinator parallelism) | `skills/decompose.md` (wave planning), `adapters/shared/schemas/plan.schema.json` | **Partial** — wave structure defined, but no coordinator enforces execution order |
| 3 | Write completion claim before next deliverable | Procedural backstop (hook on progress.json) | `hooks/state-guard.sh` protects state.json from direct writes | **Partial** — state is guarded but no hook triggers on completion claims |
| 4 | Run eval at completion boundary | Hard gate (hook auto-triggers) | `commands/checkpoint.md` (`--step-end` triggers gate), `commands/lib/step-transition.sh` | **Partial** — transition machinery exists, but eval is manual (human runs /checkpoint), not auto-triggered |
| 5 | Stop after N eval failures | Structural + procedural (coordinator tracks, kills specialist) | No implementation | **Absent** — no correction limit hook or tracking |
| 6 | Update progress.json accurately | Procedural backstop (validation hook) | `hooks/state-guard.sh` (write protection), `scripts/update-state.sh` (controlled mutations) | **Implemented** — mutations go through update-state.sh only |
| 7 | Produce work summary at completion | Procedural backstop (hook auto-generates) | `scripts/regenerate-summary.sh`, `hooks/summary-regen.sh` | **Implemented** |
| 8 | Stay within work def scope | Advisory (eval catches post-hoc) | `skills/shared/red-flags.md` (anti-pattern catalog) | **Implemented** (advisory-level, as planned) |
| 9 | Use targeted tool calls | Advisory (specific context pointers) | `schemas/definition.schema.json` (context_pointers with path+note) | **Implemented** (advisory-level, as planned) |
| 10 | Produce eval-specified artifacts | Hard gate (eval must pass) | `evals/dimensions/` (criteria exist), but no automated eval runner | **Partial** — criteria defined, enforcement is manual |
| 11 | Cross-model evaluation | Structural (separate agent, different model) | `harness.yaml` has `cross_model.provider` field | **Partial** — config exists, no runtime mechanism reads it |
| 12 | Write testable eval criteria | Procedural backstop (scope-check eval) | `scripts/validate-definition.sh` (schema validation) | **Partial** — schema validates structure but not quality of criteria |
| 13 | Respect correction limit | Procedural backstop (hook enforces) | No implementation | **Absent** — no correction limit tracking or enforcement |
| 14 | Specialists: domain-appropriate agent | Convention (work def maps to specialists) | `specialists/` (4 templates), definition schema has specialist field | **Implemented** |
| 15 | Preserve work def constraints | Advisory (eval catches post-hoc) | `skills/shared/red-flags.md`, review skill | **Implemented** (advisory-level, as planned) |

**Summary**: 7/15 implemented, 6/15 partial, 2/15 absent. The two absent behaviors (correction limit, eval failure tracking) are both safety mechanisms that prevent runaway agent loops.

---

## C. Plan Phases (PLAN.md) vs. Implementation Coverage

| Phase | Specs | Implementation Status | Notes |
|-------|-------|-----------------------|-------|
| **1: Foundation** | Prompt Format, Work Definition Schema, File Structure, Context Model | **Fully implemented** | YAML frontmatter+MD for skills, YAML for definitions, JSON for state. Schema validated. Three context tiers with budgets. File structure matches plan (~23 core files). |
| **2: Enforcement & Execution** | Hook/Callback Set, Eval Infrastructure, Multi-Agent Team Templates, Dual-Runtime Adapters | **70% implemented** | Hooks: 12 implemented (session-start, state-guard, gate-check, summary-regen, post-compact, ownership-warn, etc.). Eval: dimensions defined, no runner. Teams: specialist templates exist, coordinator is a stub. Adapters: CC complete, Agent SDK partial. |
| **3: Lifecycle** | Ideation Loop, Git Workflow, Research as Work Type, Scope Change Protocol | **80% implemented** | Ideation: full 6-part ceremony in `skills/ideate.md`. Git: conventions in `docs/git-conventions.md` + `skills/shared/git-conventions.md`, scripts for branching/merging. Research: mode flag, research templates, research evals. Scope change: `commands/redirect.md` covers pivots, but no mid-execution scope amendment protocol. |
| **4: Operations** | Autonomous Triggering, Observability, Concurrent Work, Error Recovery, Health Checks | **30% implemented** | Health checks: `scripts/harness-doctor.sh`. Error recovery: `commands/lib/rewind.sh`. No autonomous triggering, no observability dashboard, no concurrent work stream support (detect-context.sh handles single active task only). |
| **5: Knowledge & Ecosystem** | Artifacts, Self-Improvement, Integrations | **40% implemented** | Artifacts: learnings.jsonl capture, templates for research outputs, summary regeneration. Self-improvement: `_rationale.yaml` with deletion conditions (no automation). Integrations: harness.yaml has beans/CI config fields (stubs). |
| **6: Consistency Review** | Cross-spec consistency pass | **Not started** | Expected: no implementation predates this. |

**Summary**: Phase 1 is solid. Phases 2-3 are structurally present but less complete than file counts suggest — key wiring is missing (see below). Phases 4-5 are lightly touched. Phase 6 is pending.

**Revised assessment**: The initial "70%/80%" ratings for Phases 2-3 were based on file existence. Deeper audit reveals these phases have components that exist in isolation but aren't connected:

| Phase 2 Spec | What Exists | What's Missing |
|--------------|-------------|----------------|
| Hook/Callback Set | 12 hooks implemented | Hooks don't call existing validators (e.g., `validate_plan_json` exists but `step-transition.sh` never calls it) |
| Eval Infrastructure | 8 dimension YAMLs | No eval runner, no LLM-judge, dimensions are inert rubrics |
| Multi-Agent Templates | 3 specialist templates, coordinator skeleton | No team composition derivation, no wave executor, no context seeding automation. Coordinator has 15+ TODOs. |
| Dual-Runtime Adapters | CC adapter complete, Agent SDK has config.py | Agent SDK templates are stubs. Schemas exist in adapters/shared/ but aren't linked to main validation pipeline. |

| Phase 3 Spec | What Exists | What's Missing |
|--------------|-------------|----------------|
| Ideation Loop | Full 6-part ceremony | Works well for supervised; ceremony is theater in delegated/autonomous (trust gradient not wired) |
| Git Workflow | Conventions, branch scripts | Works as designed |
| Research as Work Type | Mode flag in schema, templates, dimension YAMLs | `--mode research` flag never passed to init; mode field hardcoded to "code"; dimension selection is prose; output path enforcement is prose |
| Scope Change Protocol | `redirect.md` for pivots | No mid-execution amendment (deferred by design) |

**Revised Phase 2 rating**: 45% (components exist but aren't wired together)
**Revised Phase 3 rating**: 60% (ideation and git work; research mode is non-functional at harness level)

---

## D. Architectural Gaps (not in any plan phase)

These gaps emerged from deep audits of workflow completeness, orchestration, and trust gradient.

| Gap | Category | Severity | Description |
|-----|----------|----------|-------------|
| Step artifacts not validated before advancement | Workflow | **Critical** | Only ideate validates its output. All other steps can advance with zero artifacts. `step-transition.sh` records gates but never checks artifacts exist. |
| plan.json schema disconnected | Schema | **High** | Schema exists at `adapters/shared/schemas/plan.schema.json`, validator exists at `hooks/lib/validate.sh::validate_plan_json()`, but neither is called by step-transition or any hook. |
| Mode flag not persisted | Wiring | **High** | `init-work-unit.sh` hardcodes `mode: "code"`. The `--mode research` flag from `/work` command is never passed through. Research mode is non-functional. |
| Trust gradient is prose-only | Wiring | **High** | `gate_policy` affects only auto-advance blocking (~20 lines). Gate decision routing (supervised vs delegated vs autonomous flow) is entirely in skill prose — not enforced. |
| No team composition derivation | Orchestration | **Medium** | No algorithm reads definition.yaml deliverables and produces team assignments. Human is the coordinator. |
| No wave executor | Orchestration | **Medium** | plan.json defines waves but nothing dispatches specialists in order or enforces wave boundaries. |
| No specialist prompt construction | Orchestration | **Medium** | Context seeding contract documented but no code constructs agent prompts from definition.yaml + specialist templates + file ownership. |
| Missing spec template | Template | **Low** | No template for spec step output. Research templates exist (5); code-mode spec has none. |
| reviews/ not created at init | Wiring | **Low** | `references/work-unit-layout.md` says it's created at initialization; `init-work-unit.sh` doesn't create it. |
| Per-deliverable gate override dead field | Schema | **Low** | `definition.schema.json` has `deliverables[].gate` field. Nothing reads it. |
| Eval dimension selection hardcoded | Wiring | **Low** | `reviewer.py` hardcodes `implement.yaml` path; doesn't check mode or step. |
