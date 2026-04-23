# Team Plan — post-install-hygiene

## Architecture Decisions

Grounded in `research/synthesis.md`. Each decision is traceable to a research finding.

### AD-1 — Canonical resolver reuse (not duplication)
**Research citation**: `research/cross-model-and-xdg.md` Section C quotes the full `resolve_config_value()` body at `bin/frw.d/lib/common.sh:121-144`. `bin/frw.d/lib/common.sh:121-144` already provides the three-tier chain we want (project → XDG → FURROW_ROOT). Every XDG-config consumer calls this function directly; callers handle defaults via `value=$(resolve_config_value key) || value="default"`. No new helper is created.

**Trade-off**: simplicity (reuse existing) over API ergonomics (a defaulting variant would be cleaner but adds a second helper to maintain). Rationale: the existing helper already works and is tested.

### AD-2 — Diff computation via `git log -p --no-merges`, not `git diff`
**Research citation**: `research/cross-model-and-xdg.md` Section B walks through the three git-log semantics questions and concludes `git log -p --no-merges <base>..HEAD -- <globs>` is correct for non-contiguous commits. `git diff <first>^..<last>` diffs the contiguous range and would include unrelated commits. `--follow` is omitted because it is single-path only; rename tracing is out of scope.

**Trade-off**: correctness over simplicity. `git diff <first>^..<last>` looks simpler but is wrong for non-contiguous commit selections.

### AD-3 — Schema canonicalization + migration (learnings)
**Research citation**: `research/schema-validators.md` Section E documents the exact dual-schema state — 4 rows on old (`id, timestamp, category, content, context, source_task, source_step, promoted`), only install-and-merge on new (`ts, step, kind, summary, detail, tags`). Rather than a reader that handles both (permanent dual-schema complexity), we migrate the 4 old-format rows to the new schema in a one-time commit. `schemas/learning.schema.json` + a validate-on-append hook prevents further drift.

**Trade-off**: one-time migration effort up-front vs. permanent union-reader code. Rationale (R2 decision): the row count is small (4) and the old schema was documented but silently abandoned; migration gets us to a single canonical shape.

### AD-4 — Hook registration via `.claude/settings.json` merge
**Research citation**: `research/install-artifacts.md` Section B confirms hooks are merged into `.claude/settings.json`, not symlinked to `.git/hooks`. New pre-commit hooks (script-modes, append-learning) are added to `bin/frw.d/hooks/` and registered via install.sh's merge into `.claude/settings.json`, matching the existing hook model.

**Trade-off**: consistency with existing model over alternative mechanisms.

### AD-5 — Specialist symlinks as install-time artifacts
**Research citation**: `research/install-artifacts.md` Section D quotes `bin/frw.d/install.sh:572-581` showing the glob-discovery loop (`specialists/*.md` filtered by `_*`). Section C enumerates the 22-item roster and tracked/untracked split. Unifying the 22 symlinks to "all gitignored, all install-time" matches the direction set by install-and-merge. `_meta.yaml` exists but is informational, not load-bearing — we don't promote it.

**Trade-off**: glob discovery is "magic" vs. explicit manifest is "declarative." Not changing this today keeps scope bounded.

### AD-6 — Migration script pattern (forward-looking insurance)
**Research citation**: `research/schema-validators.md` Section D confirms `find .furrow/rows -name 'reintegration*.json'` returns empty. `migrate-reintegration-evidence-path.sh` exists and is tested against a synthetic fixture, but executes as a no-op today. Rationale: making `evidence_path` required could break a future archived row if one lands before this row merges; the migration path is ready.

### AD-7 — First preferred_specialists consumer in specialist-delegation.md
**Research citation**: `research/cross-model-and-xdg.md` Section D confirms `preferred_specialists` has zero runtime consumers in grep output — it is write-only at install time. Wiring creates its first runtime consumer at decompose-time specialist selection. The lookup uses `resolve_config_value "preferred_specialists.<role>"` with fallback to existing selection logic. The config schema treats `preferred_specialists` as a map of role-name → specialist-name.

**Trade-off**: additive scope vs. leaving the field write-only. Rationale (R3 decision): a write-only field is worse UX than the small wiring cost.

## Wave Map

Wave-to-deliverable mapping rationale:

**Wave 1** — `test-isolation-guard` (root). Must land first so every subsequent deliverable's new tests use the hardened sandbox.

