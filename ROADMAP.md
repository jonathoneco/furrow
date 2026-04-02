# Roadmap

Updated 2026-04-02. Phase 1 complete. Arranged for worktree parallelism.

---

## Dependency DAG (active items only)

```
         ┌── T5 (Auto-Advance) ·····················── [terminal]
         │
Phase 2 ─┤── T8 (Parallel Workflows) ···············── [terminal]
         │
         └── T7 (Roadmap Process) ── T9 (Triage Skill)

Independent ─┬── T10 (Integration Tests) ···········── [terminal]
             ├── T11 (Summary Section Fix) ··········── [terminal]
             └── T12 (Source-TODO Auto-Populate) ····── [terminal]
```

Legend: `──` hard dependency, `···` no dependency

---

## File Conflict Zones (Phase 2+)

| Zone | Files | TODOs affected |
|------|-------|----------------|
| Auto-advance pipeline | `commands/lib/auto-advance.sh`, `scripts/auto-advance.sh`, `skills/spec.md` | T5 only |
| Hook implementations | `hooks/state-guard.sh`, `hooks/ownership-warn.sh`, `hooks/post-compact.sh`, `hooks/timestamp-update.sh` | T8 only |
| Context/detection | `commands/lib/detect-context.sh`, `skills/work-context.md` | T8 only |
| Step transition | `commands/lib/step-transition.sh` | T10, T11 (low — T10 tests it, T11 modifies gate logic) |
| Summary/regen | `scripts/regenerate-summary.sh`, `hooks/validate-summary.sh` | T11 only |
| Init flow | `commands/lib/init-work-unit.sh` | T12 only |
| Eval scripts | `scripts/run-eval.sh`, `hooks/correction-limit.sh`, `scripts/generate-plan.sh` | T10 only |
| Roadmap/todos | `commands/work-todos.md`, `todos.yaml` | T7 only |

**No conflicts between Phase 2 tracks** (T5, T7, T8 touch disjoint file sets).

---

## Phase 0 — Foundation — DONE

### T1: Review Implementation

Completed in commit `7808ec2`.

---

## Phase 1 — Validation & Independent Work — DONE

All four tracks merged to main.

| Track | Result |
|-------|--------|
| T2 — E2E Test | Cancelled as redundant. Gaps captured as T10. |
| T3 — Research E2E | Fixed 7 research-flow bugs (`6874c1a`). |
| T4 — Specialist Rewrite | Rewrote 3 templates with reasoning-focused format (`2082f57`). |
| T6 — TODOS Workflow | Migrated to `todos.yaml` with schema validation and archive integration (`7024260`). |

**Lessons from Phase 1**:
- T3 found real bugs in `run-eval.sh`, `select-dimensions.sh`, `auto-advance.sh`, `step-transition.sh`, `promote-components.sh`, `skills/plan.md` — Phase 2 work should re-read these files as they've changed since the original TODO descriptions were written.
- T6 replaced `TODOS.md` with `todos.yaml` — T7 and T9 descriptions need to reference `todos.yaml`, not `TODOS.md`.
- Merge conflicts arose because T4 and T6 branched before T2/T3 merged. Phase 2 should merge from updated main to avoid this.

---

## Phase 2 — Enhancement (3 parallel worktrees)

> Branches from: `main` (current, after all Phase 1 merges)
> Merge point: All three merge to `main` before Phase 3

```
main ──┬── work/auto-advance ──────────── merge ──┐
       ├── work/parallel-workflows ────── merge ──┤
       └── work/roadmap-process ───────── merge ──┘── main
```

### Track 2a: T5 — Auto-Advance Enforcement

**Work description**: Decide and implement whether auto-advance criteria should be harness-enforced (deterministic shell checks) or evaluator-judged (prose in skills). Add testability checks if going the enforcement route.

**Branch**: `work/auto-advance`
**Key files**: `commands/lib/auto-advance.sh`, `scripts/auto-advance.sh`, `skills/spec.md`
**Conflict risk**: None — auto-advance pipeline is isolated.
**Note**: T3 modified `commands/lib/auto-advance.sh` — re-read before starting.

### Track 2b: T8 — Parallel Workflow Support — DONE

Focused+dormant model via `.work/.focused` file. 4 new functions in `hooks/lib/common.sh`,
all hooks scoped, `--switch` flag on `/work`, `--all` flag on `/status`. 7 commits, 12 files.
Merged to main.

### Track 2c: T7 — Roadmap Process

