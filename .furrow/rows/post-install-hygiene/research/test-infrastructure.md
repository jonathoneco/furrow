# Test Infrastructure Research

## Section A — Current Environment Variable Resolution in Tests

### Files Surveyed
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/helpers.sh` (lines 22–105)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-install-idempotency.sh` (lines 17–90)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-install-consumer-mode.sh` (lines 18–19)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-install-xdg-override.sh` (lines 19–150)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-upgrade-idempotency.sh` (lines 17–100)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-ci-contamination.sh` (lines 20–150)

### Environment Variable Usage by Test

**test-install-idempotency.sh**:
- Sets: `FURROW_ROOT` (line 17: `FURROW_ROOT="$PROJECT_ROOT"`)
- Sets: `XDG_STATE_HOME` per test (lines 50, 66, 104, 120, 135)
- Uses: fixture directory isolation via `mktemp -d` (line 42–44: `fixture_dir`, `xdg_dir`, `manifest_dir`)
- Leaves unset: `HOME`, `XDG_CONFIG_HOME`, `TMP`, `TMPDIR`

**test-install-consumer-mode.sh**:
- Sets: `FURROW_ROOT` (line 18: same as above)
- Sets: `XDG_STATE_HOME` per test (lines 60, 90, 137)
- Uses: fixture isolation via `mktemp -d` (lines 50, 52, 84)
- **Critical mutation**: Lines 47–73 show the test creates a `.furrow/SOURCE_REPO` sentinel in fixture, but that's *within* a temp fixture, not the live worktree.

**test-install-xdg-override.sh**:
- Sets: `FURROW_ROOT`, `XDG_STATE_HOME`, `XDG_CONFIG_HOME` per test
- Lines 47–48 show: fixture isolation *and explicit isolation of XDG paths* — "NOT /tmp/xdg-test — dynamically allocated"
- Lines 53–56, 82–86: both `--xdg-state-home` flag *and* env var set (redundant safety)
- Uses: `mktemp -d` for all isolation points

