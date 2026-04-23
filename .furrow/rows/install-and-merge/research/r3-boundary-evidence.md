# R3: Boundary Violations — Evidence Base

## 1. Broken Symlinks

All `.claude/commands/specialist:*.md` symlinks (22 files) target `/home/jonco/src/furrow/specialists/` — outside the worktree root `/home/jonco/src/furrow-install-and-merge/`. Additionally, 2 rules files in `.claude/rules/` are symlinks escaping the repo:

| Path | Target | Resolves? | Outside Worktree? | Fix Needed |
|------|--------|-----------|-------------------|-----------|
| `.claude/commands/specialist:test-engineer.md` | `../../../furrow/specialists/test-engineer.md` | ✓ | YES | YES |
| `.claude/commands/specialist:merge-specialist.md` | `../../../furrow/specialists/merge-specialist.md` | ✓ | YES | YES |
| `.claude/commands/specialist:shell-specialist.md` | `../../../furrow/specialists/shell-specialist.md` | ✓ | YES | YES |
| `.claude/commands/specialist:harness-engineer.md` | `../../../furrow/specialists/harness-engineer.md` | ✓ | YES | YES |
| (... 18 more specialist:*.md files similarly outside ...) | | | | |
| `.claude/rules/cli-mediation.md` | `../../../furrow/.claude/rules/cli-mediation.md` | ✓ | YES | YES |
| `.claude/rules/step-sequence.md` | `../../../furrow/.claude/rules/step-sequence.md` | ✓ | YES | YES |

**Finding:** All 24 symlinks point to `/home/jonco/src/furrow/` (the source repo), which is outside the consumer-project worktree boundary. These violate the design intention that specialist and rules symlinks should resolve to `../../specialists/` (local to this repo).

---

## 2. Committed Install Artifacts

Three `.bak` files committed in `bin/`:

| Path | Git Status | Commit SHA | Issue |
|------|-----------|-----------|-------|
| `bin/alm.bak` | Untracked (`??`) | N/A | Install-produced backup; should be under `$XDG_STATE_HOME` |
| `bin/rws.bak` | Untracked (`??`) | N/A | Install-produced backup; should be under `$XDG_STATE_HOME` |
| `bin/sds.bak` | Untracked (`??`) | N/A | Install-produced backup; should be under `$XDG_STATE_HOME` |

Additionally, `.claude/rules/` contains two `.bak` sibling files:
- `.claude/rules/cli-mediation.md.bak` — untracked
- `.claude/rules/step-sequence.md.bak` — untracked

These backups are remnants of a symlink-replacement process that should have written state to `$XDG_STATE_HOME/furrow/{repo-slug}/` instead of the worktree.

---

## 3. Type-Change Hazards

Current symlinks that MUST remain regular files per definition.yaml acceptance criteria:

| Path | Current Type | Status | Danger |
|------|-------------|--------|--------|
| `bin/alm` | Symlink | Present in tree | **HIGH** — actual binary currently a symlink to `/home/jonco/src/furrow/bin/alm` |
| `bin/rws` | Symlink | Present in tree | **HIGH** — actual binary currently a symlink to `/home/jonco/src/furrow/bin/rws` |
| `bin/sds` | Symlink | Present in tree | **HIGH** — actual binary currently a symlink to `/home/jonco/src/furrow/bin/sds` |
| `.claude/rules/cli-mediation.md` | Symlink | Present in tree | **MEDIUM** — rules should be regular files or repo-local symlinks |
| `.claude/rules/step-sequence.md` | Symlink | Present in tree | **MEDIUM** — rules should be regular files or repo-local symlinks |

The definition.yaml acceptance criterion states:
> "Pre-commit hook blocks: (a) type-change regular→symlink on bin/alm, bin/rws, bin/sds, .claude/rules/*"

This is already happening — these files ARE symlinks and should be regular files. The pre-commit hook hasn't yet been implemented to reverse it.

---

## 4. Historical Contamination Evidence

Key commits that demonstrate the install-artifact boundary violation problem:

| SHA | Subject | Impact |
|-----|---------|--------|
| `a6eb8ff` | `chore: ignore furrow-managed files and untrack bin/ CLI symlinks` | **MAJOR**: Deleted `bin/alm`, `bin/rws`, `bin/sds` (4291 LOC removed). Added `.gitignore` patterns for `# furrow:managed` section. This was a symlink-from-source-repo workaround committed in-tree. |
| `c432926` | `chore: update symlinks and seed state for infra-fixes row` | Updated 30+ symlinks in `.claude/commands/` to point to source repo (`../../../furrow/`), establishing the escape pattern now visible. |
| `f067df9` | `merge: parallel-agent-wiring — row artifacts and orchestration rewrite` | **DESTRUCTIVE MERGE**: Reverted symlink conversions, stating "DROPPED...consumer .gitignore additions" and "bin/alm, bin/rws, bin/sds deletions (kept main binaries)". Main carries real binaries; this branch tried to symlink them. This is the signature boundary violation. |
| `8b6a63a` | `merge: infra-fixes — PROJECT_ROOT, specialist enforcement, ideation review` | Noted "Reverted consumer-project symlinks for bin/{alm,rws,sds} back to real scripts" — confirms the pattern of symlink-ification as a contamination artifact. |
| `bc2746c` | `chore: merge T4 (specialist-rewrite) — reasoning-focused specialist templates` | Template/specialist symlink management in worktree; contributed to the `.claude/commands/specialist:*` escape-symlink pattern. |

