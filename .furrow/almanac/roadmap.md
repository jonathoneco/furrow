# Roadmap

> Updated: 2026-04-04 | 7 phases, 0/7 complete | 33 active TODOs across 17 rows

## Dependency DAG

```
Phase 1 (3 rows ||)
  quick-harness-fixes ──┐
  skill-quality-guards ─┼──> Phase 2 (3 rows ||)
  model-routing ────────┘      specialist-overhaul ──────┐
                               ideation-and-review-ux ───┼──> Phase 3
                               quality-and-rules ────────┘      parallel-agent-wiring
                                                                       │
                                                                       ▼
                                                                Phase 4 (2 rows ||)
                                                                  todo-pipeline ─────────────┐
                                                                  research-methodology ···   │
                                                                                             ▼
                                                                Phase 5 (2 rows ||)
                                                                  infra-cleanup ──> context-patterns ···
                                                                  cli-architecture ──┬──> almanac-and-seeds
                                                                                     └──> harness-lifecycle-ux
                                                                                     Phase 6 (3 rows ||)

                                                                Phase 7 (independent)
                                                                  audits-and-mining ··· [terminal]
                                                                  exploratory-research ··· [terminal]
```

Legend: `──` hard dep · `~~` inferred (foundational/merge) · `···` independent · `[terminal]` end of chain

## Conflict Zones

| Phase | Files | Rows affected | Severity | Mitigation |
|-------|-------|---------------|----------|------------|
| 2 | skills/implement.md | specialist-overhaul, ideation-and-review-ux | low | specialist-overhaul merges first |
| 2 | skills/shared/ | ideation-and-review-ux, quality-and-rules | low | different files within shared/ |
| 5 | bin/frw.d/hooks/, bin/frw.d/scripts/ | infra-cleanup, cli-architecture | medium | infra-cleanup merges first |
| 6 | references/, skills/ | almanac-and-seeds, context-patterns | low | different subdirectories |

## Phase 1 — Foundational Fixes & Guards — PLANNED

Small-effort, high-impact fixes with no file overlaps. Front-loads hook reliability and skill guardrails before larger refactors.

### work/quick-harness-fixes (3 TODOs, ~2 sessions)
- `stop-hook-false-positives`: Handle stop hooks enforcing fluff requirements
- `skill-loading-visible-internals`: Skill loading exposes internals — should be seamless
- `claude-md-docs-routing`: CLAUDE.md should reference docs routing
- **Key files**: bin/frw.d/hooks/validate-summary.sh, bin/frw.d/hooks/stop-ideation.sh, bin/frw.d/lib/validate.sh, bin/rws, .claude/CLAUDE.md
- **Conflict risk**: none
- **Why together**: All small hook/UX fixes in the harness plumbing layer

### work/skill-quality-guards (2 TODOs, ~1 session)
- `guard-against-horizontal-slices`: Guard against horizontal slices in decomposition
- `research-source-guidance`: Structured guidance for primary vs secondary source research
- **Key files**: skills/decompose.md, skills/shared/red-flags.md, evals/dimensions/decompose.yaml, skills/research.md, templates/research-sources.md
- **Conflict risk**: none
- **Why together**: Both add quality guardrails to step skills

### work/model-routing (1 TODO, ~1 session)
- `sonnet-model-routing`: Use Sonnet for on-rails tasks, reserve Opus for reasoning
- **Key files**: specialists/, skills/implement.md, skills/shared/context-isolation.md
- **Conflict risk**: none
- **Why together**: Single focused TODO

## Phase 2 — Specialist, Enforcement & Rules — PLANNED

Builds the quality/enforcement/specialist layer on top of Phase 1 guardrails. Three parallel rows targeting different file domains.

### work/specialist-overhaul (3 TODOs, ~3 sessions)
- `specialist-encoded-reasoning`: Specialists need encoded reasoning, not just role descriptions
- `specialist-templates-from-team-plan-not-enforced-d`: Specialist templates from team-plan not enforced during implementation
- `specialist-expansion`: Step-specific modes, new domains (frontend), rationale grounding
- **Key files**: specialists/, references/specialist-template.md, skills/implement.md, .furrow/almanac/rationale.yaml
- **Conflict risk**: low (skills/implement.md overlap with ideation-and-review-ux)
- **Why together**: All address specialist template quality and scope — format first, enforcement second, expansion third

### work/ideation-and-review-ux (2 TODOs, ~3 sessions)
- `interactive-ideation-checkpoints`: Collaborative check-ins at pre-implementation steps
- `fresh-session-review`: Run review in a truly fresh session (no shared context)
- **Key files**: skills/ideate.md, skills/research.md, skills/plan.md, skills/spec.md, skills/shared/, skills/review.md, commands/review.md
- **Conflict risk**: low (skills/implement.md overlap with specialist-overhaul)
- **Why together**: Both improve interaction quality in pre-implementation and review steps

### work/quality-and-rules (2 TODOs, ~2 sessions)
- `quality-enforcement-expansion`: PostToolUse hooks, test cases from spec, naming guidance
- `rules-strategy`: Rules strategy — harness-scoped vs project-scoped
- **Key files**: .claude/settings.json, .claude/rules/, skills/spec.md, bin/frw.d/hooks/, install.sh
- **Conflict risk**: none
- **Why together**: Both about raising the quality bar through enforcement and guidance

## Phase 3 — Agent Orchestration — PLANNED

Agent dispatch requires stable specialist templates (Phase 2) and model routing (Phase 1). Single row avoids skills/implement.md conflicts.

