# Research Synthesis — post-install-hygiene

Consolidates findings from four parallel explorer agents covering the 8 deliverables. Full per-topic detail is in sibling files (`test-infrastructure.md`, `schema-validators.md`, `cross-model-and-xdg.md`, `install-artifacts.md`).

## Per-deliverable state of play

### 1. test-isolation-guard
- Existing tests largely *do* use `mktemp -d` + per-test `FURROW_ROOT`/`XDG_STATE_HOME`/`XDG_CONFIG_HOME` (verified in test-install-idempotency.sh, test-install-xdg-override.sh, test-upgrade-idempotency.sh).
- **Helper exists**: `tests/integration/helpers.sh` provides `setup_test_env()` and `setup_fixture()`. No unified pre/post snapshot mechanism.
- Live-worktree mutation likely came from a subset of tests not using the helpers — the audit must be per-test to identify which ones.
- No centralized `run-all.sh`; each test is self-contained. The pre/post guard should go into `helpers.sh` and be invoked via `EXIT` trap.

### 2. rescue-sh-exec-fix
- Problem confirmed: `bin/frw.d/scripts/rescue.sh` is 100644.
- **Scope is bigger than the TODO suggested**: **19 of 30** scripts under `bin/frw.d/scripts/` are 100644. Only 11 are 100755. Rescue is the one that fails because it's the one that gets exec'd without going through `sh`, but the other 18 are latent bugs.
- Hook registration model: hooks go through `.claude/settings.json` merge (not `.git/hooks` symlinks). A "pre-commit hook" is declared in settings.json.
- No existing script-mode validator among the 14 hooks.

### 3. cross-model-per-deliverable-diff
- Current `bin/frw.d/scripts/cross-model-review.sh:116` passes `git diff --stat <base>..HEAD` — no per-deliverable scoping. 4 call sites total (79, 280, 446, 631) for cross_model.provider reads.
- `deliverable` arg already threaded through; just unused for diff.
- Reference impl for reading `file_ownership` from definition.yaml via yq exists at `bin/frw.d/scripts/check-artifacts.sh:77-106`.
- **AC is technically wrong**: definition.yaml currently says "via 'git diff <first>^..<last>' or equivalent combined diff". That syntax diffs the contiguous range, not just matching commits. Use `git log -p --no-merges <base>..HEAD -- <globs>` instead.
- `--follow` is single-path only; multi-glob tracing won't follow renames. Acceptable per ACs.

### 4. reintegration-schema-consolidation
- `Draft202012Validator` subprocess pattern lives at `bin/frw.d/scripts/validate-definition.sh:36-55`, not `get-reintegration-json.sh` as originally assumed. Same pattern either way — extract to shared helper.
- `generate-reintegration.sh` inline jq block at lines 357-396 only checks required fields + enum const + basic types. Misses nested object validation, `additionalProperties`, ISO-8601 date validation.
- Schema currently has only `pass` in `test_results.required`; `evidence_path` is optional.
- **Archived-row back-compat is a no-op**: `find .furrow/rows -name 'reintegration*.json'` returns empty. The migration AC simplifies to "migration script exists + test creates a synthetic pre-migration file to verify it works."

### 5. xdg-config-consumer-wiring
- **Resolver already exists**: `resolve_config_value()` at `bin/frw.d/lib/common.sh:121-144` implements the exact three-tier chain (project → XDG → FURROW_ROOT). Definition AC proposed a new `get_config_field` — we should use/rename/wrap the existing one, not add a second.
- Four cross-model-review.sh call sites need rewiring to the resolver (79, 280, 446, 631).
- `bin/rws:117-124` `read_gate_policy()` and `bin/frw.d/hooks/stop-ideation.sh` read definition.yaml only, hardcoded fallbacks; no XDG.
- **`preferred_specialists` has ZERO consumers.** Grep returns only the schema definition + test fixtures. Wiring it means *creating* a new consumer in `skills/shared/specialist-delegation.md` — this is additive scope, not an audit of existing consumers.
- `docs/architecture/config-resolution.md` already documents the three-tier chain. Section needs updating, not creating.

### 6. promote-learnings-schema-fix
- **Two incompatible schemas in production**: 4 rows use old (`id, timestamp, category, content, context, source_task, source_step, promoted`), only `install-and-merge` uses new (`ts, step, kind, summary, detail, tags`).
- `commands/lib/promote-learnings.sh` reads old-schema fields only — correct for 4 rows, wrong for 1.
- **Original AC's "update script to read new schema" is a half-fix**: it'd flip which rows display correctly.
- `skills/shared/learnings-protocol.md` documents only the OLD format. The newer format in install-and-merge is undocumented drift.
- No learnings-write hook exists — nothing prevents further drift.

