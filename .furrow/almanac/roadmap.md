# Roadmap

> Updated: 2026-04-07 | 6 phases, 0/6 complete | 26 active TODOs across 14 rows

## Dependency DAG

```
Phase 1 (2 rows ||)
  model-routing-and-specialists ──┐
  infra-bug-fixes ────────────────┼──> Phase 2 (2 rows ||)
                                  │      parallel-agent-wiring ──┐
                                  └──>   script-safety ···       │
                                                                 ▼
                                                          Phase 3 (2 rows ||)
                                                            todo-pipeline ──────────┐
                                                            research-methodology ···│
                                                                                    ▼
                                                          Phase 4 (2 rows ||)
                                                            infra-cleanup ──> context-patterns
                                                            cli-architecture ──┬──> almanac-and-seeds
                                                                               └──> harness-lifecycle-ux
                                                                               Phase 5 (3 rows ||)

                                                          Phase 6 (independent)
                                                            audits-and-mining ··· [terminal]
                                                            exploratory-research ··· [terminal]
```

Legend: `──` hard dep · `~~` inferred (foundational/merge) · `···` independent · `[terminal]` end of chain

## Conflict Zones

| Phase | Files | Rows affected | Severity | Mitigation |
|-------|-------|---------------|----------|------------|
| 1 | specialists/, skills/implement.md | model-routing-and-specialists, infra-bug-fixes | low | model-routing merges first |
| 2 | bin/frw.d/ | parallel-agent-wiring, script-safety | low | different files |
| 4 | bin/rws, bin/frw.d/scripts/ | infra-cleanup, cli-architecture | medium | infra-cleanup merges first |
| 5 | references/, skills/ | almanac-and-seeds, context-patterns | low | different subdirectories |

## Phase 1 — Token Optimization & Infrastructure Fixes — PLANNED

Critical token optimization must land first — orchestrator/step-agent architecture saves 40-60% cost. Model routing needs step-specific specialist modes (coupled design). Bug fixes unblock reliable CLI operation in consumer projects.

### work/model-routing-and-specialists (2 TODOs, ~3 sessions)
- `per-step-model-routing`: Per-step model routing — Opus for reasoning, Sonnet for execution
- `specialist-expansion`: Step-specific modes, new domains (frontend), rationale grounding
- **Key files**: skills/, specialists/, skills/shared/context-isolation.md, bin/frw.d/scripts/launch-phase.sh, bin/rws
- **Conflict risk**: low
- **Why together**: Model routing needs step-specific specialist modes; specialist expansion needs model hints. Deeply coupled.

### work/infra-bug-fixes (3 TODOs, ~2 sessions)
- `consumer-project-furrow-root`: frw/rws resolve FURROW_ROOT to install dir, not consumer project root
- `gate-check-hook-excluded-steps`: gate-check hook blocks transitions for excluded steps
- `specialist-templates-from-team-plan-not-enforced-d`: Specialist templates not enforced during implementation
- **Key files**: bin/frw, bin/rws, bin/sds, bin/alm, bin/frw.d/hooks/gate-check.sh, skills/implement.md
- **Conflict risk**: low
- **Why together**: All are CLI/hook bug fixes blocking reliable operation

## Phase 2 — Agent Orchestration & Enforcement — PLANNED

Agent dispatch requires stable specialist templates and model routing from Phase 1. Script restrictions add enforcement before infrastructure restructure.

### work/parallel-agent-wiring (3 TODOs, ~3 sessions)
- `parallel-agent-orchestration-adoption`: Built-in team orchestration isn't being used — diagnose and fix
- `worktree-reintegration-summary`: Produce summary for worktree reintegration
- `user-action-integration`: Integration points for actions the user must take
- **Key files**: skills/implement.md, skills/shared/context-isolation.md, bin/rws
- **Conflict risk**: none
- **Why together**: All touch skills/implement.md and context-isolation.md — must be one row

### work/script-safety (1 TODO, ~2 sessions)
- `script-access-restrictions`: Restrict direct access to internal/dependency scripts
- **Key files**: bin/frw.d/scripts/, bin/frw.d/hooks/
- **Conflict risk**: none
- **Why together**: Single focused TODO

## Phase 3 — Command Pipeline — PLANNED

Command layer changes after agent wiring stabilizes skills/. Research methodology is independent but logically grouped.

### work/todo-pipeline (4 TODOs, ~3 sessions)
- `brain-dump-triage-command`: Brain dump triage command to turn notes into actionable TODOs
- `todo-context-references`: TODOs with context references from dump and active sessions
- `roadmap-todo-integration`: Roadmap provides tackling prompts and merges TODOs
- `research-documentation-detection`: Detect when research output should be documentation instead
- **Key files**: commands/, commands/work-todos.md, commands/triage.md, commands/next.md, bin/alm, skills/review.md
- **Conflict risk**: none
- **Why together**: All operate on the TODO/roadmap command pipeline