### work/parallel-agent-wiring (3 TODOs, ~3 sessions)
- `parallel-agent-orchestration-adoption`: Built-in team orchestration isn't being used — diagnose and fix
- `worktree-reintegration-summary`: Produce summary for worktree reintegration
- `user-action-integration`: Integration points for actions the user must take
- **Key files**: skills/implement.md, skills/shared/context-isolation.md, bin/rws
- **Conflict risk**: none
- **Why together**: All touch skills/implement.md and context-isolation.md — must be one row

## Phase 4 — Command Pipeline — PLANNED

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

## Phase 5 — Infrastructure & CLI Strategy — PLANNED

CLI architecture decision (Go vs shell, modularization) must resolve before building new almanac features or renaming verbs. Infra cleanup stabilizes folder structure.

### work/infra-cleanup (2 TODOs, ~2 sessions)
- `work-folder-structure-and-cleanup`: Structure .furrow/rows/ to prevent unbounded growth
- `script-access-restrictions`: Restrict direct access to internal/dependency scripts
- **Key files**: bin/rws, commands/archive.md, references/row-layout.md, bin/frw.d/scripts/, bin/frw.d/hooks/
- **Conflict risk**: none
- **Why together**: Both address internal infrastructure organization

### work/cli-architecture (1 TODO, ~4 sessions)
- `cli-architecture-overhaul`: CLI architecture overhaul — functionality over script routing, modularization, Go evaluation
- **Key files**: bin/alm, bin/rws, bin/sds, bin/frw.d/scripts/
- **Conflict risk**: medium (overlaps with infra-cleanup on bin/frw.d/)
- **Why together**: Single large TODO

## Phase 6 — Knowledge Architecture & Harness Identity — PLANNED

Almanac graph primitives + seeds are deeply coupled (seeds = graph nodes). Lifecycle UX (sow/reap, status line) depends on CLI strategy from Phase 5. Context patterns are independent.

### work/almanac-and-seeds (2 TODOs, ~5 sessions)
- `almanac-graph-primitives`: First-class dependency graph in almanac — deterministic DAG over LLM reasoning
- `seeds-concept`: Seeds as a structured knowledge reduction stage with dependency wiring
- **Key files**: bin/alm, .furrow/almanac/, skills/, references/, templates/
- **Conflict risk**: low (references/ overlap with context-patterns)
- **Why together**: Seeds are the nodes in the almanac graph — deeply coupled design

### work/context-patterns (1 TODO, ~2 sessions)
- `design-pattern-context-construction`: Context construction driven by design pattern thinking
- **Key files**: references/, docs/, adapters/claude-code/progressive-loading.yaml
- **Conflict risk**: low (references/ overlap with almanac-and-seeds)
- **Why together**: Single focused TODO

### work/harness-lifecycle-ux (1 TODO, ~4 sessions)
- `harness-lifecycle-ux`: sow/reap verbs, status line design, installation/exploration skill
- **Key files**: commands/, skills/, install.sh, .claude/settings.json
- **Conflict risk**: none
- **Why together**: Single large TODO

## Phase 7 — Audits & Exploration — PLANNED

Low-urgency research and audit items with no production dependencies. Insights from mining can feed back into earlier phases.

### work/audits-and-mining (4 TODOs, ~3 sessions)
- `adapters-audit`: Adapters pass — check for atrophy, modularization decay, internal consistency
- `mine-v1-harness`: Mine v1 harness for learnings, insights, and research
- `apply-nate-jones-skill`: Apply Nate Jones harness skill patterns to Furrow
- `mine-claude-code`: Mine Claude Code for reusable patterns and capabilities
- **Key files**: adapters/
- **Conflict risk**: none
- **Why together**: All are audit/mining tasks that produce insights, not code changes

### work/exploratory-research (1 TODO, ~3 sessions)
- `memetic-algorithms-research`: Research memetic algorithms for LLM orchestration
- **Key files**: (none)
- **Conflict risk**: none
- **Why together**: Single exploratory TODO

## Worktree Quick Reference

```sh
# Phase 1 — Foundational Fixes & Guards (parallel)
git worktree add ../wt-quick-harness-fixes -b work/quick-harness-fixes
git worktree add ../wt-skill-quality-guards -b work/skill-quality-guards
git worktree add ../wt-model-routing -b work/model-routing

# Phase 2 — Specialist, Enforcement & Rules (parallel)
git worktree add ../wt-specialist-overhaul -b work/specialist-overhaul
git worktree add ../wt-ideation-and-review-ux -b work/ideation-and-review-ux
git worktree add ../wt-quality-and-rules -b work/quality-and-rules

# Phase 3 — Agent Orchestration
git worktree add ../wt-parallel-agent-wiring -b work/parallel-agent-wiring

# Phase 4 — Command Pipeline (parallel)
git worktree add ../wt-todo-pipeline -b work/todo-pipeline
git worktree add ../wt-research-methodology -b work/research-methodology

# Phase 5 — Infrastructure & CLI Strategy (parallel)
git worktree add ../wt-infra-cleanup -b work/infra-cleanup
git worktree add ../wt-cli-architecture -b work/cli-architecture

# Phase 6 — Knowledge Architecture & Harness Identity (parallel)
git worktree add ../wt-almanac-and-seeds -b work/almanac-and-seeds
git worktree add ../wt-context-patterns -b work/context-patterns
git worktree add ../wt-harness-lifecycle-ux -b work/harness-lifecycle-ux

# Phase 7 — Audits & Exploration (parallel)
git worktree add ../wt-audits-and-mining -b work/audits-and-mining
git worktree add ../wt-exploratory-research -b work/exploratory-research
```