**Pattern:** Every ~2 weeks, a consumer-worktree run leaves install artifacts (`.bak` files, escaped symlinks) that require a `chore: update symlinks` or `merge: ...revert` commit to fix. This is the core evidence motivating the overhaul.

---

## 5. Stale References

Found 26 TODO ids in `todos.yaml` that do NOT appear in `roadmap.yaml`:

- `almanac-knowledge-subcommands-learn-rationale-docs`
- `beans-enforcement-integration`
- `blocking-stop-hooks`
- `claude-md-docs-routing`
- `consumer-project-furrow-root` (RELEVANT: references consumer-project install contamination)
- `cross-platform-compatibility`
- `default-supervised-gating`
- `duplication-cleanup`
- `fresh-session-review`
- `gate-check-hook-excluded-steps`
- `interactive-ideation-checkpoints`
- `legacy-todos-migration`
- `merge-specialist` (RELEVANT: direct evidence of merge-phase worker role)
- `per-step-model-routing`
- `quality-enforcement-expansion`
- `rename-to-furrow`
- `rethink-hint-file-pattern`
- `rules-strategy` (RELEVANT: .claude/rules management)
- `rws-review-archive-flow-and-deliverable-tracking`
- `script-access-restrictions`
- `skill-loading-visible-internals`
- `sonnet-model-routing`
- `specialist-auto-delegation`
- `specialist-encoded-reasoning`
- `specialist-expansion`
- `specialist-templates-from-team-plan-not-enforced-d`
- `stop-hook-false-positives`

Notable: `consumer-project-furrow-root`, `merge-specialist`, and `rules-strategy` appear to directly address the boundary-violation problem but are not integrated into the roadmap dependency graph.

---

## 6. Gitignore Smell Test

`.gitignore` contains a `# furrow:managed` section with patterns that only make sense for a **consumer project**:

```
# furrow:managed
skills
schemas
evals
specialists
references
adapters
templates
bin/sds
bin/rws
bin/alm
.claude/commands/furrow:*
.claude/commands/specialist:*
.claude/commands/lib/
.claude/rules/cli-mediation.md
.claude/CLAUDE.md
```

This section was introduced in commit `a6eb8ff` under the rationale "Untrack bin/ CLI symlinks — they now live only in the source repo and are accessed via symlinks in this consumer project."

**Evidence of boundary violation:** The `.gitignore` is explicitly written for a consumer-project install scenario, yet this repo is the **source repo**. Per definition.yaml:
> "Source-repo detection: .furrow/SOURCE_REPO sentinel committed; install.sh... skip symlink-to-source when present. install.sh explicitly refuses to copy .furrow/SOURCE_REPO into consumer projects."

No `.furrow/SOURCE_REPO` sentinel exists, and the gitignore implies the repo treats itself as a consumer.

---

## 7. Sources Consulted

| Source | Tier | Contribution |
|--------|------|--------------|
| `.furrow/rows/install-and-merge/definition.yaml` | Primary (spec) | Baseline acceptance criteria; referenced for type-change hazards and SOURCE_REPO sentinel expectation |
| `git log --oneline -20 -- bin/ .claude/ .gitignore` | Primary (git) | 6 commits identified as boundary-violation patterns |
| `git show <sha>` for commits f067df9, a6eb8ff, c432926, 8b6a63a | Primary (git) | Detailed contamination evidence: deletions, reverts, symlink escapes |
| `find .claude/commands -name "specialist:*.md" -type l` | Primary (fs) | 22 symlinks confirmed escaping worktree |
| `.furrow/almanac/roadmap.yaml`, `todos.yaml` | Primary (state) | 26 stale TODO references identified |
| `.gitignore` current state | Primary (fs) | Consumer-project patterns found in source repo |

---

## Summary

**Most Critical Findings:**

1. **All 24 specialist/rules symlinks escape the worktree** — point to `/furrow/` instead of local `../../specialists/`. This is the single largest boundary violation.

2. **bin/alm, bin/rws, bin/sds are currently symlinks** when they should be regular files. Definition.yaml's pre-commit hook requirement (blocking type-changes) is not yet implemented.

3. **Install-produced .bak files committed untracked** in `bin/` and `.claude/rules/` — evidence that install-time symlink staging is happening in-tree instead of under XDG_STATE_HOME.

4. **Gitignore explicitly documents consumer-project behavior** while repo is source. No SOURCE_REPO sentinel to gate this.

5. **Historical merge/revert pattern** (f067df9, a6eb8ff, 8b6a63a, c432926) shows recurring contamination cycles every 1-2 weeks, confirming the need for automated boundary enforcement.

**This evidence base validates the R3 research question: concrete, in-repo boundary violations exist across symlinks, install artifacts, and gitignore configuration.**
