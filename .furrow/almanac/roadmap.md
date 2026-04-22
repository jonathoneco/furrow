# Roadmap

> Last updated: 2026-04-22 | 7 phases, 0/7 complete | 39 active TODOs across 15 rows | config-cleanup folded into Phase 1

## Dependency DAG (active items only)

```
Phase 1 — Install & Merge Foundation
  install-and-merge-foundation  ── (foundational) ──┐
                                                    │
Phase 2 — Almanac Graph & Seeds                     ▼
  almanac-and-seeds  ~~ (foundational) ─────────┬───┴──┐
  ambient-promotion  ~~ (foundational) ─────────┤      │
                                                │      │
Phase 3 — Review & Specialist System             │      │
  review-unification  ~~ (merge-impl) ───────┐  │      │
  specialist-quality  ···                    │  │      │
                                             ▼  ▼      ▼
Phase 4 — Command Pipeline & Planning UX
  command-pipeline  ~~ (merge-impl) ──────────┐
  planning-ux  ~~ (merge-impl) ───────────────┤
                                              ▼
Phase 5 — CLI Architecture & Folder Cleanup
  cli-architecture  ~~ (merge-impl) ──────────┐
  folder-structure  ~~ (foundational) ────────┤
                                              ▼
Phase 6 — Orchestration & Lifecycle
  orchestration-polish     ···  [terminal]
  sprint-and-spikes        ···  [terminal]
  harness-lifecycle-ux     ···  [terminal]
  collaborative-surfaces   ···  [terminal]

Phase 7 — Audits & Exploration
  audits-and-mining        ···  [terminal]
  exploratory-research     ···  [terminal]
  furrow-tui               ···  [terminal]
```

Legend: `──` hard dep · `~~` inferred (foundational/merge) · `···` independent · `[terminal]` end of chain

## File Conflict Zones

| Zone | Files | Rows affected | Severity | Mitigation |
|------|-------|---------------|----------|------------|
| Phase 2 | `.furrow/almanac/`, `bin/alm` | almanac-and-seeds, ambient-promotion | medium | almanac-and-seeds merges first |
| Phase 5 | `bin/rws`, `bin/frw.d/` | cli-architecture, folder-structure | medium | cli-architecture merges first |
| Phase 6 | `skills/`, `commands/` | orchestration-polish, harness-lifecycle-ux | low | different subsystems within shared dirs |

## Phase 1 — Install & Merge Foundation — PLANNED

Recurring commit/merge issues across this repo and consumer projects. One coherent install story: self-hosting hygiene, the `~/.config/furrow/` tier, merge-process skill, and post-merge validation. Folded `config-cleanup` in from Phase 5 because the 3-tier config resolution chain is inseparable from install-architecture decisions.

### work/install-and-merge-foundation (4 TODOs, ~5 sessions)

- `install-architecture-overhaul` — Install architecture overhaul — self-hosting, symlink hygiene, commit safety
- `config-cleanup` — Configuration cleanup — ~/.config/furrow/ tier, 3-tier resolution chain, migration path
- `merge-process-skill` — Design a /furrow:merge skill — reconcile worktree branches back into main
- `post-merge-watch-list` — Post-merge watch-list — track behavioral signals to validate after rows merge

- **Key files**: `install.sh`, `bin/frw.d/install.sh`, `bin/frw.d/scripts/launch-phase.sh`, `bin/frw.d/hooks/`, `bin/frw.d/lib/common.sh`, `bin/frw`, `commands/`, `commands/next.md`, `.furrow/`
- **Conflict risk**: none
- **Why together**: All four address the same structural pain — the install/config/merge/validate pipeline. Landing them on one branch keeps self-hosting, the 3-tier config chain, and merge hygiene coherent. `~/.config/furrow/` is arguably the cleanest answer to "install writes too many files into the project": if shared specialists and promotion targets live in `~/.config/furrow/`, consumers don't need to symlink them at all, eliminating half the broken-target symlink problem.

## Phase 2 — Almanac Graph & Seeds — PLANNED