**test-upgrade-idempotency.sh**:
- Sets: `FURROW_ROOT`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME` (lines 17, 85–87)
- Lines 79–90: wraps `frw upgrade` in cd-into-project subshell, passing explicit env vars
- Uses: `mktemp -d` for fixture, config, and state isolation (lines 97–99)
- Critical: Line 84 uses `_make_tmp_dir()` helper which builds `_TMP_DIRS` array for centralized cleanup

**test-ci-contamination.sh**:
- Sets: `PROJECT_ROOT_DIR`, `CONTAMINATION_CHECK` path (lines 20–22)
- Uses: isolated git repo via `make_isolated_repo()` (lines 28–41)
- Line 29: `REPO_DIR="$(mktemp -d)"` + isolated git init inside
- **Key difference**: Creates brand-new git repos, never touches the live worktree

### Key Finding: No Shared Sandbox Helper Currently Exists

**helpers.sh provides**:
- `setup_test_env()` (lines 26–66): creates `TEST_DIR` via `mktemp -d`, sets `PATH` to include project `bin/`, initializes minimal git repo, creates `.furrow/` skeleton
- `setup_fixture()` (lines 82–91): creates `FIXTURE_DIR` via `mktemp -d`, sets `WORK_DIR` and `FIXTURE_DIR` exports
- Exit-trap cleanup (lines 65, 89): `trap 'rm -rf "${TEST_DIR:-}"' EXIT INT TERM`
- **BUT**: No unified snapshot mechanism for specialist symlinks or todos.yaml

**Mutation vectors identified**:

The codebase correctly uses `mktemp -d` isolation in *all* test-install and test-upgrade files. However:

1. `helpers.sh` line 94–95 exports `FURROW_ROOT` and `PROJECT_ROOT` globally (unconditional):
   ```bash
   FURROW_ROOT="$PROJECT_ROOT"
   export FURROW_ROOT
   export PROJECT_ROOT
   ```
   This is safe because `PROJECT_ROOT` is computed as the repo root (line 17), not the live user's pwd.

2. No test currently snapshots the live worktree's `.claude/commands/specialist:*.md` symlinks or `.furrow/almanac/todos.yaml` before running. If a test accidentally ran against the live worktree (via environment leak), these would mutate.

---

## Section B — Specialist Symlink + Todos Snapshot Targets

### Files to Snapshot

**Specialist symlinks** (14 entries under `.claude/commands/`):
1. `specialist:api-designer.md` → `../../specialists/api-designer.md` (symlink)
2. `specialist:cli-designer.md` → `../../specialists/cli-designer.md` (symlink)
3. `specialist:complexity-skeptic.md` → `../../specialists/complexity-skeptic.md` (symlink)
4. `specialist:document-db-architect.md` → `../../specialists/document-db-architect.md` (symlink)
5. `specialist:go-specialist.md` → `../../specialists/go-specialist.md` (symlink)
6. `specialist:harness-engineer.md` → `../../specialists/harness-engineer.md` (symlink)
7. `specialist:migration-strategist.md` → `../../specialists/migration-strategist.md` (symlink)
8. `specialist:python-specialist.md` → `../../specialists/python-specialist.md` (symlink)
9. `specialist:relational-db-architect.md` → `../../specialists/relational-db-architect.md` (symlink)
10. `specialist:security-engineer.md` → `../../specialists/security-engineer.md` (symlink)
11. `specialist:shell-specialist.md` → `../../specialists/shell-specialist.md` (symlink)
12. `specialist:systems-architect.md` → `../../specialists/systems-architect.md` (symlink)
13. `specialist:test-engineer.md` → `../../specialists/test-engineer.md` (symlink)
14. `specialist:typescript-specialist.md` → `../../specialists/typescript-specialist.md` (symlink)

**Source/reference binaries** (regular executable files):
- `bin/alm` — regular file (83 KB, executable)
- `bin/rws` — regular file (99 KB, executable)
- `bin/sds` — regular file (18 KB, executable)

**Todos file** (plain YAML):
- `.furrow/almanac/todos.yaml` — regular file (140 KB)

**Rules files** (plain markdown):
- `.claude/rules/cli-mediation.md` — regular file (1.6 KB)
- `.claude/rules/step-sequence.md` — regular file (0.7 KB)

### Guard Strategy

Pre-test snapshot should capture:
- SHA256 of each specialist symlink *target* (not the link itself — prevent link-hijacking detection)
- SHA256 of bin/{alm,rws,sds}
- SHA256 of .furrow/almanac/todos.yaml
- SHA256 of .claude/rules/*.md files

Post-test: diff snapshots; any change → test contaminated the live worktree.

---

## Section C — Test-Merge-E2E Fixture Structure

### File Location
`/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-merge-e2e.sh` (29 KB, 750 lines)

### Top-Level Structure

**Fixture setup functions**:
1. `setup_e2e_fixture()` (lines 26–81) — "contaminated-stop" fixture
   - Creates `E2E_REPO` via `mktemp -d`
   - Initializes git, creates `.furrow/`, `.claude/rules/`, `bin/frw.d/{lib,hooks,scripts}`
   - Commits main branch with baseline files
   - Creates worktree branch `work/e2e-row` with 4 commits:
     - Commit 1: feat (safe source change)
     - Commit 2: install artifact `bin/alm.bak` (destructive)
     - Commit 3: convert `bin/alm` to symlink (protected typechange)
     - Commit 4: append to `.furrow/almanac/todos.yaml` (machine-mergeable candidate)

2. `setup_safe_e2e_fixture()` (lines 310–360) — "safe-happy-path" fixture
   - Creates `SAFE_REPO` via `mktemp -d`
   - Same skeleton as contaminated fixture
   - Creates worktree branch `work/safe-e2e-row` with only 2 safe commits (source files, no protected paths)

3. `teardown_e2e_fixture()` (lines 83–89) and `teardown_safe_e2e_fixture()` (lines 362–367)
   - Cleanup via `rm -rf`

### Assertion Helper Convention

From `helpers.sh`:
- `assert_exit_code <description> <expected> <actual>` (lines 109–122)
- `assert_file_exists <description> <path>` (lines 124–137)
- `assert_json_field <description> <file> <jq_expr> <expected>` (lines 184–198)
- `run_test <function_name>` (lines 247–257) — calls function, counts pass/fail

test-merge-e2e uses these + inline TESTS_RUN/TESTS_PASSED/TESTS_FAILED counters (lines 123–144, 181–191, etc.)

### Existing AC-10 Fixture Coverage

**Contaminated-stop fixture** (`E2E_REPO`):
- Phase 1 (audit): Exit 3 (blockers: install artifact + symlink typechange)
  - Assertions: audit.json created, `install_artifact_additions` non-empty, `blockers` non-empty (lines 115–144)
- Phase 2 (classify): Exit 4 (destructive commits)
  - Assertions: classify.json created, commit count > 0 (lines 172–191)
- Phase 3 (resolve-plan): Exit 5 (approval required)
  - Assertions: plan.json created, plan.md created, `.approved == false`, `inputs_hash` valid (lines 203–226)
- Phase 4 (execute): Exit 5 without approval (lines 229–248)
- Verify: Skipped (execute failed, no execute.json)

**Safe-happy-path fixture** (`SAFE_REPO`):
- Phase 1 (audit): Exit 0 or 3 (accept rws blocker only)
  - Assertions: merge_id produced, no contamination blockers (lines 372–414)
- Phase 2 (classify): Exit 0 (all safe commits)
  - Assertion: exit code 0 (lines 417–429)
- Phase 3 (resolve-plan): Exit 5 (approval required)
  - Assertions: plan.json created, `.approved == false` (lines 432–449)
- Phase 4 (execute): Succeeds after approval
  - Assertions: execute.json created, `.status == complete`, merge_sha valid (lines 474–527)
- Phase 5 (verify): 
  - Green path: Exit 0, `.overall == pass`, 6+ checks pass, shell_syntax + no_bin_deletions specifically verified (lines 529–608)
  - Regression path: Exit 7 on sort-invariant violation (lines 615–668)
  - Idempotency: Re-run produces identical check count (lines 671–713)

### Determinism Tricks Used

**No explicit GIT_COMMITTER_DATE/GIT_AUTHOR_DATE**. Instead, reliance on:
- Fresh repo initialization (no history to depend on)
- Deterministic file content (hardcoded in fixture setup, not random)
- Exit code semantics (phases pass/fail based on predictable merge conflicts, not timestamps)

**Example**: Line 46 in `setup_e2e_fixture()` commits todos with fixed date in YAML:
```bash
printf -- '- id: todo-001\n  title: existing todo\n  created_at: "2026-01-01T00:00:00Z"\n' > .furrow/almanac/todos.yaml
```

---

## Section D — Test Runner Entrypoint

### Current State

**No centralized `tests/integration/run-all.sh`** exists. Individual test files are self-contained executables:
```
#!/bin/bash
set -euo pipefail
source helpers.sh
run_test test_foo
run_test test_bar
print_summary
exit $?
```

Each test file calls `run_test()` (helper.sh line 247) and ends with `print_summary()` (line 259).

### Where to Add Pre/Post Guard

Logical locations for a "git status empty before+after" check:

1. **Shared helpers.sh**: Add a `setup_guard_snapshot()` and `teardown_guard_snapshot()` function that:
   - Pre-test: `git status` to empty (verify clean worktree)
   - Post-test: `git status` to empty (verify no contamination)
   - Diff against pre/post SHA256 snapshots of specialist symlinks + todos.yaml + binaries

2. **Individual test entrypoint** (each test's `main()` or top-level code):
   - Call guard setup before `setup_e2e_fixture()` or `setup_test_env()`
   - Call guard teardown in EXIT trap after fixture teardown

3. **Optional: CI wrapper script** (if one is added):
   - Pre-run: Snapshot live worktree
   - Post-run: Verify no changes

### Current Cleanup Pattern

helpers.sh uses unconditional EXIT trap (line 65):
```bash
trap 'rm -rf "${TEST_DIR:-}"' EXIT INT TERM
```

test-merge-e2e.sh extends this (line 722):
```bash
trap 'teardown_e2e_fixture; teardown_safe_e2e_fixture' EXIT INT TERM
```

**Recommendation**: Guard should hook into EXIT *after* fixture teardown, so:
```bash
trap 'teardown_fixtures; verify_no_worktree_mutations' EXIT INT TERM
```

---

## Summary of Key Findings

| Finding | Location | Impact |
|---------|----------|--------|
| All test-install/test-upgrade use `mktemp -d` isolation | helpers.sh, all test files | Live worktree NOT mutated by these tests ✓ |
| No shared sandbox helper exists | helpers.sh missing | Need to add `setup_guard_snapshot()` / `teardown_guard_snapshot()` |
| Specialist symlink targets stable (14 entries) | `.claude/commands/specialist:*.md` | Snapshotting targets via SHA256 is clean |
| Todos.yaml is 140 KB plain file | `.furrow/almanac/todos.yaml` | Snapshotting via SHA256 is clean |
| test-merge-e2e splits AC-10 across two fixtures | lines 304–668 | Contaminated-stop + safe-happy-path; need third full-pipeline fixture |
| No full-pipeline fixture (5 phases all green) | test-merge-e2e.sh | Missing: fixture covering all 5 /furrow:merge subphases end-to-end |
| No determinism tricks (GIT_COMMITTER_DATE) | test-merge-e2e setup | Uses fixed content + deterministic exit codes instead |
| No centralized test runner | tests/integration/ | Each .sh is self-contained; no run-all.sh or Makefile |

---

## Sources Consulted

- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/helpers.sh` (lines 1–271)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-install-idempotency.sh` (lines 1–156)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-install-consumer-mode.sh` (lines 1–163)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-install-xdg-override.sh` (lines 1–155+)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-upgrade-idempotency.sh` (lines 1–150+)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-ci-contamination.sh` (lines 1–150+)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-merge-e2e.sh` (lines 1–750)
- `.claude/commands/specialist:*.md` symlinks (14 total, all pointing to `../../specialists/*.md`)
- `bin/{alm,rws,sds}` (regular executable files)
- `.furrow/almanac/todos.yaml` (140 KB YAML)
- `.claude/rules/{cli-mediation.md, step-sequence.md}` (2 regular files)

