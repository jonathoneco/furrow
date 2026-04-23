# Spec: ac-10-e2e-fixture

## Interface Contract

### Modified file: `tests/integration/test-merge-e2e.sh`

Gains a third fixture named `full-pipeline` alongside the existing
`contaminated-stop` (lines 26-81, research Section C) and `safe-happy-path`
(lines 310-360) fixtures. The two existing fixtures remain untouched as
focused sub-phase coverage (per AC in definition.yaml).

New top-level functions:

- `setup_full_pipeline_fixture()` — creates `FULL_REPO` via `mktemp -d` inside
  the sandbox fixture dir (returned by `setup_sandbox`). Initializes a git
  repo with main-branch skeleton (`.furrow/`, `.claude/rules/`,
  `bin/frw.d/{lib,hooks,scripts}`). Creates a worktree branch
  `work/full-pipeline-row` with the combined-conditions commit set described
  below. All commits use fixed `GIT_COMMITTER_DATE`, `GIT_AUTHOR_DATE`,
  `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL`, `GIT_AUTHOR_NAME`,
  `GIT_AUTHOR_EMAIL` for determinism.
- `teardown_full_pipeline_fixture()` — `rm -rf "$FULL_REPO"`.
- `test_full_pipeline_runs_all_five_subphases()` — orchestrates
  audit → classify → resolve-plan → execute → verify for `FULL_REPO` and
  asserts the final-state invariants below.

### New directory: `tests/integration/fixtures/merge-e2e/full-pipeline/`

Holds static seed files the fixture-setup function copies into `FULL_REPO`.
At minimum: baseline `.furrow/almanac/todos.yaml`, protected-file conflict
seed, install-artifact seed, plus a feature-commit source file.

### Combined commit set on `work/full-pipeline-row`

1. Feature commit: source file under `bin/frw.d/scripts/new-feature.sh`
   (safe, non-protected path).
2. Install-artifact contamination: `.claude/commands/specialist:foo.md` added
   directly (violates the install-time-only policy established by
   specialist-symlink-unification).
3. Protected-file conflict: edit to a file both main and the branch changed
   in incompatible ways (forces a real merge conflict the resolve-plan
   subphase must address).
4. Feature commit: another safe source file.

This exercises: audit (detects install artifact as blocker), classify
(identifies destructive + feature commits), resolve-plan (produces plan.json
requiring approval for the conflict), execute (approves and merges),
verify (all green checks).

### Final-state assertions

After `verify` passes, the test asserts:

- `frw doctor` exits 0.
- Every file matching `bin/frw.d/hooks/*.sh` parses: `sh -n <file>` exits 0
  for each.
- `seeds.jsonl` sort invariant holds (monotonic `ts`).
- `.furrow/almanac/todos.yaml` sort invariant holds
  (existing `frw verify` check — reuses the mechanism).
- `bin/alm`, `bin/rws`, `bin/sds` remain mode 100755:
  `stat -c %a bin/alm bin/rws bin/sds` prints `755 755 755`.

### EXIT trap extension

The existing trap at `test-merge-e2e.sh:722` (research Section D) becomes:
`trap 'teardown_e2e_fixture; teardown_safe_e2e_fixture; teardown_full_pipeline_fixture; assert_no_worktree_mutation' EXIT INT TERM`

## Acceptance Criteria (Refined)

- **AC-1 (fixture exists and runs all 5 subphases)**:
  `tests/integration/test-merge-e2e.sh` contains a test function whose body
  invokes `/furrow:merge` sub-commands in this order: `audit`, `classify`,
  `resolve-plan`, `execute`, `verify`. Each subphase produces its expected
  JSON artifact (`audit.json`, `classify.json`, `plan.json`, `execute.json`,
  `verify.json`) inside `FULL_REPO`. Verification: the test function exists
  (`grep -q test_full_pipeline_runs_all_five_subphases
  tests/integration/test-merge-e2e.sh`) and the test suite exit code is 0.
- **AC-2 (existing fixtures untouched)**: The functions
  `setup_e2e_fixture` (lines 26-81 per research Section C) and
  `setup_safe_e2e_fixture` (lines 310-360) are byte-identical to their
  pre-row content. Verification: `git diff HEAD~1 -- tests/integration/test-merge-e2e.sh`
  does not show any hunks inside those two function bodies.
- **AC-3 (final-state: frw doctor)**: After `verify` completes, invoking
  `frw doctor` inside `FULL_REPO` exits 0. Verification: the test captures
  the exit code and calls `assert_exit_code "doctor after full-pipeline" 0 "$rc"`.
- **AC-4 (final-state: hooks parse)**: For each file `h` in
  `bin/frw.d/hooks/*.sh`, `sh -n "$h"` exits 0. Verification:
  `for h in bin/frw.d/hooks/*.sh; do sh -n "$h" || exit 1; done` inside
  `FULL_REPO` returns 0.