### work/research-methodology (1 TODO, ~1 session)
- `research-methodology-design`: Research methodology for systems design — beyond naive web search
- **Key files**: skills/research.md, templates/research-sources.md
- **Conflict risk**: none
- **Why together**: Single focused TODO

## Phase 4 — Infrastructure & CLI Strategy — PLANNED

CLI architecture decision (Go vs shell, modularization) must resolve before building new almanac features or renaming verbs. Infra cleanup stabilizes folder structure.

### work/infra-cleanup (1 TODO, ~2 sessions)
- `work-folder-structure-and-cleanup`: Structure .furrow/rows/ to prevent unbounded growth
- **Key files**: bin/rws, commands/archive.md, references/row-layout.md
- **Conflict risk**: none
- **Why together**: Single focused TODO

### work/cli-architecture (1 TODO, ~4 sessions)
- `cli-architecture-overhaul`: CLI architecture overhaul — functionality over script routing, modularization, Go evaluation
- **Key files**: bin/alm, bin/rws, bin/sds, bin/frw.d/scripts/
- **Conflict risk**: medium (overlaps with infra-cleanup on bin/)
- **Why together**: Single large TODO

## Phase 5 — Knowledge Architecture & Harness Identity — PLANNED

Almanac graph + seeds are deeply coupled (seeds = graph nodes, sds = graph engine). Lifecycle UX depends on CLI strategy from Phase 4. Context patterns are independent.

### work/almanac-and-seeds (2 TODOs, ~5 sessions)
- `almanac-graph-primitives`: Graph infrastructure for seeds — storage, querying, visualization
- `seeds-concept`: Seeds as the task management primitive — work graph, in-row tracking, gating
- **Key files**: bin/alm, bin/sds, .furrow/almanac/, skills/, references/, templates/
- **Conflict risk**: low
- **Why together**: Seeds are the nodes in the almanac graph — deeply coupled design

### work/context-patterns (1 TODO, ~2 sessions)
- `design-pattern-context-construction`: Context construction driven by design pattern thinking
- **Key files**: references/, docs/, adapters/claude-code/progressive-loading.yaml
- **Conflict risk**: low
- **Why together**: Single focused TODO

### work/harness-lifecycle-ux (1 TODO, ~4 sessions)
- `harness-lifecycle-ux`: sow/reap verbs, status line design, installation/exploration skill
- **Key files**: commands/, skills/, install.sh, .claude/settings.json
- **Conflict risk**: none
- **Why together**: Single large TODO

## Phase 6 — Audits & Exploration — PLANNED

Low-urgency research and audit items with no production dependencies. Insights feed back into earlier work.

### work/audits-and-mining (5 TODOs, ~4 sessions)
- `adapters-audit`: Adapters pass — check for atrophy, modularization decay, internal consistency
- `mine-v1-harness`: Mine v1 harness for learnings, insights, and research
- `apply-nate-jones-skill`: Apply Nate Jones harness skill patterns to Furrow
- `mine-claude-code`: Mine Claude Code for reusable patterns and capabilities
- `specialist-quality-validation`: Establish a validation mechanism for specialist template quality
- **Key files**: adapters/, evals/, references/specialist-template.md
- **Conflict risk**: none
- **Why together**: All are audit/mining tasks that produce insights, not code changes

### work/exploratory-research (1 TODO, ~3 sessions)
- `memetic-algorithms-research`: Research memetic algorithms for LLM orchestration
- **Key files**: (none)
- **Conflict risk**: none
- **Why together**: Single exploratory TODO

## Worktree Quick Reference

```sh
# Phase 1 — Token Optimization & Infrastructure Fixes (parallel)
git worktree add ../furrow-model-routing-and-specialists -b work/model-routing-and-specialists
git worktree add ../furrow-infra-bug-fixes -b work/infra-bug-fixes

# Phase 2 — Agent Orchestration & Enforcement (parallel)
git worktree add ../furrow-parallel-agent-wiring -b work/parallel-agent-wiring
git worktree add ../furrow-script-safety -b work/script-safety

# Phase 3 — Command Pipeline (parallel)
git worktree add ../furrow-todo-pipeline -b work/todo-pipeline
git worktree add ../furrow-research-methodology -b work/research-methodology

# Phase 4 — Infrastructure & CLI Strategy (parallel)
git worktree add ../furrow-infra-cleanup -b work/infra-cleanup
git worktree add ../furrow-cli-architecture -b work/cli-architecture

# Phase 5 — Knowledge Architecture & Harness Identity (parallel)
git worktree add ../furrow-almanac-and-seeds -b work/almanac-and-seeds
git worktree add ../furrow-context-patterns -b work/context-patterns
git worktree add ../furrow-harness-lifecycle-ux -b work/harness-lifecycle-ux

# Phase 6 — Audits & Exploration (parallel)
git worktree add ../furrow-audits-and-mining -b work/audits-and-mining
git worktree add ../furrow-exploratory-research -b work/exploratory-research
```
