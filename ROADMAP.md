# Roadmap

Generated from `TODOS.md` on 2026-04-02.
Arranged for maximum worktree parallelism with explicit merge points.

---

## Dependency DAG

```
                    ┌─── T4 (Specialist Rewrite) ···················── [independent]
                    │
         ┌── T2 (E2E Test) ──┬── T5 (Auto-Advance)
         │                    │
T1 ──────┤                    └── T8 (Parallel Workflows)
(done?)  │
         └── T3 (Research E2E) ·································── [terminal]
                    │
                    │    ┌── T7 (Roadmap Process) ── T9 (Triage Skill)
                    │    │
                    └── T6 (TODOS Workflow) ·····················── [independent]
```

Legend: `──` hard dependency, `···` no dependency (shown for phase alignment)

---

## File Conflict Zones

These determine which TODOs **cannot** share a worktree:

| Zone | Files | TODOs affected |
|------|-------|----------------|
| State machine | `commands/lib/step-transition.sh`, `scripts/advance-step.sh`, `scripts/record-gate.sh` | T2, T5 |
| Hooks core | `hooks/lib/common.sh`, `hooks/lib/validate.sh` | T2, T3, T8 |
| Auto-advance pipeline | `commands/lib/auto-advance.sh`, `scripts/auto-advance.sh` | T5 only |
| Command definitions | `commands/checkpoint.md`, `commands/archive.md` | T6 only |
| Hook implementations | `hooks/state-guard.sh`, `hooks/ownership-warn.sh`, `hooks/post-compact.sh` | T8 only |
| Eval scripts | `scripts/run-eval.sh`, `scripts/validate-step-artifacts.sh`, `scripts/select-dimensions.sh` | T3 only |
| Specialist templates | `specialists/*.md` | T4 only |
| Context skill | `skills/work-context.md` | T2, T8 (low conflict — T2 reads, T8 modifies) |

**Key insight**: Most conflict is in `hooks/lib/common.sh` — if T2 and T3 both discover bugs there, merging will require manual resolution. Mitigated by T1 (review) happening first.

---

## Phase 0 — Foundation (sequential)

### T1: Review Implementation — DONE

Completed in commit `7808ec2` ("review and fix 8 harness scripts").
Phase 1 is unblocked — all tracks can branch from `main` now.

---

## Phase 1 — Validation & Independent Work (4 parallel worktrees)

> Branches from: `main` (after T1 merge)
> Merge point: All four merge to `main` before Phase 2

```
main ──┬── work/e2e-test ──────────────── merge ──┐
       ├── work/research-e2e ──────────── merge ──┤
       ├── work/specialist-rewrite ────── merge ──┤
       └── work/todos-workflow ────────── merge ──┘── main
```

### Track 1a: T2 — End-to-End Test with Real Task — REDUNDANT

**Status**: Cancelled. The other Phase 1 worktrees (T3, T4, T6) inherently exercise the full pipeline as real tasks. Previous tasks on this branch (`harness-v2-status-eval`, `review-impl-scripts`) already ran the full 7-step flow and found/fixed 14 bugs. A separate meta-test is unnecessary.

**Coverage gaps** not addressed by organic pipeline usage (see TODO 10):
- Multi-deliverable dependency wave ordering (T4 has 3 independent deliverables — wave logic is trivial)
- `correction-limit.sh` enforcement (only fires on gate failures, may not happen naturally)
- `run-eval.sh` Phase B dimension scoring on real code deliverables with mixed pass/fail

**Original description**: Exercise the full 7-step pipeline (ideate→review) with a real task. Verify `validate-step-artifacts.sh` gates, `generate-plan.sh` with multi-deliverable definitions, `correction-limit.sh` during implementation, and `run-eval.sh` on actual deliverables.

### Track 1b: T3 — Research Mode End-to-End Test

**Work description**: Test the full research workflow — `--mode research` init, research.md artifact validation, deliverables/ output location, research-specific dimension selection, and Phase A/B eval on knowledge artifacts.

**Branch**: `work/research-e2e`
**Key files**: `scripts/select-dimensions.sh`, `scripts/run-eval.sh`, `scripts/validate-step-artifacts.sh`, `references/research-mode.md`, `evals/dimensions/research-*.yaml`
**Conflict risk**: Medium — shares `hooks/lib/validate.sh` with T2. Different functions likely touched.

### Track 1c: T4 — Specialist Template Rewrite

**Work description**: Rewrite `api-designer.md`, `database-architect.md`, and `test-engineer.md` to match the reasoning-focused format of `harness-engineer.md`. Each specialist gets: Domain Expertise, How This Specialist Reasons (5-8 patterns), Quality Criteria, Anti-Patterns, Context Requirements.

**Branch**: `work/specialist-rewrite`
**Key files**: `specialists/api-designer.md`, `specialists/database-architect.md`, `specialists/test-engineer.md`
**Conflict risk**: None — fully isolated directory, no shared dependencies.

### Track 1d: T6 — Formalize TODOS Workflow