**Wave 2** — 6 parallel deliverables, all depending only on wave-1:
- `script-modes-fix` (19 scripts chmod, hook, 2 tests)
- `reintegration-schema-consolidation` (schema required field, validator extraction, forward-looking migration)
- `xdg-config-consumer-wiring` (resolver reuse, 3 consumer sites, first preferred_specialists consumer)
- `promote-learnings-schema-fix` (canonical schema, migration of 4 old rows, validator hook)
- `specialist-symlink-unification` (untrack 22, install-time production, self-hosting.md extension)
- `ac-10-e2e-fixture` (third merge-e2e fixture)

File-ownership overlap analysis in wave 2: all 6 deliverables touch disjoint files (verified against plan.json). The only intersection is `bin/frw.d/hooks/` — `script-modes-fix` adds `pre-commit-script-modes.sh`; `promote-learnings-schema-fix` adds `append-learning.sh`. Distinct files, no conflict.

**Wave 3** — `cross-model-per-deliverable-diff`. Depends on `xdg-config-consumer-wiring` for the resolver used by the `cross_model.provider` read at `cross-model-review.sh:79`.

## Specialist Assignments

| Deliverable | Specialist | Notes |
|---|---|---|
| test-isolation-guard | test-engineer | Produces the shared sandbox helper every other deliverable's tests consume |
| script-modes-fix | harness-engineer | File-mode metadata + hook + tests |
| reintegration-schema-consolidation | harness-engineer | Schema authority + shared validator helper |
| xdg-config-consumer-wiring | harness-engineer | Resolver adoption across 3+ consumer sites |
| promote-learnings-schema-fix | harness-engineer | Schema + migration + hook (similar shape to above) |
| specialist-symlink-unification | harness-engineer | Install-time artifact policy enforcement |
| ac-10-e2e-fixture | test-engineer | End-to-end fixture authoring; builds on wave-1 sandbox |
| cross-model-per-deliverable-diff | harness-engineer | Wave-3; adopts the resolver from wave-2 xdg work |

Total: 2 specialists (test-engineer, harness-engineer). 5 harness-engineer deliverables in wave 2 will serialize under a single specialist unless decompose dispatches parallel harness agents. Decompose step owns that decision.

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Wave-2 harness-engineer serial bottleneck | High | Medium | Decompose step dispatches N parallel harness agents; file_ownership in plan.json prevents collisions |
| Migration of 4 old learnings rows drops fields unexpectedly | Medium | Medium | Migration script writes migration-report.md per row; unmappable records flagged for manual review rather than silently dropped |
| Specialist-symlinks unification breaks 5 dependent integration tests during the untrack commit | Medium | Medium | Test-isolation-guard lands first; unification's own test-specialist-symlinks.sh exercises post-install state |
| `git log -p --no-merges -- <globs>` misses rename-tracked commits | Low | Low | Accepted; documented in AC; --follow is single-path and scope does not require it |
| Downstream rows (post this one) depend on `get_config_field` name that we chose not to introduce | Low | Low | Resolver name stays `resolve_config_value`; documented in config-resolution.md |
| Hook registration via settings.json merge conflicts with a project's existing settings.json | Low | High | install.sh already handles this path; new hooks follow the existing merge pattern |
| Learnings migration rewrites committed `learnings.jsonl` in 4 archived rows | Medium | Low | This is a normal forward commit, not history rewrite. Migration report (migration-report.md) is committed alongside so any reader can see what changed. Downstream consumers hashing the raw files must re-check. No audit-trail fields (ts, step) are modified — only fields renamed/dropped. |
| In-flight rows produce pre-evidence_path reintegration JSON → blocked at reintegration-gate after this row merges | Medium | Medium | `migrate-reintegration-evidence-path.sh` runs idempotently on any archived or in-flight row before that row's reintegration-gate. Mitigation is already shipped as the migration script (AD-6). |
| Scope expansion from R1/R2/R3 (research-time) flagged as "unplanned" at review-gate | Low | Low | Explicitly blessed in constraint #8 and in research-decisions.md. Cross-model review can confirm by reading the decisions doc. |
| Wave-3 sole-occupant adds coordination cost | Low | Low | Acceptable; keeping cross-model in wave-3 makes the dependency visible to downstream readers. Decompose step can merge waves if the harness-engineer queue allows. |

## Path forward

After plan-gate pass, spec step produces per-deliverable acceptance-criterion breakdowns for each of the 8 deliverables. Decompose step creates specialist wave assignments (likely one harness-engineer agent per wave-2 deliverable, running in parallel). Implement step runs the waves. Review step runs per-deliverable + cross-model review using the new per-deliverable diff scoping (dog-fooded on this row).

