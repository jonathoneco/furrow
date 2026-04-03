# Roadmap

> Updated: 2026-04-02 | 8 phases, 4/8 complete | 30 TODOs across 13 rows

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
Phase 4 ─────────────┤── namespace-rename [x] ──┐
  (IN PROGRESS)      │   (dup→rename→compat)    │
                     │                          ├── supervised-gating
                     │                          │   (foundational)
                     │                          ├~~ beans-integration
                     │                          │   (beans→merge-spec→legacy)
                     │                          │
Phase 5 ─────────────┤── safety-defaults ··· quality-guardrails ··· context-routing ··· interactive-collab
  (4 parallel)       │
                     │
Phase 6 ─────────────┤── agent-orchestration ··· review-independence
  (2 parallel)       │
                     │
Phase 7 ─────────────┤── script-hardening ··· work-lifecycle ··· knowledge-pipeline ··· todo-roadmap
  (4 parallel)       │
                     │
Phase 8 ─────────────┘── memetic-research [terminal]
```

Legend: `[x]` done · `[ ]` TODO · `──` hard dep · `~~` inferred (foundational/merge) · `···` independent · `[terminal]` end of chain

---

## Conflict Zones

| Phase | Files | Overlapping TODOs |
|-------|-------|-------------------|
| 4 | `step-transition.sh`, `init-row.sh` | supervised-gating then beans-integration (sequential due to file overlap) |
| 5 | `skills/research.md` | quality-guardrails vs interactive-collaboration (low risk — different sections) |
| 5 | `skills/implement.md`, `skills/shared/context-isolation.md` | context-routing vs interactive-collaboration (low risk — different sections) |
| 6 | `skills/implement.md`, `skills/shared/context-isolation.md` | agent-orchestration (low risk — lands after Phase 5) |
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
| T7 — Roadmap Process | `/furrow:triage` command with triage via `alm triage`, template system, todos.yaml schema extension (7 triage fields). |
| T8 — Parallel Workflow Support | Focused+dormant model via `.furrow/rows/.focused`, 4 new functions in `bin/frw.d/lib/common.sh`, all hooks scoped, `--switch`/`--all` flags. |

---

## Phase 3 — Quality & Polish — DONE

| Track | Result |
|-------|--------|
| T9 — Triage-TODOs Harness Skill | New `/furrow:triage` command replaces `/work-roadmap`. Same 10-step pipeline with AI-driven triage assessment. |
| T10 — Edge-Case Integration Tests | 80/80 assertions across 5 test suites. |
| T11+T12 — Harness UX Fixes | Summary protocol, step-aware validation, `--source-todo` flag, `.gate_policy_hint` eliminated. |

---

## Phase 4 — Foundational Infrastructure — IN PROGRESS

**Rationale:** These rows change the ground truth everything else builds on. The rename changed every file path; supervised gating ensures all subsequent rows actually pause for user review at step boundaries; beans changes the enforcement pipeline every branch merges through.

### work/namespace-rename (3 TODOs) — DONE

| TODO | Result |
|------|--------|
| `duplication-cleanup` | Cleaned up file duplication and aligned command namespace |
| `rename-to-furrow` | Renamed project from 'harness' to 'furrow' across all files |
| `cross-platform-compatibility` | Cross-platform shell portability fixes for macOS/WSL |

Completed across commits `e2e268e`..`4500bab`. Row archived at `c2482ed`.

### work/supervised-gating (1 TODO, ~1 session)
`default-supervised-gating`: Default gate policy should be supervised with structural enforcement
- **Key files**: `commands/lib/step-transition.sh`, `commands/lib/init-row.sh`, `.claude/furrow.yaml`, step skills
- **Conflict risk**: low (step-transition.sh shared with beans-integration, but different changes)
- **Why here**: The namespace-rename row proved supervised mode has no structural enforcement — the agent steamrolled from research through implement without pausing. Every subsequent row benefits from this fix landing first.

### work/beans-integration (3 TODOs, ~1-2 sessions, sequential)
`beans-enforcement-integration`: Beans task management for enforcement layer and programmatic checks
`merge-specialist`: Add a merge specialist template (built against new enforcement layer)
`legacy-todos-migration`: Incorporate legacy TODOs into the system
- **Key files**: `bin/frw.d/hooks/gate-check.sh`, `commands/lib/step-transition.sh`, `commands/lib/init-row.sh`, `specialists/merge-specialist.md`, `todos.yaml`
- **Conflict risk**: none (after supervised-gating completes)
- **Why together**: Beans changes the enforcement pipeline; merge specialist needs to know about beans status validation; legacy migration depends on beans being in place.
- **Dependencies**: `legacy-todos-migration` → `beans-enforcement-integration`

**Parallelism**: supervised-gating first (foundational), then beans-integration.

---

## Phase 5 — Safety, Quality & Collaboration — PLANNED

**Rationale:** High-value changes built against the renamed codebase and supervised gating. Quality guardrails raise the bar for all subsequent work. Interactive collaboration is promoted here because making early steps genuinely collaborative compounds across every future row. Four parallel worktrees with low-risk file overlaps on different sections.

### work/safety-defaults (1 TODO, ~1 session)
`stop-hook-false-positives`: Handle stop hooks enforcing fluff requirements
- **Key files**: `bin/frw.d/hooks/validate-summary.sh`, `bin/frw.d/hooks/stop-ideation.sh`, `bin/frw.d/lib/validate.sh`
- **Conflict risk**: none
- **Why standalone**: Fix hook false positives that block valid work.

### work/quality-guardrails (3 TODOs, ~1 session)
`research-source-guidance`: Structured guidance for primary vs secondary source research
`guard-against-horizontal-slices`: Guard against horizontal slices in decomposition
`skill-loading-visible-internals`: Skill loading exposes internals — should be seamless
- **Key files**: `skills/research.md`, `templates/research-sources.md`, `skills/decompose.md`, `skills/shared/red-flags.md`, `evals/dimensions/decompose.yaml`, `commands/lib/load-step.sh`, `commands/lib/gate-precheck.sh`
- **Conflict risk**: low (`skills/research.md` overlap with interactive-collaboration — different sections)
- **Why together**: All add guardrail instructions to step skills — different skills, same pattern.

### work/context-routing (2 TODOs, ~1 session)
`claude-md-docs-routing`: CLAUDE.md should reference docs routing
`sonnet-model-routing`: Use Sonnet for on-rails tasks, reserve Opus for reasoning
- **Key files**: `.claude/CLAUDE.md`, `specialists/`, `skills/implement.md`, `skills/shared/context-isolation.md`
- **Conflict risk**: low (`skills/implement.md` overlap with interactive-collaboration — different sections)
- **Why together**: Both are routing decisions baked into ambient context — docs routing and model routing.

### work/interactive-collaboration (2 TODOs, ~1-2 sessions)
`interactive-ideation-checkpoints`: Collaborative check-ins at pre-implementation steps
`worktree-reintegration-summary`: Produce summary for worktree reintegration
- **Key files**: `skills/ideate.md`, `skills/research.md`, `skills/plan.md`, `skills/spec.md`, `skills/shared/`, `skills/implement.md`, `skills/shared/context-isolation.md`
- **Conflict risk**: low (shared files with quality-guardrails and context-routing — different sections)
- **Why together**: Both improve human↔agent handoff quality at different points in the workflow.

**Parallelism**: all 4 rows run in parallel.

---

## Phase 6 — Orchestration & Review — PLANNED

**Rationale:** The two biggest remaining capability gaps: agents aren't being dispatched (despite full infrastructure), and review lacks true independence. With interactive collaboration landing in Phase 5, this phase focuses on the agent-side orchestration and process isolation.

### work/agent-orchestration (2 TODOs, ~2-3 sessions)
`parallel-agent-orchestration-adoption`: Built-in team orchestration isn't being used — diagnose and fix
`specialist-encoded-reasoning`: Specialists need encoded reasoning, not just role descriptions
- **Key files**: `skills/implement.md`, `skills/shared/context-isolation.md`, `specialists/`, `references/specialist-template.md`
- **Conflict risk**: low (skills/implement.md modified in Phase 5, but those changes land first)
- **Why together**: Can't fix orchestration adoption without improving what gets dispatched.

### work/review-independence (2 TODOs, ~1-2 sessions)
`fresh-session-review`: Run review in a truly fresh session (no shared context)
`brain-dump-triage-command`: Brain dump triage command to turn notes into actionable TODOs
- **Key files**: `skills/review.md`, `skills/shared/eval-protocol.md`, `commands/review.md`, `commands/`, `commands/work-todos.md`
- **Conflict risk**: none
- **Why together**: Both create new commands/workflows — review isolation and brain dump triage.

**Parallelism**: both rows run in parallel.

---

## Phase 7 — Infrastructure & Knowledge — PLANNED

**Rationale:** Hardening, hygiene, and knowledge flow improvements. All independent subsystems that can run in 4 parallel worktrees. Lower urgency but collectively address operational quality and the knowledge pipeline.

### work/script-hardening (2 TODOs, ~1-2 sessions)
`script-access-restrictions`: Restrict direct access to internal/dependency scripts
`rethink-hint-file-pattern`: Rethink hint file pattern — consolidate into state.json
- **Key files**: `bin/frw.d/scripts/`, `bin/frw.d/hooks/`, `bin/frw.d/hooks/state-guard.sh`
- **Conflict risk**: none
- **Why together**: Both protect internal plumbing — script access boundaries and hint file cleanup.

### work/work-lifecycle (2 TODOs, ~1-2 sessions)
`work-folder-structure-and-cleanup`: Structure .furrow/rows/ to prevent unbounded growth
`user-action-integration`: Integration points for actions the user must take
- **Key files**: `commands/archive.md`, `references/row-layout.md`, `skills/shared/`, `bin/rws`
- **Conflict risk**: none
- **Why together**: Both extend the row lifecycle — directory pruning on archive, user-action tracking during execution.

### work/knowledge-pipeline (3 TODOs, ~2-3 sessions)
`seeds-concept`: Seeds as a structured knowledge reduction stage
`research-documentation-detection`: Detect when research output should be documentation instead
`design-pattern-context-construction`: Context construction driven by design pattern thinking
- **Key files**: `skills/`, `references/`, `templates/`, `docs/`, `commands/lib/promote-components.sh`, `skills/review.md`
- **Conflict risk**: low (references/ overlap with script-hardening — different files)
- **Why together**: All about how knowledge flows through Furrow — reduction, routing, and assembly patterns.

### work/todo-roadmap-system (3 TODOs, ~1-2 sessions)
`todo-context-references`: TODOs with context references from dump and active sessions
`roadmap-todo-integration`: Roadmap provides tackling prompts and merges TODOs
`mine-claude-code`: Mine Claude Code for reusable patterns and capabilities
- **Key files**: `commands/work-todos.md`, `bin/alm`, `todos.yaml`, `templates/roadmap.md.tmpl`
- **Conflict risk**: none
- **Why together**: All improve the TODO/roadmap pipeline — context references, tackling prompts, and CC pattern mining.

**Parallelism**: all 4 rows run in parallel.

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
# Phase 4 — Foundational Infrastructure
# namespace-rename: DONE
# supervised-gating next:
git worktree add ../wt-supervised-gating -b work/supervised-gating main
# ... complete, merge, then:
git worktree add ../wt-beans-integration -b work/beans-integration main

# Phase 5 — Safety, Quality & Collaboration (4 parallel)
git worktree add ../wt-safety-defaults          -b work/safety-defaults          main
git worktree add ../wt-quality-guardrails       -b work/quality-guardrails       main
git worktree add ../wt-context-routing          -b work/context-routing          main
git worktree add ../wt-interactive-collaboration -b work/interactive-collaboration main

# Phase 6 — Orchestration & Review (2 parallel)
git worktree add ../wt-agent-orchestration -b work/agent-orchestration main
git worktree add ../wt-review-independence -b work/review-independence main

# Phase 7 — Infrastructure & Knowledge (4 parallel)
git worktree add ../wt-script-hardening   -b work/script-hardening   main
git worktree add ../wt-work-lifecycle     -b work/work-lifecycle     main
git worktree add ../wt-knowledge-pipeline -b work/knowledge-pipeline main
git worktree add ../wt-todo-roadmap       -b work/todo-roadmap-system main

# Merge pattern (per row)
git checkout main && git merge --no-ff work/{branch-name}
git worktree prune
```