Foundational graph primitives and promotion system. Many downstream TODOs reference seed graph and almanac primitives. almanac-and-seeds merges first (shared `bin/alm` surface).

### work/almanac-and-seeds (2 TODOs, ~5 sessions)

- `almanac-graph-primitives`
- `seeds-concept`

- **Key files**: `bin/alm`, `bin/sds`, `.furrow/almanac/`, `skills/`, `references/`
- **Conflict risk**: medium (with ambient-promotion on `.furrow/almanac/` and `bin/alm`)
- **Why together**: Seed graph IS the almanac graph engine — one cohesive primitive.

### work/ambient-promotion (1 TODO, ~4 sessions)

- `ambient-context-promotion`

- **Key files**: `.furrow/almanac/`, `bin/alm`, `commands/lib/`
- **Conflict risk**: medium
- **Why together**: Standalone promotion system; kept separate for independent pacing.

## Phase 3 — Review & Specialist System — PLANNED

Unify review machinery and raise specialist quality bar before downstream command changes consume reviews and specialists.

### work/review-unification (2 TODOs, ~3 sessions)

- `unified-isolated-review`
- `gate-dimension-deduplication`

- **Key files**: `bin/frw.d/scripts/cross-model-review.sh`, `skills/review.md`, `skills/ideate.md`, `skills/shared/eval-protocol.md`, `commands/review.md`, `evals/gates/`, `evals/dimensions/`
- **Conflict risk**: low
- **Why together**: Both restructure how reviews are invoked and how gate dimensions compose — one branch keeps the review contract consistent.

### work/specialist-quality (3 TODOs, ~3 sessions)

- `specialist-template-warning-escalation`
- `specialist-quality-validation`
- `apply-nate-jones-skill`

- **Key files**: `specialists/`, `references/specialist-template.md`, `skills/implement.md`
- **Conflict risk**: low
- **Why together**: All three address the specialist quality bar — template enforcement, validation, and skill application patterns.

## Phase 4 — Command Pipeline & Planning UX — PLANNED

Command layer matures after agent wiring, reviews, and graph primitives stabilize. Planning UX shares `commands/` but different files.

### work/command-pipeline (5 TODOs, ~3 sessions)

- `brain-dump-triage-command`
- `todo-context-references`
- `roadmap-todo-integration`
- `research-documentation-detection`
- `decision-review-todo-type`

- **Key files**: `commands/`, `commands/work-todos.md`, `commands/triage.md`, `commands/next.md`, `bin/alm`, `skills/review.md`
- **Conflict risk**: low
- **Why together**: Command-surface changes for brain-dump, TODO, and roadmap flow — consolidate for atomic UX.

### work/planning-ux (3 TODOs, ~3 sessions)

- `triage-and-braindump-ideation`
- `furrow-next-phase-lifecycle`
- `research-methodology-design`

- **Key files**: `commands/triage.md`, `commands/next.md`, `bin/frw.d/scripts/launch-phase.sh`, `skills/research.md`
- **Conflict risk**: low
- **Why together**: Planning-loop ergonomics across triage, next-phase handoff, and research methodology.

## Phase 5 — CLI Architecture & Folder Cleanup — PLANNED

CLI architecture decision gates downstream lifecycle UX. cli-architecture merges first to stabilize `bin/` boundaries before folder restructure.

### work/cli-architecture (3 TODOs, ~4 sessions)

- `cli-architecture-overhaul`
- `cli-breakup-script-guard`
- `register-deliverable-command`

- **Key files**: `bin/alm`, `bin/rws`, `bin/sds`, `bin/frw.d/scripts/`, `bin/frw.d/hooks/script-guard.sh`
- **Conflict risk**: medium
- **Why together**: All three restructure the CLI surface — overhauling architecture, breaking up the guard, and filling a command gap.

### work/folder-structure (1 TODO, ~2 sessions)

- `work-folder-structure-and-cleanup`

