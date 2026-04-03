# Roadmap

> Updated: 2026-04-02 | 8 phases, 3/8 complete | 30 TODOs across 12 work units

---

## Dependency DAG

```
Phase 0 ── T1 [x] ──┐
                     │
Phase 1 ─────────────┤── T2 [x] ── T3 [x] ── T4 [x] ── T6 [x]
                     │
Phase 2 ─────────────┤── T5 [x] ── T7 [x] ── T8 [x]
                     │
Phase 3 ─────────────┤── T9 [x] ── T10 [x] ── T11+T12 [x]
                     │
Phase 4 ─────────────┤── namespace-rename ──┐
  (sequential)       │   (dup→rename→compat)│
                     │                      ├~~ beans-integration
                     │                      │   (beans→legacy→merge)
                     │                      │
Phase 5 ─────────────┤── safety-defaults ···│·· quality-guardrails ··· context-routing
  (3 parallel)       │                      │
                     │                      │
Phase 6 ─────────────┤── agent-orchestration│··· interactive-collab ··· review-independence
  (3 parallel)       │                      │
                     │                      │
Phase 7 ─────────────┤── script-hardening ··│·· work-lifecycle ··· knowledge-pipeline ··· todo-roadmap
  (4 parallel)       │                      │
                     │                      │
Phase 8 ─────────────┘── memetic-research [terminal]
```

Legend: `[x]` done · `[ ]` TODO · `──` hard dep · `~~` inferred (foundational/merge) · `···` independent · `[terminal]` end of chain

---

## Conflict Zones

| Phase | Files | Overlapping TODOs |
|-------|-------|-------------------|
| 4 | `*` (rename touches everything) | namespace-rename must complete before beans-integration starts |
| 6 | `skills/implement.md`, `skills/shared/context-isolation.md` | agent-orchestration vs interactive-collaboration (low risk — different sections) |
| 7 | `references/`, `skills/` | knowledge-pipeline vs script-hardening (low risk — different files) |

---

## Phase 0 — Foundation — DONE

### T1: Review Implementation

Completed in commit `7808ec2`.

---

## Phase 1 — Validation & Independent Work — DONE

| Track | Result |
|-------|--------|
| T2 — E2E Test | Cancelled as redundant. Gaps captured as T10. |
| T3 — Research E2E | Fixed 7 research-flow bugs (`6874c1a`). |
| T4 — Specialist Rewrite | Rewrote 3 templates with reasoning-focused format (`2082f57`). |
| T6 — TODOS Workflow | Migrated to `todos.yaml` with schema validation and archive integration (`7024260`). |

---

## Phase 2 — Enhancement — DONE

| Track | Result |
|-------|--------|
| T5 — Gate Evaluation Rearchitecture | Isolated subagent evaluators, pre/post-step evaluation, YAML gate criteria, `decided_by` vocabulary migration. 6 commits, 34 files, net -208 lines. |
| T7 — Roadmap Process | `/harness:triage` command with triage script (`scripts/triage-todos.sh`), template system, todos.yaml schema extension (7 triage fields). |
| T8 — Parallel Workflow Support | Focused+dormant model via `.work/.focused`, 4 new functions in `hooks/lib/common.sh`, all hooks scoped, `--switch`/`--all` flags. |

---

## Phase 3 — Quality & Polish — DONE

| Track | Result |
|-------|--------|
| T9 — Triage-TODOs Harness Skill | New `/harness:triage` command replaces `/work-roadmap`. Same 10-step pipeline with AI-driven triage assessment. |
| T10 — Edge-Case Integration Tests | 80/80 assertions across 5 test suites. |
| T11+T12 — Harness UX Fixes | Summary protocol, step-aware validation, `--source-todo` flag, `.gate_policy_hint` eliminated. |

---

## Phase 4 — Foundational Infrastructure — PLANNED

**Rationale:** Both work units change the ground truth everything else builds on. The rename changes every file path in the project; beans changes the enforcement pipeline every branch merges through. Doing these first means all downstream branches are built against the final namespace and enforcement layer — no rebasing against stale names or missing enforcement hooks.

### work/namespace-rename (3 TODOs, ~2-3 sessions, sequential)
`duplication-cleanup`: Clean up file duplication and align command namespace
`rename-to-furrow`: Rename project from 'harness' to 'furrow'
`cross-platform-compatibility`: Cross-platform compatibility check
- **Key files**: `install.sh`, `*` (rename), `scripts/`, `hooks/`, `commands/lib/`
- **Conflict risk**: high — rename touches `*`, must run solo
- **Why together**: Sequential pipeline: clean up duplication first (so rename is clean), rename everything, then audit the final codebase for portability.
- **Dependencies**: `rename-to-furrow` → `duplication-cleanup`, `cross-platform-compatibility` → `rename-to-furrow`