## Decompose-step additions

### Scope Analysis
- 8 deliverables, 3 waves (1 + 6 + 1).
- 2 specialist types required: `test-engineer` (2 deliverables), `harness-engineer` (6 deliverables).
- Total integration tests produced by this row: 10 new + 2 modified existing.
- File-ownership surface: 9 top-level directories touched (bin/frw.d/, bin/rws, commands/, docs/architecture/, schemas/, skills/shared/, tests/integration/, .gitignore, install.sh).

### Team Composition
- One `test-engineer` agent: owns wave-1 test-isolation-guard and wave-2 ac-10-e2e-fixture (serial within the test-engineer queue — ac-10 depends on test-isolation-guard anyway).
- Five parallel `harness-engineer` agents for wave-2 (file_ownership is disjoint). Plus a sixth `harness-engineer` agent for wave-3 cross-model-per-deliverable-diff after xdg-config-consumer-wiring completes.
- Model routing: both specialists declare `model_hint: sonnet` in their frontmatter. Decompose honors this per the resolution rule (specialist model_hint > step model_default > sonnet) — all implementation happens on sonnet.

### Task Assignment

| Deliverable | Specialist | Model | Wave | Notes |
|---|---|---|---|---|
| test-isolation-guard | test-engineer | sonnet | 1 | Root — must complete before wave-2 starts |
| script-modes-fix | harness-engineer | sonnet | 2 | Mode-only commit — no content changes |
| reintegration-schema-consolidation | harness-engineer | sonnet | 2 | **Produces** `bin/frw.d/lib/validate-json.sh` — landing order constraint below |
| xdg-config-consumer-wiring | harness-engineer | sonnet | 2 | No cross-deliverable deps within wave-2 |
| promote-learnings-schema-fix | harness-engineer | sonnet | 2 | **Consumes** `validate-json.sh` — see ordering below |
| specialist-symlink-unification | harness-engineer | sonnet | 2 | Modifies .gitignore state + install.sh |
| ac-10-e2e-fixture | test-engineer | sonnet | 2 | Depends on test-isolation-guard sandbox helper |
| cross-model-per-deliverable-diff | harness-engineer | sonnet | 3 | Depends on xdg-config's resolver adoption at cross-model-review.sh call sites |

### Coordination

**Intra-wave-2 ordering constraint (NEW from spec review)**: within wave-2, `reintegration-schema-consolidation` must land its `bin/frw.d/lib/validate-json.sh` helper BEFORE `promote-learnings-schema-fix`'s `append-learning.sh` hook calls it. The two deliverables own disjoint files so parallel authoring is safe; only the runtime call-site ordering matters. Two implementation strategies, either acceptable:
- **Strategy A (sequential within wave-2)**: `reintegration-schema-consolidation` runs first; `promote-learnings-schema-fix` starts after the helper file exists. Adds a mid-wave sync point.
- **Strategy B (parallel with stubbed helper)**: `promote-learnings-schema-fix` begins authoring immediately with the helper's interface (validate_json <schema> <doc>) assumed; merge order enforces correctness (reintegration commit merges first). No stubbing in the working tree — both specialists reference the same interface signature from `specs/reintegration-schema-consolidation.md`.

**Recommendation**: Strategy B. The interface is documented in both specs; parallel authoring reduces wall-clock time; merge ordering is a small git discipline check.

**Post-implement cross-check**: after all wave-2 deliverables land, run a consistency pass confirming:
- `validate-json.sh` exists and is sourced by `append-learning.sh` (not inlined)
- `resolve_config_value` is still the single resolver in `common.sh` (no duplicate helpers)
- `bin/frw.d/scripts/*.sh` all ship at 100755
- 22 specialist symlinks produced by install.sh, 0 tracked in git

### Skills
None required beyond the standard implement-step skills. Specialists operate within their declared domain; no cross-domain hand-offs.

### Validation
- Every deliverable in definition.yaml appears in exactly one wave in plan.json ✓
- depends_on graph respected across waves: wave-1 precedes wave-2 precedes wave-3 ✓
- file_ownership globs disjoint within each wave (verified at plan step + re-verified after adding helpers.sh to wave-1 and stop-ideation.sh to xdg-config-consumer-wiring) ✓
- Every specialist exists in `specialists/*.md` with valid frontmatter ✓
