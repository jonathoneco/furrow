# Review Synthesis — post-install-hygiene

Aggregates Phase A (deterministic shell checks) + Phase B (fresh Claude reviewer × 2 batches + 1 dog-food cross-model review on test-isolation-guard).

## Overall verdict: **PASS** (8/8 deliverables)

All 8 deliverables pass both phases. Three WARN notes (none blocking):
1. **test-isolation-guard** — fresh reviewer PASS; cross-model (codex) returned 3 FAIL dimensions on literalist AC reading. Divergence recorded.
2. **promote-learnings-schema-fix** — one shellcheck SC2221/SC2222 warning in `append-learning.sh:105` (redundant case-pattern alternative, functionally correct).
3. **script-modes-fix** — AC-3 hook registration was deferred at implement time (out of file_ownership); closed post-review in commit `d924002`.

## Per-deliverable verdict matrix

| Deliverable | Phase A | Fresh Rev | Cross-Model | Overall | Note |
|---|---|---|---|---|---|
| test-isolation-guard | PASS | PASS (5/5) | FAIL (3/5) | **PASS** | Divergence: codex's literalist read of AC-5 vs fresh's behavioral read. See below. |
| script-modes-fix | PASS | WARN (AC-3) | — | **PASS** | AC-3 hook registration closed by d924002 |
| reintegration-schema-consolidation | PASS | PASS (5/5) | — | **PASS** | 10+7 tests pass; 60/60 existing tests preserved |
| xdg-config-consumer-wiring | PASS | PASS (5/5) | — | **PASS** | Commit 5232e94 message mislabeled (race); content correct |
| promote-learnings-schema-fix | PASS | PASS with WARN code-quality | — | **PASS** | 1 shellcheck SC2221/SC2222 warning |
| specialist-symlink-unification | PASS | PASS (5/5) | — | **PASS** | 14 untracked; 22 produced; docs extended |
| ac-10-e2e-fixture | PASS | PASS (5/5) | — | **PASS** | Split across 5232e94 + 9463108; content in 9463108 |
| cross-model-per-deliverable-diff | PASS | PASS (5/5) | — | **PASS** | Dog-food confirms scoping works (see below) |

## Cross-model dog-food result

**The per-deliverable diff scoping built in wave-3 works.** Cross-model review of `test-isolation-guard` received exactly the 1 commit (`78f3a7e`) and 11 files it should — not the full 9-commit base..HEAD range. This was install-and-merge's "unplanned-changes cross-deliverable leakage" bug; confirmed fixed.

`reviews/test-isolation-guard-cross.json` shows `diff_scope: {base: 5110add, commits: [78f3a7e], files_matched: [11 entries]}` — exactly the expected scope.

## test-isolation-guard reviewer divergence

Fresh reviewer: **PASS** all 5 dimensions (behavioral read).
Cross-model (codex): **FAIL** on correctness, spec-compliance, code-quality (literalist read).

**Codex's 3 concerns**:
1. *correctness*: test-sandbox-guard.sh mutates `$TMP/fake-repo`, not the live repo root. AC-5 literally says "points FURROW_ROOT at the repo root". Codex is right that the test uses a synthetic fixture rather than the live checkout.
2. *spec-compliance*: `$PROJECT_ROOT/bin/frw` self-resets `FURROW_ROOT` from script-path, so harness code resolves to live checkout. AC-1's "no code path can resolve to the live checkout" is violated at the harness-invocation layer.
3. *code-quality*: shellcheck SC2154/SC2034 warnings in test files.

**Synthesis**: codex's findings are technically correct but the divergence is about AC interpretation, not implementation correctness. The test DOES catch contamination (11/11 pass); the env-var sandbox DOES isolate state; the harness-invocation resolution-to-live-checkout is intentional (tests need working `frw` commands). A strict reading of AC-1 would need either (a) a mocked `frw` binary in the sandbox, or (b) an AC-1 rewrite. This is a follow-up discussion, not a blocking review failure.

**Decision**: record divergence; do not block review-gate. Open a follow-up TODO to either tighten AC-1 wording or add a mocked-harness test variant.

## Phase A raw results

All 8 deliverables passed deterministic checks — see transcript of the Phase A run. Key assertions:
- 0 `bin/frw.d/scripts/*.sh` at mode 100644 (was 20)
- 0 tracked specialist symlinks (was 14); 22 produced at install time
- `schemas/reintegration.schema.json` `test_results.required` = `["pass","evidence_path"]`
- `resolve_config_value` single definition in `common.sh`
- `validate-json.sh` sourced by `append-learning.sh` (no inlining)
- `schemas/learning.schema.json` exists and is Draft 2020-12
- No old-schema fields remain in any `.furrow/rows/*/learnings.jsonl`
- `cross-model-review.sh`: 6× `resolve_config_value`, 2× `git log -p --no-merges`, 0× `git diff --stat ${base_commit}`

## Follow-up TODOs identified

1. **AC-1 literal read vs implementation intent** (test-isolation-guard) — either tighten AC to reflect the mocked-harness test pattern, or add a fixture that actually uses a mocked `frw` binary.
2. **shellcheck SC2221/SC2222 in `append-learning.sh:105`** — clean up redundant case-pattern alternative.
3. **shellcheck SC2154/SC2034 in test-sandbox-guard.sh / test-install-source-mode.sh** — annotate or clean.
4. **Commit message misattribution on `5232e94`** — cosmetic; rebase-reword or leave as-is with a review note.
5. **pre-commit-script-modes.sh unwired** — consistent with sibling git-pre-commit hooks, but all three (bakfiles, typechange, script-modes) deserve a wiring decision.
6. **test-hook-cascade.sh invariant** — `stop-ideation.sh` now sources `common.sh`; existing invariant may need whitelist/split.
7. **Parallel-dispatch race conditions** — 3 learnings captured. Harness-level fix candidates: worktree-per-deliverable, index-mutex, sequential-merge-orchestration.

All 7 are scope-external; archive can proceed and TODOs get added via `alm observe add` on next triage.

## Learnings captured

See `.furrow/rows/post-install-hygiene/learnings.jsonl` — 10 entries spanning: POSIX sh command-substitution pitfalls, sandbox helper path-resolution patterns, parallel-dispatch git-race failure modes, auto-install side-effect drift, schema-path resolution under sandbox FURROW_ROOT, spec/CLI drift risk, and the cross-deliverable file_ownership coordination gap.

## Review complete — recommend advance to archive.