### work/beans-integration (3 TODOs, ~1-2 sessions, sequential)
`beans-enforcement-integration`: Beans task management for enforcement layer and programmatic checks
`merge-specialist`: Add a merge specialist template (built against new enforcement layer)
`legacy-todos-migration`: Incorporate legacy TODOs into the system
- **Key files**: `hooks/gate-check.sh`, `commands/lib/step-transition.sh`, `commands/lib/init-work-unit.sh`, `specialists/merge-specialist.md`, `todos.yaml`
- **Conflict risk**: none (after namespace-rename completes)
- **Why together**: Beans changes the enforcement pipeline; merge specialist needs to know about beans status validation; legacy migration depends on beans being in place.
- **Dependencies**: `legacy-todos-migration` → `beans-enforcement-integration`

**Parallelism**: namespace-rename completes first (touches `*`), then beans-integration.

---

## Phase 5 — Safety & Quality Defaults — PLANNED

**Rationale:** All small-effort, high-value changes. Built against the renamed codebase and beans enforcement layer. Safety defaults (supervised gating, hook false positives) and quality guardrails (source hierarchy, vertical slices, model routing) that raise the bar for all subsequent work. Minimal file conflicts — 3 parallel worktrees.

### work/safety-defaults (2 TODOs, ~1 session)
`default-supervised-gating`: Default gate policy should be supervised, not auto-advance
`stop-hook-false-positives`: Handle stop hooks enforcing fluff requirements
- **Key files**: `commands/lib/step-transition.sh`, `commands/lib/init-work-unit.sh`, `.claude/harness.yaml`, `hooks/validate-summary.sh`, `hooks/stop-ideation.sh`, `hooks/lib/validate.sh`
- **Conflict risk**: none
- **Why together**: Both fix overly-permissive/rigid defaults in the same enforcement surface (hooks + step transitions).

### work/quality-guardrails (3 TODOs, ~1 session)
`research-source-guidance`: Structured guidance for primary vs secondary source research
`guard-against-horizontal-slices`: Guard against horizontal slices in decomposition
`skill-loading-visible-internals`: Skill loading exposes internals — should be seamless
- **Key files**: `skills/research.md`, `templates/research-sources.md`, `skills/decompose.md`, `skills/shared/red-flags.md`, `evals/dimensions/decompose.yaml`, `commands/lib/load-step.sh`, `commands/lib/gate-precheck.sh`
- **Conflict risk**: none
- **Why together**: All add guardrail instructions to step skills — different skills, same pattern.

### work/context-routing (2 TODOs, ~1 session)
`claude-md-docs-routing`: CLAUDE.md should reference docs routing
`sonnet-model-routing`: Use Sonnet for on-rails tasks, reserve Opus for reasoning
- **Key files**: `.claude/CLAUDE.md`, `specialists/`, `skills/implement.md`, `skills/shared/context-isolation.md`
- **Conflict risk**: none
- **Why together**: Both are routing decisions baked into ambient context — docs routing and model routing.

**Parallelism**: all 3 work units run in parallel.

---

## Phase 6 — Orchestration & Collaboration — PLANNED

**Rationale:** The two biggest capability gaps: agents aren't being dispatched (despite full infrastructure), and early steps lack genuine human collaboration. No hard file conflicts between the three tracks — orchestration touches implement.md/context-isolation.md, collaboration touches ideate/research/plan/spec skills, review touches review.md/commands.

### work/agent-orchestration (2 TODOs, ~2-3 sessions)
`parallel-agent-orchestration-adoption`: Built-in team orchestration isn't being used — diagnose and fix
`specialist-encoded-reasoning`: Specialists need encoded reasoning, not just role descriptions
- **Key files**: `skills/implement.md`, `skills/shared/context-isolation.md`, `specialists/`, `references/specialist-template.md`
- **Conflict risk**: low (skills/implement.md overlap with context-routing in Phase 5, but that lands first)
- **Why together**: Can't fix orchestration adoption without improving what gets dispatched.

### work/interactive-collaboration (2 TODOs, ~1-2 sessions)
`interactive-ideation-checkpoints`: Collaborative check-ins at pre-implementation steps
`worktree-reintegration-summary`: Produce summary for worktree reintegration
- **Key files**: `skills/ideate.md`, `skills/research.md`, `skills/plan.md`, `skills/spec.md`, `skills/shared/`, `skills/implement.md`, `skills/shared/context-isolation.md`
- **Conflict risk**: low (skills/implement.md shared with agent-orchestration — different sections)
- **Why together**: Both improve human↔agent handoff quality at different points in the workflow.

### work/review-independence (2 TODOs, ~1-2 sessions)
`fresh-session-review`: Run review in a truly fresh session (no shared context)
`brain-dump-triage-command`: Brain dump triage command to turn notes into actionable TODOs
- **Key files**: `skills/review.md`, `skills/shared/eval-protocol.md`, `commands/review.md`, `commands/`, `commands/work-todos.md`
- **Conflict risk**: none
- **Why together**: Both create new commands/workflows — review isolation and brain dump triage.