- **Key files**: `bin/rws`, `commands/archive.md`, `references/row-layout.md`
- **Conflict risk**: low
- **Why together**: Single-TODO row; focused on `.furrow/rows/` growth management. (config-cleanup moved to Phase 1 since it's fundamentally about install architecture.)

## Phase 6 — Orchestration & Lifecycle — PLANNED

Polish orchestration patterns, add sprint/spike modes, and land lifecycle-UX verb renames. Four rows run in parallel; mostly distinct subsystems.

### work/orchestration-polish (5 TODOs, ~3 sessions)

- `parallel-agent-orchestration-adoption`
- `re-evaluate-dispatch-enforcement`
- `worktree-reintegration-summary`
- `user-action-integration`
- `effort-selection-alongside-model`

- **Key files**: `skills/implement.md`, `skills/shared/context-isolation.md`, `bin/rws`, `specialists/`, `references/specialist-template.md`
- **Conflict risk**: low
- **Why together**: All refine the orchestrator/dispatch lifecycle and its knobs.

### work/sprint-and-spikes (2 TODOs, ~4 sessions)

- `sprint-inspired-planning`
- `spike-row-mode`

- **Key files**: `skills/`, `evals/dimensions/`, `.furrow/almanac/`, `commands/triage.md`
- **Conflict risk**: low
- **Why together**: Both are planning-mode variants.

### work/harness-lifecycle-ux (1 TODO, ~4 sessions)

- `harness-lifecycle-ux`

- **Key files**: `commands/`, `skills/`, `install.sh`, `.claude/settings.json`
- **Conflict risk**: low

### work/collaborative-surfaces (1 TODO, ~3 sessions)

- `collaborative-surfaces`

- **Key files**: `skills/`, `adapters/`
- **Conflict risk**: none

## Phase 7 — Audits & Exploration — PLANNED

Low-urgency items. Insights feed back into earlier work. TUI is aspirational.

### work/audits-and-mining (3 TODOs, ~4 sessions)

- `adapters-audit`
- `mine-v1-harness`
- `mine-claude-code`

- **Key files**: `adapters/`, `evals/`, `references/specialist-template.md`
- **Conflict risk**: none

### work/exploratory-research (2 TODOs, ~3 sessions)

- `memetic-algorithms-research`
- `design-pattern-context-construction`

- **Key files**: `references/`, `docs/`
- **Conflict risk**: none

### work/furrow-tui (1 TODO, ~3 sessions)

- `furrow-tui-dashboard`

- **Conflict risk**: none

## Worktree Quick Reference

```sh
# Phase 1 — Install & Merge Foundation
git worktree add ../furrow-install-and-merge-foundation -b work/install-and-merge-foundation

# Phase 2 — Almanac Graph & Seeds
git worktree add ../furrow-almanac-and-seeds -b work/almanac-and-seeds
git worktree add ../furrow-ambient-promotion -b work/ambient-promotion

# Phase 3 — Review & Specialist System
git worktree add ../furrow-review-unification -b work/review-unification
git worktree add ../furrow-specialist-quality -b work/specialist-quality

# Phase 4 — Command Pipeline & Planning UX
git worktree add ../furrow-command-pipeline -b work/command-pipeline
git worktree add ../furrow-planning-ux -b work/planning-ux

# Phase 5 — CLI Architecture & Folder Cleanup
git worktree add ../furrow-cli-architecture -b work/cli-architecture
git worktree add ../furrow-folder-structure -b work/folder-structure

# Phase 6 — Orchestration & Lifecycle
git worktree add ../furrow-orchestration-polish -b work/orchestration-polish
git worktree add ../furrow-sprint-and-spikes -b work/sprint-and-spikes
git worktree add ../furrow-harness-lifecycle-ux -b work/harness-lifecycle-ux
git worktree add ../furrow-collaborative-surfaces -b work/collaborative-surfaces

# Phase 7 — Audits & Exploration
git worktree add ../furrow-audits-and-mining -b work/audits-and-mining
git worktree add ../furrow-exploratory-research -b work/exploratory-research
git worktree add ../furrow-furrow-tui -b work/furrow-tui
```
