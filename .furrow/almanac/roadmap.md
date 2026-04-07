# Roadmap

> Updated: 2026-04-07 | 7 phases, 0/7 complete | 36 active TODOs across 19 rows

## Dependency DAG

```
Phase 1 (2 rows ||)
  model-routing-and-specialists ──┬──> parallel-agent-wiring
  infra-fixes ────────────────────┼──> dual-review-delegation
                                  └──> script-safety
                                  Phase 2 (3 rows ||)
                                         │
                                         ▼
                                  Phase 3 (2 rows ||)
                                    command-pipeline ────────┐
                                    planning-ux ···          │
                                                             ▼
                                  Phase 4 (2 rows ||)
                                    infra-cleanup ──> context-patterns
                                    cli-architecture ──┬──> almanac-and-seeds ──> sprint-and-spikes
                                                       ├──> ambient-promotion
                                                       └──> harness-lifecycle-ux
                                                       Phase 5 (3 rows ||)  Phase 6 (3 rows ||)

                                  Phase 7 (independent)
                                    audits-and-mining ··· [terminal]
                                    exploratory-research ··· [terminal]
                                    furrow-tui ··· [terminal]
```

Legend: `──` hard dep · `···` independent · `[terminal]` end of chain

## Conflict Zones

| Phase | Files | Rows | Severity | Mitigation |
|-------|-------|------|----------|------------|
| 1 | specialists/, skills/implement.md | model-routing, infra-fixes | low | model-routing merges first |
| 2 | skills/implement.md | parallel-agent-wiring, dual-review | low | parallel-agent-wiring merges first |
| 3 | commands/ | command-pipeline, planning-ux | low | different command files |
| 4 | bin/rws, bin/frw.d/ | infra-cleanup, cli-architecture | medium | infra-cleanup merges first |
| 5 | bin/alm, .furrow/almanac/ | almanac-and-seeds, ambient-promotion | medium | almanac-and-seeds merges first |

## Phase 1 — Token Optimization & Infrastructure Fixes — PLANNED

Critical token savings (40-60%) + bug fixes blocking reliable operation. Model routing + specialist expansion are coupled. Infrastructure fixes unblock CLI operation in consumer projects.

### work/model-routing-and-specialists (2 TODOs, ~3 sessions)
- `per-step-model-routing`: Orchestrator + step agent architecture, collaborate/execute split
- `specialist-expansion`: Step-specific modes, new domains (frontend), rationale grounding
- **Key files**: skills/, specialists/, skills/shared/context-isolation.md, bin/frw.d/scripts/launch-phase.sh, bin/rws
- **Conflict risk**: low
- **Why together**: Model routing needs step-specific specialist modes; deeply coupled design

### work/infra-fixes (5 TODOs, ~2 sessions)
- `consumer-project-furrow-root`: frw/rws resolve FURROW_ROOT to install dir, not consumer project
- `gate-check-hook-excluded-steps`: gate-check hook blocks transitions for excluded steps
- `specialist-templates-from-team-plan-not-enforced-d`: Specialist templates not enforced during implementation
- `config-cleanup`: Move furrow.yaml to .furrow/, add ~/.config/furrow/, wire source_todo
- `blocking-stop-hooks`: Convert stop hooks to blocking + auto-TODO on harness errors
- **Key files**: bin/frw, bin/rws, bin/sds, bin/alm, bin/frw.d/hooks/, .claude/furrow.yaml, skills/implement.md
- **Conflict risk**: low
- **Why together**: All CLI/hook fixes blocking reliable operation

## Phase 2 — Agent Orchestration & Review Enhancement — PLANNED

Agent dispatch requires model routing from Phase 1. Dual-review and script enforcement are independent but same dependency tier.

### work/parallel-agent-wiring (3 TODOs, ~3 sessions)
- `parallel-agent-orchestration-adoption`: Built-in team orchestration — diagnose and fix
- `worktree-reintegration-summary`: Produce summary for worktree reintegration
- `user-action-integration`: Integration points for user actions
- **Key files**: skills/implement.md, skills/shared/context-isolation.md, bin/rws
- **Conflict risk**: none
- **Why together**: All touch skills/implement.md + context-isolation.md

### work/dual-review-delegation (1 TODO, ~2 sessions)
- `dual-review-and-specialist-delegation`: Dual-review at plan/spec, intent-based specialist auto-delegation, new specialists
- **Key files**: skills/plan.md, skills/spec.md, specialists/, references/specialist-template.md
- **Conflict risk**: low
- **Why together**: Single TODO

### work/script-safety (1 TODO, ~2 sessions)
- `script-access-restrictions`: Restrict direct access to internal scripts
- **Key files**: bin/frw.d/scripts/, bin/frw.d/hooks/
- **Conflict risk**: none
- **Why together**: Single TODO

## Phase 3 — Command & Planning Pipeline — PLANNED

Command layer after agent wiring stabilizes. Planning UX shares commands/ but different files.

### work/command-pipeline (4 TODOs, ~3 sessions)
- `brain-dump-triage-command`: Brain dump triage command
- `todo-context-references`: TODOs with context references
- `roadmap-todo-integration`: Roadmap provides tackling prompts
- `research-documentation-detection`: Detect when research should be docs
- **Key files**: commands/, commands/work-todos.md, commands/triage.md, bin/alm
- **Conflict risk**: low
- **Why together**: All operate on the TODO/roadmap command pipeline