**Parallelism**: all 3 work units run in parallel.

---

## Phase 7 — Infrastructure & Knowledge — PLANNED

**Rationale:** Hardening, hygiene, and knowledge flow improvements. All independent subsystems that can run in 4 parallel worktrees. Lower urgency but collectively address operational quality and the knowledge pipeline.

### work/script-hardening (2 TODOs, ~1-2 sessions)
`script-access-restrictions`: Restrict direct access to internal/dependency scripts
`rethink-hint-file-pattern`: Rethink hint file pattern — consolidate into state.json
- **Key files**: `scripts/`, `hooks/`, `hooks/state-guard.sh`
- **Conflict risk**: none
- **Why together**: Both protect internal plumbing — script access boundaries and hint file cleanup.

### work/work-lifecycle (2 TODOs, ~1-2 sessions)
`work-folder-structure-and-cleanup`: Structure .work/ to prevent unbounded growth
`user-action-integration`: Integration points for actions the user must take
- **Key files**: `scripts/archive-work.sh`, `commands/archive.md`, `commands/lib/detect-context.sh`, `references/work-unit-layout.md`, `skills/shared/`, `commands/lib/step-transition.sh`
- **Conflict risk**: none
- **Why together**: Both extend the work unit lifecycle — directory pruning on archive, user-action tracking during execution.

### work/knowledge-pipeline (3 TODOs, ~2-3 sessions)
`seeds-concept`: Seeds as a structured knowledge reduction stage
`research-documentation-detection`: Detect when research output should be documentation instead
`design-pattern-context-construction`: Context construction driven by design pattern thinking
- **Key files**: `skills/`, `references/`, `templates/`, `docs/`, `commands/lib/promote-components.sh`, `skills/review.md`
- **Conflict risk**: low (references/ overlap with script-hardening — different files)
- **Why together**: All about how knowledge flows through the harness — reduction, routing, and assembly patterns.

### work/todo-roadmap-system (3 TODOs, ~1-2 sessions)
`todo-context-references`: TODOs with context references from dump and active sessions
`roadmap-todo-integration`: Roadmap provides tackling prompts and merges TODOs
`mine-claude-code`: Mine Claude Code for reusable patterns and capabilities
- **Key files**: `commands/work-todos.md`, `scripts/triage-todos.sh`, `todos.yaml`, `templates/roadmap.md.tmpl`
- **Conflict risk**: none
- **Why together**: All improve the TODO/roadmap pipeline — context references, tackling prompts, and CC pattern mining.

**Parallelism**: all 4 work units run in parallel.

---

## Phase 8 — Exploratory — PLANNED

**Rationale:** Pure research with no urgency. Park until there's headroom.

### work/memetic-research (standalone research unit)
`memetic-algorithms-research`: Research memetic algorithms for LLM orchestration
- **Key files**: none (research-only, no code changes expected)
- **Conflict risk**: none
- **Why standalone**: Exploratory research with uncertain practical value. No dependencies or dependents.

---

## Deferred (not yet scheduled)

| Item | Blocker |
|------|---------|
| Agent SDK adapter completion | Claude Code is the only active runtime |
| Autonomous triggering | Needs supervised/delegated modes proven |
| Observability dashboard | Needs operational data from real usage |
| Self-improvement automation | Needs eval infrastructure tested |
| Deletion testing automation | Needs eval infrastructure tested |

---

## Worktree Quick Reference

```sh
# Phase 4 — Foundational Infrastructure (sequential)
git worktree add ../wt-namespace-rename -b work/namespace-rename main
# ... complete namespace-rename, merge, then:
git worktree add ../wt-beans-integration -b work/beans-integration main

# Phase 5 — Safety & Quality Defaults (3 parallel)
git worktree add ../wt-safety-defaults    -b work/safety-defaults    main
git worktree add ../wt-quality-guardrails -b work/quality-guardrails main
git worktree add ../wt-context-routing    -b work/context-routing    main

# Phase 6 — Orchestration & Collaboration (3 parallel)
git worktree add ../wt-agent-orchestration      -b work/agent-orchestration      main
git worktree add ../wt-interactive-collaboration -b work/interactive-collaboration main
git worktree add ../wt-review-independence       -b work/review-independence       main

# Phase 7 — Infrastructure & Knowledge (4 parallel)
git worktree add ../wt-script-hardening   -b work/script-hardening   main
git worktree add ../wt-work-lifecycle     -b work/work-lifecycle     main
git worktree add ../wt-knowledge-pipeline -b work/knowledge-pipeline main
git worktree add ../wt-todo-roadmap       -b work/todo-roadmap-system main

# Merge pattern (per work unit)
git checkout main && git merge --no-ff work/{branch-name}
git worktree prune
```
