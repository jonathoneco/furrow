# Roadmap

> Last updated: 2026-04-03 | 6 phases, 0/6 complete

## Dependency DAG (active items only)

```
Phase 1 (parallel) ···················· Phase 2 (parallel) ─── Phase 3 ─── Phase 4 ─── Phase 5 (parallel) ─── Phase 6
┌─────────────────────┐  ┌──────────────────────┐
│ quick-harness-fixes  │  │ ideation-and-review-ux│
│ skill-quality-guards │  │ specialist-overhaul   │     parallel-       todo-        ┌─ infra-cleanup ──┐    research-
│ model-routing        │  └──────────────────────┘     agent-wiring    pipeline      │ knowledge-arch.  │    exploration
└─────────────────────┘                                                              └──────────────────┘
       ···                        ~~                       ~~              ~~                ~~                  ···
```

Legend: `──` hard dep · `~~` inferred (foundational/merge) · `···` independent · `[terminal]` end of chain

## File Conflict Zones

| Zone | Files | TODOs affected |
|------|-------|----------------|
| skills/ broad | skills/*.md, skills/shared/ | interactive-ideation-checkpoints, seeds-concept, skill-loading-visible-internals |
| hooks/ | hooks/*.sh, hooks/lib/ | stop-hook-false-positives, script-access-restrictions |
| skills/implement.md | skills/implement.md, skills/shared/context-isolation.md | parallel-agent-orchestration-adoption, sonnet-model-routing, worktree-reintegration-summary |
| commands/ | commands/*.md | brain-dump-triage-command, todo-context-references, roadmap-todo-integration |

## Phase 1 — Quick Wins & Foundational Guards — PLANNED

Small-effort, high-impact fixes that don't conflict with each other. Front-loads quick wins to improve daily workflow before larger refactors.

### work/quick-harness-fixes (3 TODOs, ~2 sessions)
stop-hook-false-positives: Handle stop hooks enforcing fluff requirements
skill-loading-visible-internals: Skill loading exposes internals — should be seamless
claude-md-docs-routing: CLAUDE.md should reference docs routing
- **Key files**: hooks/validate-summary.sh, hooks/stop-ideation.sh, hooks/lib/validate.sh, bin/rws, .claude/CLAUDE.md
- **Conflict risk**: none
- **Why together**: All address rough edges in the harness shell — hooks, skill loading, and docs routing

### work/skill-quality-guards (2 TODOs, ~1 session)
guard-against-horizontal-slices: Guard against horizontal slices in decomposition
research-source-guidance: Structured guidance for primary vs secondary source research
- **Key files**: skills/decompose.md, skills/shared/red-flags.md, evals/dimensions/decompose.yaml, skills/research.md, templates/research-sources.md
- **Conflict risk**: none
- **Why together**: Both add guardrails to step skills without structural changes

### work/model-routing (1 TODO, ~1 session)
sonnet-model-routing: Use Sonnet for on-rails tasks, reserve Opus for reasoning
- **Key files**: specialists/, skills/implement.md, skills/shared/context-isolation.md
- **Conflict risk**: none
- **Why together**: Single TODO, own branch for clean merge

## Phase 2 — Skill Layer UX — PLANNED

Deeper skill and specialist improvements that build on the Phase 1 guardrails. Two parallel rows targeting different file domains.

### work/ideation-and-review-ux (2 TODOs, ~3 sessions)
interactive-ideation-checkpoints: Collaborative check-ins at pre-implementation steps
fresh-session-review: Run review in a truly fresh session (no shared context)
- **Key files**: skills/ideate.md, skills/research.md, skills/plan.md, skills/spec.md, skills/shared/, skills/review.md, skills/shared/eval-protocol.md, commands/review.md
- **Conflict risk**: low (with specialist-overhaul — different file domains)
- **Why together**: Both improve agent-user collaboration quality at step boundaries

### work/specialist-overhaul (2 TODOs, ~2 sessions)
specialist-encoded-reasoning: Specialists need encoded reasoning, not just role descriptions
specialist-templates-from-team-plan-not-enforced-d: Specialist templates not enforced during implementation
- **Key files**: specialists/, references/specialist-template.md, skills/implement.md
- **Conflict risk**: low (skills/implement.md overlap with ideation row — coordinate merge order)
- **Why together**: Both address the specialist subsystem end-to-end

## Phase 3 — Agent Orchestration — PLANNED

Wiring up parallel agent execution, worktree handoffs, and user-action integration. All touch skills/implement.md and context-isolation.md — must be one row.

### work/parallel-agent-wiring (3 TODOs, ~3 sessions)
parallel-agent-orchestration-adoption: Built-in team orchestration isn't being used — diagnose and fix
worktree-reintegration-summary: Produce summary for worktree reintegration
user-action-integration: Integration points for actions the user must take
- **Key files**: skills/implement.md, skills/shared/context-isolation.md, bin/rws
- **Conflict risk**: none (single row)
- **Why together**: All three address how agents coordinate during implementation — overlapping files make parallelism unsafe

## Phase 4 — CLI & Command Pipeline — PLANNED

Improvements to the TODO extraction, triage, and roadmap generation pipeline. All operate on commands/ and bin/alm.

### work/todo-pipeline (4 TODOs, ~3 sessions)
brain-dump-triage-command: Brain dump triage command to turn notes into actionable TODOs
todo-context-references: TODOs with context references from dump and active sessions
roadmap-todo-integration: Roadmap provides tackling prompts and merges TODOs
research-documentation-detection: Detect when research output should be documentation instead
- **Key files**: commands/, commands/work-todos.md, commands/triage.md, commands/next.md, commands/lib/promote-components.sh, bin/alm, skills/review.md
- **Conflict risk**: none (single row)
- **Why together**: All improve the TODO lifecycle — extraction, triage, roadmap, and promotion

## Phase 5 — Structure & Knowledge Architecture — PLANNED

Infrastructure cleanup and the largest conceptual TODO (seeds). Two parallel rows with different file domains.

### work/infra-cleanup (2 TODOs, ~2 sessions)
work-folder-structure-and-cleanup: Structure .furrow/rows/ to prevent unbounded growth
script-access-restrictions: Restrict direct access to internal/dependency scripts
- **Key files**: bin/rws, commands/archive.md, references/row-layout.md, scripts/, hooks/
- **Conflict risk**: none
- **Why together**: Both address harness infrastructure hygiene

### work/knowledge-architecture (2 TODOs, ~4+ sessions)
design-pattern-context-construction: Context construction driven by design pattern thinking
seeds-concept: Seeds as a structured knowledge reduction stage
- **Key files**: references/, docs/, skills/, templates/
- **Conflict risk**: low (broad skills/ touch — schedule after Phase 2 skills work)
- **Why together**: Both reimagine how knowledge flows through the harness

## Phase 6 — Research & Exploration — PLANNED

Low-urgency research items deferred to last. No production dependencies.

### work/research-exploration (2 TODOs, ~3+ sessions)
mine-claude-code: Mine Claude Code for reusable patterns and capabilities
memetic-algorithms-research: Research memetic algorithms for LLM orchestration
- **Key files**: (research output only — no production files)
- **Conflict risk**: none
- **Why together**: Both are open-ended research with no production file changes

## Worktree Quick Reference

```sh
# Phase 1 — Quick Wins & Foundational Guards (parallel)
git worktree add ../wt-quick-harness-fixes -b work/quick-harness-fixes
git worktree add ../wt-skill-quality-guards -b work/skill-quality-guards
git worktree add ../wt-model-routing -b work/model-routing

# Phase 2 — Skill Layer UX (parallel)
git worktree add ../wt-ideation-and-review-ux -b work/ideation-and-review-ux
git worktree add ../wt-specialist-overhaul -b work/specialist-overhaul

# Phase 3 — Agent Orchestration
git worktree add ../wt-parallel-agent-wiring -b work/parallel-agent-wiring

# Phase 4 — CLI & Command Pipeline
git worktree add ../wt-todo-pipeline -b work/todo-pipeline

# Phase 5 — Structure & Knowledge Architecture (parallel)
git worktree add ../wt-infra-cleanup -b work/infra-cleanup
git worktree add ../wt-knowledge-architecture -b work/knowledge-architecture

# Phase 6 — Research & Exploration
git worktree add ../wt-research-exploration -b work/research-exploration
```
