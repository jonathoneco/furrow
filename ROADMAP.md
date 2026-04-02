# Roadmap

> Updated: 2026-04-02 | 4 phases, 3/4 complete

---

## Dependency DAG

```
Phase 0 ── T1 [x] ──┐
                     │
Phase 1 ─────────────┤── T2 [x] ── T3 [x] ── T4 [x] ── T6 [x]
                     │
Phase 2 ─────────────┤── T5 [x] ── T7 [x] ── T8 [x]
                     │
Phase 3 ─────────────┘── T9 [ ] || T10 [ ] || T11+T12 [ ]
```

Legend: `[x]` done, `[ ]` TODO, `──` depends on, `||` parallel

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

## Phase 3 — Quality & Polish (3 parallel worktrees) — PLANNED

**Rationale:** All remaining TODOs are independent with zero file conflicts. T11+T12 combined as small-effort UX fixes sharing the "improve existing harness flows" theme. Quick wins front-loaded by urgency.

```
main ──┬── work/harness-ux-fixes ──────── merge ──┐
       ├── work/triage-todos ──────────── merge ──┤
       └── work/integration-tests ─────── merge ──┘── main
```

### Track 3a: T9 — Triage-TODOs Harness Skill

**Work description**: Automate the manual roadmap triage process as a `/harness:triage` skill. Wraps `scripts/triage-todos.sh` output with Claude-driven triage assessment, phase grouping, and ROADMAP.md generation. Reuses T7's command output format.

- **Branch**: `work/triage-todos`
- **Key files**: New skill file + reuses `scripts/triage-todos.sh`, `scripts/check-wave-conflicts.sh`
- **Conflict risk**: None — new files only
- **Effort**: medium | **Impact**: low | **Urgency**: low

### Track 3b: T10 — Edge-Case Integration Tests

**Work description**: Shell-based integration tests for 5 untested edge-case code paths: multi-wave plan generation (Kahn's cycle detection), correction limit enforcement (glob matching), Phase B mixed verdicts, gate failure correction increment, and conditional pass carry-forward.

- **Branch**: `work/integration-tests`
- **Key files**: New `scripts/run-integration-tests.sh` + test fixtures. Tests (reads) `scripts/generate-plan.sh`, `hooks/correction-limit.sh`, `scripts/check-artifacts.sh`, `commands/lib/step-transition.sh`, `commands/lib/load-step.sh`
- **Conflict risk**: Low — new test files, only reads existing scripts
- **Effort**: medium | **Impact**: medium | **Urgency**: medium

### Track 3c: T11+T12 — Harness UX Fixes

**Work description**: Two small fixes combined into one worktree.

**T11 — Summary Section Population Fix**: Fix `validate-summary.sh` repeatedly firing because agent-written summary.md sections (Key Findings, Open Questions, Recommendations) are never populated at step boundaries. Either add a shared skill fragment or make validation a pre-gate blocker.

**T12 — Source-TODO Auto-Populate**: Auto-populate `source_todo` field in `definition.yaml` when starting work from a `todos.yaml` entry. Add `--source-todo` or `--from-todo` flag to `commands/lib/init-work-unit.sh`.

- **Branch**: `work/harness-ux-fixes`
- **Key files (T11)**: `scripts/regenerate-summary.sh`, `hooks/validate-summary.sh`, `skills/shared/` (new fragment), `commands/lib/step-transition.sh`
- **Key files (T12)**: `commands/lib/init-work-unit.sh`, `adapters/shared/schemas/definition.schema.yaml`
- **Conflict risk**: None — T11 and T12 touch disjoint files
- **Effort**: small | **Impact**: medium | **Urgency**: high (T11 fires every session)

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
# Phase 3 — launch all three
git worktree add ../harness-ux-fixes    -b work/harness-ux-fixes    main
git worktree add ../harness-triage      -b work/triage-todos        main
git worktree add ../harness-int-tests   -b work/integration-tests   main

# Phase 3 — merge all back
git checkout main && git merge --no-ff work/harness-ux-fixes
git merge --no-ff work/triage-todos
git merge --no-ff work/integration-tests

# Cleanup
git worktree prune
```