- **AC-5 (final-state: sort invariants)**: `seeds.jsonl` lines are sorted
  by `ts` ascending; `.furrow/almanac/todos.yaml` entries are sorted by the
  existing canonical order. Verification: reuse the existing
  `verify` subphase's sort-invariant check
  (research Section C, lines 529-608, `shell_syntax` + `no_bin_deletions`
  pattern) — the fact that `verify` exited 0 is the assertion.
- **AC-6 (final-state: executable modes)**: `stat -c %a bin/alm bin/rws bin/sds`
  inside `FULL_REPO` post-execute prints three `755` tokens. Verification:
  shell command as written; `assert_exit_code` on the equality check.
- **AC-7 (sandbox adoption)**: The test calls `setup_sandbox` before creating
  `FULL_REPO`; the fixture path is a child of the sandbox fixture dir.
  Verification: `grep -n setup_sandbox tests/integration/test-merge-e2e.sh`
  returns at least one line; `FULL_REPO` path begins with `$(setup_sandbox)`.
- **AC-8 (no live-worktree mutation)**: The `EXIT` trap calls
  `assert_no_worktree_mutation` after all teardowns. Verification: the trap
  line in `test-merge-e2e.sh` contains the string
  `assert_no_worktree_mutation`. Gitignore-awareness note: the 22 install-time
  specialist symlinks produced by `install.sh` (owned by the sibling
  `specialist-symlink-unification` deliverable) are `.gitignore`d, so
  `git status --porcelain` remains empty and the guard does not flake when
  both deliverables land in the same wave.
- **AC-9 (determinism)**: Every `git commit` in the fixture setup runs with
  `GIT_COMMITTER_DATE`, `GIT_AUTHOR_DATE`, `GIT_COMMITTER_NAME`,
  `GIT_AUTHOR_NAME`, `GIT_COMMITTER_EMAIL`, `GIT_AUTHOR_EMAIL` exported to
  fixed values. Verification: two back-to-back runs of the fixture produce
  identical commit SHAs — `git -C "$FULL_REPO" log --format=%H work/full-pipeline-row`
  compared across two invocations is byte-equal.
- **AC-10 (fixture files exist)**: `tests/integration/fixtures/merge-e2e/full-pipeline/`
  exists and contains at least the seed files referenced by
  `setup_full_pipeline_fixture`. Verification:
  `test -d tests/integration/fixtures/merge-e2e/full-pipeline` returns 0.

## Test Scenarios

### Scenario: full_pipeline_audit_flags_install_artifact

- **Verifies**: AC-1 (audit subphase)
- **WHEN**: `setup_full_pipeline_fixture` creates the 4-commit branch and
  `/furrow:merge audit` runs against `work/full-pipeline-row`
- **THEN**: `audit.json` is produced; `.install_artifact_additions` is a
  non-empty array containing `.claude/commands/specialist:foo.md`;
  `.blockers` is non-empty
- **Verification**:
  ```sh
  assert_file_exists "audit.json" "$FULL_REPO/.furrow/merge/audit.json"
  assert_json_field "install artifact detected" \
    "$FULL_REPO/.furrow/merge/audit.json" \
    '.install_artifact_additions | any(. == ".claude/commands/specialist:foo.md")' \
    "true"
  ```

### Scenario: full_pipeline_resolve_plan_requires_approval

- **Verifies**: AC-1 (resolve-plan subphase)
- **WHEN**: Audit and classify have completed; `/furrow:merge resolve-plan`
  runs
- **THEN**: `plan.json` is produced; `.approved == false`; the plan contains
  at least one entry for the protected-file conflict
- **Verification**: follow the existing pattern from
  `test-merge-e2e.sh` lines 203-226 (research Section C); assert
  `jq '.approved'` equals `false` and `jq '.entries | length >= 1'` is true

### Scenario: full_pipeline_verify_green_invariants_hold

- **Verifies**: AC-1 (verify subphase), AC-3, AC-4, AC-5, AC-6
- **WHEN**: `execute` has completed with approval; `/furrow:merge verify` runs
- **THEN**: `verify.json.overall == pass`; `frw doctor` exits 0; every hook
  parses; binaries remain 755
- **Verification**:
  ```sh
  cd "$FULL_REPO"
  assert_json_field "verify green" .furrow/merge/verify.json .overall '"pass"'
  frw doctor; assert_exit_code "doctor" 0 $?
  for h in bin/frw.d/hooks/*.sh; do sh -n "$h" || exit 1; done
  modes=$(stat -c '%a %a %a' bin/alm bin/rws bin/sds)
  test "$modes" = "755 755 755"
  ```

### Scenario: existing_fixtures_bodies_unmodified

- **Verifies**: AC-2
- **WHEN**: The row's implementation commit lands
- **THEN**: The byte ranges for `setup_e2e_fixture` and
  `setup_safe_e2e_fixture` are unchanged