**Work description**: Build a `/work-roadmap` command that reads `todos.yaml` and produces prioritized ROADMAP.md. Triage (urgency/impact/effort/dependencies), group into candidate work units, sequence by dependency graph, output ordered plan startable via `/work`.

**Branch**: `work/roadmap-process`
**Key files**: New command files + templates. Reads `todos.yaml` (not the old `TODOS.md`).
**Depends on**: T6 (done — `todos.yaml` and schema now exist).
**Conflict risk**: None — new files only, no overlap with T5 or T8.

---

## Phase 3 — Meta + Fixes (parallel where possible)

> Branches from: `main` (after Phase 2 merge)

```
main ──┬── work/triage-todos ──────────── merge ──┐
       ├── work/integration-tests ─────── merge ──┤
       ├── work/summary-fix ───────────── merge ──┤
       └── work/source-todo-init ──────── merge ──┘── main
```

### Track 3a: T9 — Triage-TODOs Harness Skill

**Work description**: Automate the manual roadmap triage process as a `/harness:triage` skill. Dependency extraction from `todos.yaml`, file conflict analysis for worktree safety, DAG construction, phase grouping, branch strategy generation, and ROADMAP.md output.

**Branch**: `work/triage-todos`
**Key files**: New skill + reuses `scripts/generate-plan.sh` (topological sort), `scripts/check-wave-conflicts.sh` (file conflict detection)
**Depends on**: T7 (roadmap process defines the output format)

### Track 3b: T10 — Edge-Case Integration Tests

**Work description**: Shell-based integration tests for 5 untested edge-case code paths: multi-wave plan generation, correction limit enforcement, Phase B mixed verdicts, gate failure correction increment, and conditional pass carry-forward.

**Branch**: `work/integration-tests`
**Key files**: New `scripts/run-integration-tests.sh` + test fixtures. Tests (reads) `scripts/generate-plan.sh`, `hooks/correction-limit.sh`, `scripts/run-eval.sh`, `commands/lib/step-transition.sh`, `commands/lib/load-step.sh`
**Conflict risk**: Low — new test files, only reads existing scripts. May discover bugs requiring fixes in tested files.

### Track 3c: T11 — Summary Section Population Fix

**Work description**: Fix `validate-summary.sh` repeatedly firing because agent-written summary.md sections (Key Findings, Open Questions, Recommendations) are never populated. Either add shared skill instructions or make validation a pre-gate blocker.

**Branch**: `work/summary-fix`
**Key files**: `scripts/regenerate-summary.sh`, `hooks/validate-summary.sh`, `skills/shared/` (new fragment), `commands/lib/step-transition.sh`
**Conflict risk**: Low — summary scripts are isolated. Minor overlap with T10 on `step-transition.sh` but different sections.

### Track 3d: T12 — Source-TODO Auto-Populate in /work Init

**Work description**: Auto-populate `source_todo` field in `definition.yaml` when starting work from a `todos.yaml` entry. Add `--source-todo` or `--from-todo` flag to init flow.

**Branch**: `work/source-todo-init`
**Key files**: `commands/lib/init-work-unit.sh`, `adapters/shared/schemas/definition.schema.yaml`
**Conflict risk**: None — init flow is isolated.

---

## Deferred (not yet scheduled)

| Item | Earliest phase | Blocker |
|------|---------------|---------|
| Agent SDK adapter completion | After Phase 3 | Claude Code is the only active runtime |
| Autonomous triggering | After Phase 3 | Needs supervised/delegated modes proven |
| Observability dashboard | After Phase 3 | Needs operational data from real usage |
| Self-improvement automation | After Phase 3 | Needs eval infrastructure tested |
| Deletion testing automation | After Phase 3 | Needs eval infrastructure tested |
| Phase 6 consistency review | After Phase 3 | Wait for implementation to stabilize |

---

## Worktree Quick Reference

```sh
# Phase 2 — launch all three
git worktree add ../harness-auto-advance   -b work/auto-advance        main
git worktree add ../harness-parallel-wf    -b work/parallel-workflows  main
git worktree add ../harness-roadmap        -b work/roadmap-process     main

# Phase 2 — merge all back
git checkout main && git merge --no-ff work/auto-advance
git merge --no-ff work/parallel-workflows
git merge --no-ff work/roadmap-process

# Phase 3 — launch all four
git worktree add ../harness-triage         -b work/triage-todos        main
git worktree add ../harness-int-tests      -b work/integration-tests   main
git worktree add ../harness-summary-fix    -b work/summary-fix         main
git worktree add ../harness-source-todo    -b work/source-todo-init    main

# Cleanup
git worktree prune
```