**Work description**: Build a `/work-todos` or checkpoint-integrated command that generates TODOS.md at session end. Template with: title, context, work needed, risks, references. Auto-populate from summary.md open questions, learnings.jsonl pitfalls, deferred recommendations, unaddressed review findings.

**Branch**: `work/todos-workflow`
**Key files**: New command files + `commands/checkpoint.md`, `commands/archive.md`, `skills/review.md`
**Conflict risk**: Low — touches command definitions (markdown), not script logic. Only conflicts if T2 discovers bugs in checkpoint/archive flow and modifies same `.md` files.

---

## Phase 2 — Enhancement (3 parallel worktrees)

> Branches from: `main` (after Phase 1 merge)
> Merge point: All three merge to `main` before Phase 3

```
main ──┬── work/auto-advance ──────────── merge ──┐
       ├── work/parallel-workflows ────── merge ──┤
       └── work/roadmap-process ───────── merge ──┘── main
```

### Track 2a: T5 — Auto-Advance Enforcement

**Work description**: Decide and implement whether auto-advance criteria should be harness-enforced (deterministic shell checks) or evaluator-judged (prose in skills). Add testability checks if going the enforcement route. Requires E2E test data from T2 to inform the decision.

**Branch**: `work/auto-advance`
**Key files**: `commands/lib/auto-advance.sh`, `scripts/auto-advance.sh`, `skills/spec.md`
**Depends on**: T2 (needs real usage data)
**Conflict risk**: None — auto-advance pipeline is isolated.

### Track 2b: T8 — Parallel Workflow Support

**Work description**: Enable multiple active work units. Implement focused+dormant model: one unit receives context injection and hook enforcement, others are dormant. Add `--unit <name>` scoping to commands, `--switch` to `/work`, per-unit hook filtering, and context multiplexing in `work-context.md`.

**Branch**: `work/parallel-workflows`
**Key files**: `commands/lib/detect-context.sh`, `hooks/state-guard.sh`, `hooks/ownership-warn.sh`, `hooks/timestamp-update.sh`, `hooks/post-compact.sh`, `skills/work-context.md`
**Depends on**: T2 (single-task flow must be solid)
**Conflict risk**: Low — hook files are isolated from T5's auto-advance pipeline and T7's new commands.

### Track 2c: T7 — Roadmap Process

**Work description**: Build a `/work-roadmap` command that reads TODOS.md and produces prioritized ROADMAP.md. Triage (urgency/impact/effort/dependencies), group into candidate work units, sequence by dependency graph, output ordered plan startable via `/work`.

**Branch**: `work/roadmap-process`
**Key files**: New command files + templates
**Depends on**: T6 (builds on TODOS workflow)
**Conflict risk**: None — new files only, no overlap with T5 or T8.

---

## Phase 3 — Meta (sequential)

> Branches from: `main` (after Phase 2 merge)

### T9: Triage-TODOs Harness Skill

**Work description**: Automate the manual roadmap triage process as a `/harness:triage` skill. Dependency extraction from TODOS.md, file conflict analysis for worktree safety, DAG construction with critical path identification, phase grouping, branch strategy generation, and ROADMAP.md output.

**Branch**: `work/triage-todos`
**Key files**: New skill + potentially reuses `scripts/generate-plan.sh` (topological sort), `scripts/check-wave-conflicts.sh` (file conflict detection)
**Depends on**: T7 (roadmap process defines the output format)

---

## Deferred (not yet scheduled)

These items from TODOS.md are deferred until the core harness is battle-tested:

| Item | Earliest phase | Blocker |
|------|---------------|---------|
| Agent SDK adapter completion | After Phase 2 | Claude Code is the only active runtime |
| Autonomous triggering | After Phase 3 | Needs supervised/delegated modes proven |
| Observability dashboard | After Phase 3 | Needs operational data from real usage |
| Self-improvement automation | After Phase 3 | Needs eval infrastructure tested (T2/T3) |
| Deletion testing automation | After Phase 3 | Needs eval infrastructure tested |
| Phase 6 consistency review | After Phase 3 | Wait for implementation to stabilize |

---

## Worktree Quick Reference

```sh
# Phase 1 — launch all four
git worktree add ../harness-e2e-test       -b work/e2e-test          main
git worktree add ../harness-research-e2e   -b work/research-e2e      main
git worktree add ../harness-specialist     -b work/specialist-rewrite main
git worktree add ../harness-todos-wf       -b work/todos-workflow     main

# Phase 1 — merge all back (after each completes)
git checkout main && git merge --no-ff work/e2e-test
git merge --no-ff work/research-e2e
git merge --no-ff work/specialist-rewrite
git merge --no-ff work/todos-workflow

# Phase 2 — launch all three
git worktree add ../harness-auto-advance   -b work/auto-advance        main
git worktree add ../harness-parallel-wf    -b work/parallel-workflows  main
git worktree add ../harness-roadmap        -b work/roadmap-process     main

# Phase 2 — merge all back
git checkout main && git merge --no-ff work/auto-advance
git merge --no-ff work/parallel-workflows
git merge --no-ff work/roadmap-process

# Phase 3
git worktree add ../harness-triage         -b work/triage-todos        main

# Cleanup worktrees after merge
git worktree prune
```