### work/planning-ux (3 TODOs, ~3 sessions)
- `triage-and-braindump-ideation`: Ideation loops in triage and brain dump
- `furrow-next-phase-lifecycle`: Full phase lifecycle (merge, update, handoff, launch)
- `research-methodology-design`: Systems design research methodology
- **Key files**: commands/triage.md, commands/next.md, bin/frw.d/scripts/launch-phase.sh, skills/research.md
- **Conflict risk**: low
- **Why together**: All improve planning command UX

## Phase 4 — Infrastructure & CLI Strategy — PLANNED

CLI architecture decision gates Phase 5 features. Infra cleanup stabilizes folder structure.

### work/infra-cleanup (1 TODO, ~2 sessions)
- `work-folder-structure-and-cleanup`: Structure .furrow/rows/ to prevent unbounded growth
- **Key files**: bin/rws, commands/archive.md, references/row-layout.md

### work/cli-architecture (1 TODO, ~4 sessions)
- `cli-architecture-overhaul`: Functionality over script routing, modularization, Go evaluation
- **Key files**: bin/alm, bin/rws, bin/sds, bin/frw.d/scripts/

## Phase 5 — Knowledge & Promotion — PLANNED

Seeds + almanac graph coupled (sds = graph engine). Promotion system independent but same tier.

### work/almanac-and-seeds (2 TODOs, ~5 sessions)
- `almanac-graph-primitives`: Graph infrastructure for seeds
- `seeds-concept`: Seeds as task management primitive — work graph, in-row tracking, gating
- **Key files**: bin/alm, bin/sds, .furrow/almanac/, skills/, references/

### work/ambient-promotion (1 TODO, ~4 sessions)
- `ambient-context-promotion`: Row→project→global knowledge graduation
- **Key files**: .furrow/almanac/, bin/alm, commands/lib/

### work/context-patterns (1 TODO, ~2 sessions)
- `design-pattern-context-construction`: Context construction via design patterns
- **Key files**: references/, docs/

## Phase 6 — Harness Identity & Vision — PLANNED

Longer-term vision. Lifecycle UX depends on CLI decisions. Sprint/spike depend on seed graph.

### work/harness-lifecycle-ux (1 TODO, ~4 sessions)
- `harness-lifecycle-ux`: sow/reap verbs, status line, installation skill
- **Key files**: commands/, skills/, install.sh, .claude/settings.json

### work/collaborative-surfaces (1 TODO, ~3 sessions)
- `collaborative-surfaces`: Markdown + comment threading, Notion integration
- **Key files**: skills/, adapters/

### work/sprint-and-spikes (2 TODOs, ~4 sessions)
- `sprint-inspired-planning`: Retros, velocity, multi-row coordination
- `spike-row-mode`: Implementation-flavored research with throwaway prototypes
- **Key files**: skills/, evals/dimensions/, .furrow/almanac/, commands/triage.md

## Phase 7 — Audits & Exploration — PLANNED

Low-urgency items. Insights feed back into earlier work. TUI is aspirational.

### work/audits-and-mining (5 TODOs, ~4 sessions)
- `adapters-audit`, `mine-v1-harness`, `apply-nate-jones-skill`, `mine-claude-code`, `specialist-quality-validation`
- **Key files**: adapters/, evals/, references/specialist-template.md

### work/exploratory-research (1 TODO, ~3 sessions)
- `memetic-algorithms-research`: Memetic algorithms for LLM orchestration

### work/furrow-tui (1 TODO, ~3 sessions)
- `furrow-tui-dashboard`: TUI / agent-dashboard integration

## Worktree Quick Reference

```sh
# Phase 1 — Token Optimization & Infrastructure Fixes
git worktree add ../furrow-model-routing-and-specialists -b work/model-routing-and-specialists
git worktree add ../furrow-infra-fixes -b work/infra-fixes

# Phase 2 — Agent Orchestration & Review Enhancement
git worktree add ../furrow-parallel-agent-wiring -b work/parallel-agent-wiring
git worktree add ../furrow-dual-review-delegation -b work/dual-review-delegation
git worktree add ../furrow-script-safety -b work/script-safety

# Phase 3 — Command & Planning Pipeline
git worktree add ../furrow-command-pipeline -b work/command-pipeline
git worktree add ../furrow-planning-ux -b work/planning-ux

# Phase 4 — Infrastructure & CLI Strategy
git worktree add ../furrow-infra-cleanup -b work/infra-cleanup
git worktree add ../furrow-cli-architecture -b work/cli-architecture

# Phase 5 — Knowledge & Promotion
git worktree add ../furrow-almanac-and-seeds -b work/almanac-and-seeds
git worktree add ../furrow-ambient-promotion -b work/ambient-promotion
git worktree add ../furrow-context-patterns -b work/context-patterns

# Phase 6 — Harness Identity & Vision
git worktree add ../furrow-harness-lifecycle-ux -b work/harness-lifecycle-ux
git worktree add ../furrow-collaborative-surfaces -b work/collaborative-surfaces
git worktree add ../furrow-sprint-and-spikes -b work/sprint-and-spikes

# Phase 7 — Audits & Exploration
git worktree add ../furrow-audits-and-mining -b work/audits-and-mining
git worktree add ../furrow-exploratory-research -b work/exploratory-research
git worktree add ../furrow-furrow-tui -b work/furrow-tui
```