- **Verification**:
  ```sh
  git show HEAD:tests/integration/test-merge-e2e.sh \
    | awk '/^setup_e2e_fixture\(\)/,/^}/{print}' > new.txt
  git show HEAD~1:tests/integration/test-merge-e2e.sh \
    | awk '/^setup_e2e_fixture\(\)/,/^}/{print}' > old.txt
  diff old.txt new.txt
  ```

### Scenario: fixture_is_reproducible_across_runs

- **Verifies**: AC-9
- **WHEN**: `setup_full_pipeline_fixture` is run twice in separate sandbox
  invocations
- **THEN**: The resulting commit SHAs on `work/full-pipeline-row` are
  byte-identical across the two runs
- **Verification**:
  ```sh
  run1=$(setup_full_pipeline_fixture; git -C "$FULL_REPO" log --format=%H work/full-pipeline-row)
  teardown_full_pipeline_fixture
  run2=$(setup_full_pipeline_fixture; git -C "$FULL_REPO" log --format=%H work/full-pipeline-row)
  test "$run1" = "$run2"
  ```

### Scenario: no_live_worktree_mutation_under_failure

- **Verifies**: AC-7, AC-8
- **WHEN**: The test deliberately fails (e.g., via `return 1`) inside
  `test_full_pipeline_runs_all_five_subphases`
- **THEN**: The `EXIT` trap runs teardowns and `assert_no_worktree_mutation`;
  the latter exits 0 because the sandbox contained all writes
- **Verification**: run the test under a wrapper that forces failure after
  execute; assert the live worktree's `git status --porcelain` is empty
  after the process exits

## Implementation Notes

- **Research Section C** documents the two existing fixtures and their
  assertion conventions. Reuse `assert_exit_code`, `assert_file_exists`,
  `assert_json_field` from `helpers.sh` (lines 109-198) rather than
  inventing new assertions.
- **Research Section C** (lines 181-185) notes the existing fixtures use
  hardcoded file content for determinism but do NOT set
  `GIT_COMMITTER_DATE`. This deliverable explicitly adds the env-var
  approach because the combined-condition commit set depends on SHA
  reproducibility for assertion stability (AC-9).
- **Research Section C** (lines 529-608) details the existing
  `shell_syntax` and `no_bin_deletions` checks inside verify. AC-4 (hook
  parse) and AC-6 (binary modes) complement rather than duplicate these.
- **Research Section D** (lines 230-238) documents the existing EXIT trap
  pattern. AC-8 extends it by chaining `assert_no_worktree_mutation` last.
- **Sandbox integration** (AD per sibling test-isolation-guard spec): the
  test sources `tests/integration/lib/sandbox.sh` and calls
  `setup_sandbox` before `setup_full_pipeline_fixture`; `FULL_REPO` is
  created inside the sandbox's fixture dir so every side effect
  (git config, object store, etc.) is contained.
- **Gitignore interaction** (AD-5): the 22 specialist symlinks produced by
  `install.sh` appear inside `FULL_REPO/.claude/commands/` during the
  fixture's `install.sh` invocation. They are `.gitignore`d in the source
  repo, but `FULL_REPO` is a separate repo so they are either (a) not
  created there (fixture uses only a skeleton, not a full install) or
  (b) also `.gitignore`d in the fixture's checked-in `.gitignore`. The
  fixture chooses (b) for faithfulness to real installs — the fixture's
  `.gitignore` mirrors the source repo's pattern.
- **POSIX sh constraint** (definition.yaml constraint #5): fixture setup
  uses `#!/bin/sh`-compatible constructs; `GIT_COMMITTER_DATE` and siblings
  are set via `export` rather than inline `VAR=val command`.
- **Trap ordering**: the `EXIT` trap must run `teardown_full_pipeline_fixture`
  BEFORE `assert_no_worktree_mutation`, so the guard observes the
  post-cleanup state (research Section D recommendation).

## Dependencies

- **Hard prerequisite**: `test-isolation-guard` (wave-1). This deliverable
  sources `tests/integration/lib/sandbox.sh` and calls `setup_sandbox` +
  `assert_no_worktree_mutation`. It cannot land before test-isolation-guard.
- **Existing code reused**:
  - `helpers.sh` assertion helpers
    (`assert_exit_code`, `assert_file_exists`, `assert_json_field`,
    `run_test`, `print_summary`) — research Section C, lines 109-198.
  - Existing `test-merge-e2e.sh` fixture-setup patterns
    (research Section C, lines 26-81, 310-360).
- **Soft coexistence**: `specialist-symlink-unification` (wave-2 sibling).
  Both deliverables land in wave-2; the gitignore-aware
  `git status --porcelain` check in `run-all.sh`
  (owned by test-isolation-guard) prevents cross-deliverable flakes.
- **External**: `git`, `jq` (already a helpers.sh dependency),
  `sh` (for `-n` parse check), coreutils `stat`.
