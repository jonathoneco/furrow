# Spec: specialist-symlink-unification

**Wave**: 2
**Specialist**: harness-engineer
**Depends on**: test-isolation-guard

## Interface Contract

### Git index cleanup
Remove all 14 currently-tracked `.claude/commands/specialist:*.md` entries
from the git index via `git rm --cached` (working-tree symlinks are
preserved; only the index entries are dropped). Enumerated in
research `install-artifacts.md` Section C:
`api-designer, cli-designer, complexity-skeptic, document-db-architect,
go-specialist, harness-engineer, migration-strategist, python-specialist,
relational-db-architect, security-engineer, shell-specialist,
systems-architect, test-engineer, typescript-specialist`.

`.gitignore` line 30 (`/.claude/commands/specialist:*`) stays as-is — the
current rule already excludes the pattern; the 14 tracked entries violate
it, and the untrack commit brings the repo into compliance.

### install.sh as sole producer
Per AD-5 and research `install-artifacts.md` Section D, the existing
glob-discovery loop at `bin/frw.d/install.sh:572-581` is the canonical
producer of all 22 symlinks. The loop iterates `specialists/*.md`,
filters names starting with `_`, and invokes `symlink()` for each match.
This deliverable does NOT rewrite the loop — it confirms the loop covers
all 22 specialists and extends it only if coverage is incomplete.

```sh
# Reference: bin/frw.d/install.sh:572-581
if [ -d "$FURROW_ROOT/specialists" ]; then
  for spec in "$FURROW_ROOT"/specialists/*.md; do
    [ -f "$spec" ] || continue
    _basename="$(basename "$spec" .md)"
    case "$_basename" in _*) continue ;; esac
    symlink "$spec" "$TARGET/commands/specialist:${_basename}.md"
  done
fi
```

### Install-time validator
After the symlink-creation loop completes, `install.sh` MUST invoke a
validator that asserts each produced symlink resolves to an existing
`specialists/*.md` file. Any unresolved target fails installation with
the message `install: specialist symlink <name> points to missing target
<target>` and exit 1. Reuse/extend the existing `_validate_symlinks`
helper referenced at `bin/frw.d/install.sh:602` (research Section B).

### Documentation: self-hosting.md extension
Add a new subsection to `docs/architecture/self-hosting.md` (existing
110-line file). Per research Section E, the best insertion point is
after "Boundary enforcement points" (line ~52). New subsection title:
**"Specialist symlinks as install-time artifacts"**. Content must cover:
1. All 22 `specialist:*.md` entries are gitignored; none are tracked in
   the source repo.
2. `install.sh` is the sole producer; discovery is via the glob
   `$FURROW_ROOT/specialists/*.md` filtered by the `_*` prefix exclusion
   (pointer to `bin/frw.d/install.sh:572-581`).
3. Self-hosting behavior: in the Furrow source repo itself, `install.sh`
   produces the 22 symlinks locally with relative targets
   (`../../specialists/<name>.md`); they do not appear in
   `git status` because `.gitignore` excludes them.
4. Pre-commit guard: `pre-commit-typechange.sh` already rejects any
   attempt to re-track a specialist symlink (reference, not new work).

No new `docs/architecture/install-architecture.md` is created —
research confirmed `self-hosting.md` is the natural owner.

## Acceptance Criteria (Refined)

1. **14 tracked symlinks removed from index** — `git ls-files
   .claude/commands/ | grep -c '^\.claude/commands/specialist:'` returns
   `0` after the untrack commit. Working-tree symlinks at the same paths
   remain and still resolve.
2. **`.gitignore` unchanged in pattern but compliant in state** — Line
   30 still matches `/.claude/commands/specialist:*`; `git status
   --porcelain` shows no specialist symlinks as untracked or modified.
3. **install.sh produces 22 symlinks** — After `install.sh` runs into a
   fresh fixture directory, `find "$TARGET/commands" -name
   'specialist:*.md' -type l | wc -l` returns exactly `22`.
4. **Every symlink resolves** — For each produced symlink, `readlink -f
   <path>` succeeds and the target is an existing `specialists/*.md`
   file. Unresolved targets fail install with exit 1.
5. **Self-hosting produces no `git status` drift** — Running
   `install.sh` inside the Furrow source repo itself creates 22 local
   symlinks; immediately after, `git status --porcelain
   .claude/commands/` is empty (excluded by `.gitignore`).
6. **self-hosting.md gains the new subsection** — File contains an
   H2 or H3 header containing "Specialist symlinks" and references
   `install.sh:572-581` as the discovery site.
7. **Regression test `tests/integration/test-specialist-symlinks.sh`** —
   Exercises both the consumer-install path (fresh TARGET fixture) and
   the self-hosting path (copy-of-this-repo fixture). Asserts AC-3,
   AC-4, AC-5 in both paths. Uses `setup_sandbox` from
   test-isolation-guard.

