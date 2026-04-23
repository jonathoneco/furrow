# Research Synthesis — install-and-merge

Reconciles R1–R5 with the four deliverables and the open questions from
ideation. Read individual research files for primary-source citations.

## Ideation questions — resolved or deferred

| Ideation open question | Resolved by | Answer |
|---|---|---|
| common.sh split boundary line | R2 | Split at line 168. 7 hook-safe functions → `common-minimal.sh` (~100 lines); the rest stays in `common.sh` for longer-running scripts. |
| Legacy-install detection heuristics | R1 | Two-tier: (a) presence of `.claude/furrow.yaml` OR `bin/{alm,rws,sds}.bak`; (b) absence of `.furrow/furrow.yaml` OR `.furrow/rows/`. Confirmed against current repo state. |
| `frw upgrade` command home | R1 | Top-level dispatcher case in `bin/frw`, parallel to `init` and `migrate-to-furrow`. |
| Sharded todos.d/ revisit trigger | — | Intentionally deferred to review step; not a research question. |

## Deliverable-by-deliverable synthesis

### install-architecture-overhaul

**R1 feeds**: complete mutation inventory (22 entries); `.bak` files not in
gitignore (concrete gap); dispatcher-pattern decision for `frw upgrade`.

**R2 feeds**: split line 168; 7 functions in `common-minimal.sh`; risk
analysis (concurrent markdown writes would be hook-unsafe → correctly excluded
from minimal).

**R3 feeds**: live evidence — all 24 `specialist:*.md` symlinks currently
escape worktree to `/home/jonco/src/furrow/` (not `../../specialists/` as
definition expects); `bin/{alm,rws,sds}` are symlinks in this repo (should be
regular files per pre-commit AC); 5 `.bak` files untracked; gitignore treats
source repo as consumer.

**R4 feeds**: `frw rescue` design — two-path recovery (git HEAD primary,
bundled baseline fallback); must not source common.sh; idempotent no-op when
target parses.

**Implementation implications** (for plan step):
1. Must repair the 24 escaped symlinks BEFORE implementing the pre-commit
   block — otherwise the block fires on the repair commit.
2. The `.furrow/SOURCE_REPO` sentinel fixes the gitignore smell by being the
   dimension `install.sh` branches on for "am I a source or consumer?"
3. `common-minimal.sh` is additive (no existing hook changes) so it can land
   before the `common.sh` reduction, eliminating the bootstrap window.

### config-cleanup

**R1 feeds**: legacy-install detection heuristic; quarantine policy (
`.bak` + install-state.json → XDG, rows/almanac/seeds/furrow.yaml → in-repo).

**Other research doesn't deeply touch config-cleanup** — it's mostly
mechanical wiring on top of R1's inventory.

**Implementation implications**:
1. `frw upgrade` is additive; old `frw install` keeps working. Upgrade is
   the opt-in detector+migrator.
2. `promotion-targets.yaml` stays scaffolding-only per definition.yaml AC 3;
   R5 did not design its schema (outside this row's scope).

### worktree-reintegration-summary

**R5 feeds**: full `reintegration.schema.json` shape; rationale for each
field; the decision that JSON is source-of-truth and markdown is a view.

**R3 feeds**: `files_changed.category` enum comes from the R3-observed
categories (source, test, doc, config, schema, install-artifact).

**Implementation implications**:
1. `rws generate-reintegration` reads state.json + git log since branch point +
   the latest review record — all already available.
2. Markdown template lives at `templates/reintegration.md.tmpl`.
3. Validation runs against the schema before `rws update-summary` accepts it.

### merge-process-skill

**R5 feeds**: full `merge-policy.yaml` shape; protected/machine-mergeable/
prefer-ours/always-delete categorization with globs drawn from R1 and R3.

**R3 feeds**: historical commits (f067df9, a6eb8ff, 8b6a63a, c432926) are a
ready-made regression test set — /furrow:merge's audit phase should flag
each of them correctly if re-played.

**R4 feeds**: `frw rescue` API shape (`--apply` flag, diagnose-only default)
is the fallback the merge-skill calls when common.sh is broken mid-merge.

**Implementation implications**:
1. /furrow:merge's audit phase reads `schemas/merge-policy.yaml`; its
   classify phase uses the worktree's own `reintegration.schema.json` output.
2. Script-guard heredoc false positive (we hit it in ideation) is the
   smallest fix but must land with merge-skill since the hook blocks the
   merge commands themselves.
3. R3's stale-references finding (26 TODO ids orphaned from roadmap)
   motivates the audit-phase sub-check "stale row/TODO references."

## Cross-cutting findings that don't fit one deliverable

1. **This worktree's bin/ CLIs are symlinks to the source repo.** This is
   why `frw validate-definition` read the source schema during our own
   ideation. The overhaul's success criterion should include "running
   `frw validate-definition` from a worktree validates against the
   worktree's schema" (tested via a fixture worktree with a schema delta).

2. **The 22 orphan specialist symlinks + 2 rules symlinks are an existing
   committed problem, not a drift.** The cleanup is a one-time fix with a
   defensive pre-commit hook preventing recurrence. Same for the 5 `.bak`
   files (untracked today; gitignore plus block).

3. **The 26 stale TODO ids** in R3 are noise generated by roadmap rotation;
   most are `done`, `archived`, or intentionally out of Phase 1 scope. This
   is not install-and-merge work but warrants a Phase 4+ todo-pipeline
   triage pass (already on the roadmap).

## Open questions surviving research

| # | Question | Needed by step |
|---|---|---|
| OQ-1 | Exact sort-by-id stable ordering (Python-style tuple compare? simple lexicographic? locale-independent?) for seeds.jsonl and todos.yaml. | plan |
| OQ-2 | Does the pre-commit hook block under `git commit --no-verify`? Decision: yes, `--no-verify` still bypasses; document the escape hatch explicitly. | plan |
| OQ-3 | Should `install-state.json` be per-repo (`$XDG_STATE_HOME/furrow/{repo-slug}/install-state.json`) or global with a map? R1 implies per-repo; plan to confirm. | plan |
| OQ-4 | Does `frw rescue` need to handle common.sh being missing entirely (deleted by a bad merge), not just broken? Yes — bundled baseline covers this. Document in rescue.sh comments. | plan |

## Research coverage summary

- **5 of 5 research priorities from ideation Recommendations addressed** (R1–R5).
- **All 4 open questions from ideation either resolved or explicitly deferred to review.**
- **4 new open questions surface for plan step** (OQ-1 through OQ-4).
- **Primary-source citations**: 30+ `path:line` references across R1–R3;
  secondary-source training-data claims in R4 limited to well-established
  tool behavior (homebrew, nix, git); R5 is design work grounded in R1–R3.

## Sources consulted (aggregated)

- R1 — 7 primary codebase files (install.sh, bin/frw.d/install.sh,
  bin/frw.d/init.sh, migrate-to-furrow.sh, launch-phase.sh, bin/frw,
  definition.yaml).
- R2 — common.sh + 12 hook files + 5 non-hook scripts + bin/frw dispatcher.
- R3 — git state, 5 commit shas, 24 symlinks, .gitignore, roadmap + todos.
- R4 — training-data knowledge of brew, nix, git hooks, chezmoi, mise, rustup.
- R5 — R1/R2/R3 findings + existing schemas/ convention.