### 7. specialist-symlink-unification
- 22 specialists, 14 tracked, 8 gitignored. Confirmed. All targets resolve.
- `specialists/_meta.yaml` exists — but `install.sh` uses glob-based discovery (`specialists/*.md` minus `_*`), not the manifest. `_meta.yaml` is not load-bearing.
- Self-hosting install path re-creates the same 22 symlinks with relative targets (`../../specialists/<name>.md`).
- 5 integration tests depend on the symlinks existing; `test-install-source-mode.sh` is the most direct dependency.
- **`docs/architecture/install-architecture.md` does NOT exist.** The AC referenced it. Options: (a) create it, (b) add the section to existing `docs/architecture/self-hosting.md` (110 lines, install-and-merge produced it).

### 8. ac-10-e2e-fixture
- Two existing fixtures in `test-merge-e2e.sh`:
  - **contaminated-stop** (`E2E_REPO`): 4-commit worktree, phases 1-4, exits early on contamination.
  - **safe-happy-path** (`SAFE_REPO`): 2-commit worktree, all 5 phases, clean merge.
- **Missing**: a `full-pipeline` fixture combining contamination + feature commits + protected-file conflict + approved execute + verify-green.
- No `GIT_COMMITTER_DATE` determinism tricks today; tests rely on file content + exit codes.
- Plan should decide whether the new fixture needs determinism for reliable assertions.

## Cross-cutting surprises (plan-level)

1. **Script-mode scope: 19 scripts, not 1**. Proposal: broaden `rescue-sh-exec-fix` to `script-modes-fix` that chmods all 19 at once, with the pre-commit hook preventing future regressions. Same AC count; larger blast radius but same specialist, same session. Alternative: keep AC scoped to rescue.sh only and open a follow-up TODO for the other 18.

2. **Learnings schema drift has three resolutions** — user decision required:
   - **R-A (recommended)**: migrate the 4 old-format rows to the new schema (one-time script), update `learnings-protocol.md` to document only the new format, add validator-on-write hook so no further drift.
   - **R-B**: keep both schemas; update `promote-learnings.sh` to detect which and read both (union). No migration; both docs coexist. Adds permanent dual-schema code.
   - **R-C**: freeze the 4 old rows as-is (they're archived); fix `promote-learnings` to read new only; accept that old rows' learnings print as null for those fields. Simplest but silently wrong.

3. **`preferred_specialists` wiring is additive new work**. User decision required:
   - **P-A**: wire it now in `skills/shared/specialist-delegation.md` — creates the first consumer, validates the install-time writes mean something.
   - **P-B**: defer — open a follow-up TODO, drop the preferred_specialists AC from `xdg-config-consumer-wiring`, leave it write-only for now.

4. **Install architecture docs**: the definition AC points to `docs/architecture/install-architecture.md` which does not exist. Lean: add the section to `docs/architecture/self-hosting.md` (exists, install-and-merge owns it, relevant context is already there). Update AC to reference self-hosting.md.

5. **Definition revisions needed for accuracy** (no user decision, just fix ACs at plan step):
   - Replace the wrong `git diff <first>^..<last>` phrasing with `git log -p --no-merges <base>..HEAD -- <globs>`.
   - Align xdg AC to use/wrap/rename the existing `resolve_config_value`, not introduce a second helper.
   - Downgrade archived-row migration AC from hard requirement to "script + synthetic-fixture test" since no archived files exist today.

## Decisions needed from user (at research-gate time)

| ID | Decision | Recommendation |
|---|---|---|
| R1 | Script-mode scope: fix rescue only, or all 19 with the same hook? | All 19 (single PR, same hook catches all) |
| R2 | Learnings schema resolution: R-A / R-B / R-C | R-A (migrate 4 rows + canonical schema) |
| R3 | preferred_specialists wiring: in-row (P-A) or defer (P-B)? | P-B (defer; out of hygiene scope) |
| R4 | Install docs target: create install-architecture.md or extend self-hosting.md? | Extend self-hosting.md |

## Verified-but-boring findings (no AC change needed)

- All 22 specialist symlinks resolve to existing targets.
- `resolve_config_value` three-tier chain is correctly implemented and works under `XDG_CONFIG_HOME` override.
- Tests that do use the helpers isolate correctly — the mutation came from tests that skipped them.
- `Draft202012Validator` subprocess pattern is battle-tested.
- `docs/architecture/config-resolution.md` already exists with the three-tier chain documented.

## Sources Consulted (aggregate)

Per-topic files under `.furrow/rows/post-install-hygiene/research/`:
- `test-infrastructure.md` — sections A-D with ~40 line citations across tests/integration
- `schema-validators.md` — sections A-E with ~30 line citations across bin/frw.d/scripts + schemas + learnings.jsonl
- `cross-model-and-xdg.md` — sections A-E with ~25 line citations across cross-model-review.sh, common.sh, install.sh, bin/rws
- `install-artifacts.md` — sections A-F with ~50 line citations across bin/frw, bin/frw.d/scripts, install.sh, specialists/, .gitignore, integration tests