## Test Scenarios

### Scenario: consumer install produces exactly 22 resolved symlinks
- **Verifies**: AC-3, AC-4
- **WHEN**: `setup_sandbox` creates a fresh `$TMP/home/.claude` target
  and `install.sh` runs against it.
- **THEN**: Exactly 22 `specialist:*.md` symlinks exist under the
  target's `commands/` directory and each `readlink -f` resolves to a
  file under `$FURROW_ROOT/specialists/`.
- **Verification**:
  ```sh
  setup_sandbox
  install.sh --target "$TMP/home/.claude" >/dev/null
  count=$(find "$TMP/home/.claude/commands" -name 'specialist:*.md' -type l | wc -l)
  test "$count" = "22" || fail "expected 22, got $count"
  for l in "$TMP/home/.claude/commands"/specialist:*.md; do
    readlink -f "$l" >/dev/null || fail "unresolved: $l"
  done
  ```

### Scenario: self-hosting install leaves git status clean
- **Verifies**: AC-5
- **WHEN**: A copy of the Furrow source repo is placed in
  `$TMP/fixture/furrow-src` (via `setup_sandbox`), and `install.sh`
  runs there against its own `.claude/` directory.
- **THEN**: `git -C "$TMP/fixture/furrow-src" status --porcelain
  .claude/commands/` is empty despite 22 symlinks existing in the
  working tree.
- **Verification**:
  ```sh
  cp -a "$FURROW_ROOT" "$TMP/fixture/furrow-src"
  (cd "$TMP/fixture/furrow-src" && install.sh --self-host >/dev/null)
  test -z "$(git -C "$TMP/fixture/furrow-src" status --porcelain .claude/commands/)"
  ```

### Scenario: install-time validator rejects broken targets
- **Verifies**: AC-4
- **WHEN**: A specialist file is deliberately deleted from
  `specialists/` (e.g., `rm $TMP/fixture/furrow-src/specialists/api-designer.md`),
  and `install.sh` is re-run.
- **THEN**: Install exits 1 with stderr containing
  `specialist symlink api-designer points to missing target`.
- **Verification**:
  ```sh
  rm "$TMP/fixture/furrow-src/specialists/api-designer.md"
  install_output=$(cd "$TMP/fixture/furrow-src" && install.sh --self-host 2>&1)
  rc=$?
  test "$rc" -eq 1 || fail "expected install exit 1, got $rc"
  printf '%s\n' "$install_output" | grep -q "api-designer points to missing target" \
    || fail "expected install stderr to name the broken specialist"
  ```

## Implementation Notes

- **Untrack, not delete**: `git rm --cached <path>` for each of the 14
  tracked entries — working-tree symlink survives. Commit message:
  `fix(install): untrack 14 specialist symlinks (install-time artifacts)`.
- **Discovery loop is already correct**: research Section D confirms
  `bin/frw.d/install.sh:572-581` iterates `specialists/*.md` excluding
  `_*` prefixes, which covers all 22 specialists listed in
  `_meta.yaml`. No loop rewrite — just verify coverage in the test.
- **Validator reuse**: the existing `_validate_symlinks` call at
  `bin/frw.d/install.sh:602` (per Section B) is the insertion point for
  the per-symlink resolution assertion. If the helper does not already
  check per-specialist resolution, extend it there (in this
  deliverable's file ownership).
- **Docs pattern**: match the heading depth and tone of existing
  subsections in `self-hosting.md` ("Path differences", "Boundary
  enforcement points"). Keep it under 40 lines so the file stays
  reviewable.
- **Sandbox**: both regression-test paths use `setup_sandbox`; no test
  may mutate the live worktree (constraint #4).
- **Five existing tests exercise specialist symlinks** (research
  Section F): `test-ci-contamination.sh`, `test-install-source-mode.sh`,
  `test-lifecycle.sh`, `test-rws.sh`, `test-generate-plan.sh`. The
  untrack commit must not break any — after untrack, install.sh
  recreates the working-tree symlinks, so consumer tests see the same
  filesystem state they saw before.

## Dependencies

- **Wave-1 prereq**: `test-isolation-guard` — `setup_sandbox` is used
  by the new regression test.
- **Existing install.sh machinery**: `bin/frw.d/install.sh:572-581`
  (glob loop) and `:602` (`_validate_symlinks`) — consumed and
  extended.
- **Existing `.gitignore` rule**: line 30 (`/.claude/commands/specialist:*`)
  — kept verbatim.
- **`pre-commit-typechange.sh`**: already guards against re-tracking
  (research Section B) — no change to the hook itself.
- **`specialists/_meta.yaml`**: informational only per AD-5; not
  promoted to a load-bearing manifest.
