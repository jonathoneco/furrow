# Spec: test-isolation-guard

## Interface Contract

### New file: `tests/integration/lib/sandbox.sh`

POSIX sh library sourced by every integration test. Exports:

- `setup_sandbox()` — creates `$TMP/home`, `$TMP/config`, `$TMP/state`, `$TMP/fixture`;
  exports `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `FURROW_ROOT` to point
  inside `$TMP`; prints the absolute path of the fixture dir to stdout; returns
  exit code 0 on success and non-zero if any mkdir fails.
  - Side effects: sets the four env vars in the calling shell.
  - Contract: after invocation, no code path inside the test may resolve any of
    `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, `FURROW_ROOT` to a path outside
    `$TMP`.
- `snapshot_guard_targets()` — writes sha256 sums for the protected-path set
  (see AC-3) to `$TMP/guard.pre.sha256`. Exit 0 on success.
- `assert_no_worktree_mutation()` — recomputes sha256 sums for the same paths,
  diffs against `$TMP/guard.pre.sha256`; on any drift prints the offending
  path(s) and the pre/post digests to stderr and exits 1. Exit 0 on clean match.
  Designed to be invoked from an `EXIT` trap after fixture teardown.

### Modified file: `tests/integration/helpers.sh`

Sources `lib/sandbox.sh`. Existing functions (`setup_test_env`, `setup_fixture`,
`assert_*`, `run_test`, `print_summary`) preserved. The unconditional global
`export FURROW_ROOT="$PROJECT_ROOT"` at `helpers.sh:94-95` (research Section A)
is moved behind a `setup_sandbox`-first contract: tests MUST call
`setup_sandbox` before any harness invocation; helpers.sh no longer exports
the repo-rooted `FURROW_ROOT` unconditionally.

### New file: `tests/integration/run-all.sh`

Central entrypoint. Behaviour:

1. Exits 1 if `git status --porcelain` is non-empty before any test runs; prints
   the offending output.
2. Iterates every `tests/integration/test-*.sh` with `set -e` semantics; each
   test is executed in a subshell.
3. After the suite, runs `git status --porcelain` again; exits 1 and prints the
   diff if non-empty.
4. Exit 0 iff pre-check clean, every test exited 0, and post-check clean.

### New file: `tests/integration/test-sandbox-guard.sh`

Regression test. Two scenarios: a clean pass (isolation honored) and a
deliberate contamination (FURROW_ROOT pointed at the live repo root) that must
cause `assert_no_worktree_mutation` to exit 1.

### Modified files: `tests/integration/test-install-*.sh`, `tests/integration/test-upgrade-*.sh`

Each test adopts `setup_sandbox` as the first setup step and installs
`assert_no_worktree_mutation` in its `EXIT` trap after fixture teardown.

### New file: `docs/architecture/testing.md`

Documents: sandbox contract, the four env vars, resolution order (project →
XDG → FURROW_ROOT fallback, per AD-1), the protected-path snapshot set, the
run-all.sh pre/post invariant, and the teardown ordering rule
(`teardown_fixtures; assert_no_worktree_mutation`).

## Acceptance Criteria (Refined)

- **AC-1 (env sandbox)**: Every file matching
  `tests/integration/test-install-*.sh` and
  `tests/integration/test-upgrade-*.sh` calls `setup_sandbox` before any `frw`,
  `rws`, `alm`, `sds`, or `install.sh` invocation. After that call, the four
  env vars `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, `FURROW_ROOT` each
  resolve to a path under `$TMP` (where `$TMP` is a `mktemp -d` result).
  Verification: `grep -L setup_sandbox tests/integration/test-install-*.sh
  tests/integration/test-upgrade-*.sh` returns empty.
- **AC-2 (shared helper exports)**: `tests/integration/lib/sandbox.sh` defines
  `setup_sandbox`, `snapshot_guard_targets`, and `assert_no_worktree_mutation`
  as shell functions. `setup_sandbox` creates the four subdirectories, exports
  the four env vars, and prints the fixture dir on stdout. Verification:
  `bash -c 'source tests/integration/lib/sandbox.sh && type setup_sandbox
  snapshot_guard_targets assert_no_worktree_mutation'` returns exit 0 with
  three `function` lines.
- **AC-3 (snapshot targets)**: `snapshot_guard_targets` captures sha256 for
  every path in this set: (a) the resolved targets (not the symlinks) of
  `.claude/commands/specialist:*.md`, (b) `bin/alm`, `bin/rws`, `bin/sds`,
  (c) `.furrow/almanac/todos.yaml`, (d) every file matching
  `.claude/rules/*.md`. Verification: `snapshot_guard_targets` produces a
  file whose line count equals the count of matching paths at invocation
  time.
- **AC-4 (CI-level empty-before-empty-after)**: `tests/integration/run-all.sh`
  exits non-zero when `git status --porcelain` is non-empty either before or
  after the suite; the offending output is printed to stderr.
  Verification: running `run-all.sh` in a clean worktree exits 0; running it
  after `touch foo` exits 1 with `foo` in stderr.
- **AC-5 (contamination regression)**: `tests/integration/test-sandbox-guard.sh`
  contains one scenario that invokes `assert_no_worktree_mutation` after
  writing to a protected path (via `FURROW_ROOT=$PROJECT_ROOT`); the
  scenario asserts exit code 1 and that stderr contains the offending path.
  Verification: `tests/integration/test-sandbox-guard.sh` exits 0 overall
  (the internal contamination case asserts the guard triggered).
- **AC-6 (documentation)**: `docs/architecture/testing.md` exists and contains
  H2 sections titled "Sandbox contract", "Env-var resolution order", and
  "Protected-path snapshot set"; each section is non-empty. Verification:
  `grep -c '^## ' docs/architecture/testing.md` returns at least 3.

## Test Scenarios

### Scenario: sandbox_isolates_all_four_env_vars

- **Verifies**: AC-1, AC-2
- **WHEN**: A test sources `tests/integration/lib/sandbox.sh` and calls
  `setup_sandbox` inside a fresh `mktemp -d` working dir
- **THEN**: `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `FURROW_ROOT`
  each resolve to a path prefixed by that `$TMP`; stdout contains the
  fixture-dir absolute path
- **Verification**:
  ```sh
  TMP=$(mktemp -d); cd "$TMP"
  . tests/integration/lib/sandbox.sh
  fixture=$(setup_sandbox)
  for v in HOME XDG_CONFIG_HOME XDG_STATE_HOME FURROW_ROOT; do
    eval "case \"\${$v}\" in \"$TMP\"/*) ;; *) exit 1;; esac"
  done
  test -d "$fixture"
  ```

### Scenario: snapshot_captures_symlink_targets_not_links

- **Verifies**: AC-3
- **WHEN**: `snapshot_guard_targets` runs against the live repo
- **THEN**: The digest for `.claude/commands/specialist:harness-engineer.md`
  equals the digest of `specialists/harness-engineer.md`, proving the snapshot
  followed the symlink per research Section B
- **Verification**:
  ```sh
  snapshot_guard_targets
  a=$(grep 'specialist:harness-engineer' "$TMP/guard.pre.sha256" | awk '{print $1}')
  b=$(sha256sum specialists/harness-engineer.md | awk '{print $1}')
  test "$a" = "$b"
  ```

### Scenario: run_all_blocks_on_dirty_precondition

- **Verifies**: AC-4
- **WHEN**: `tests/integration/run-all.sh` is invoked in a worktree where a
  tracked file has been modified but not committed
- **THEN**: `run-all.sh` exits 1 before any test runs; stderr contains the
  modified path
- **Verification**:
  ```sh
  echo x >> README.md
  if tests/integration/run-all.sh 2>err; then exit 1; fi
  grep -q README.md err
  git checkout README.md
  ```

### Scenario: deliberate_contamination_is_caught

- **Verifies**: AC-5
- **WHEN**: A subshell unsets the sandbox env vars, points `FURROW_ROOT` at
  `$PROJECT_ROOT`, writes a byte to `.furrow/almanac/todos.yaml`, and calls
  `assert_no_worktree_mutation`
- **THEN**: The function exits 1 and stderr names `.furrow/almanac/todos.yaml`
- **Verification**: `tests/integration/test-sandbox-guard.sh` runs this
  scenario in an isolated fixture (so the live `todos.yaml` is not mutated)
  and asserts the observed exit code equals 1

### Scenario: install_idempotency_adopts_sandbox

- **Verifies**: AC-1
- **WHEN**: `tests/integration/test-install-idempotency.sh` is statically
  inspected
- **THEN**: A call to `setup_sandbox` appears before any `install.sh` or
  `frw` invocation
- **Verification**:
  ```sh
  awk '/setup_sandbox/{s=NR} /install\.sh|bin\/frw|bin\/rws/{if(!s||NR<s)exit 1}' \
    tests/integration/test-install-idempotency.sh
  ```

## Implementation Notes

- **Research Section A** documents existing isolation is ad-hoc: every test
  uses `mktemp -d` but no shared helper enforces all four env vars. The new
  library consolidates the pattern rather than reinvent it.
- **Research Section A** notes `helpers.sh:94-95` unconditionally exports
  `FURROW_ROOT="$PROJECT_ROOT"`. This spec removes the unconditional export
  so `setup_sandbox` is the single source of truth for the four env vars
  (AD-1 canonical-resolver-reuse rationale applies by analogy).
- **Research Section B** enumerates the protected-path set verbatim: 14
  specialist symlinks, 3 binaries, `todos.yaml`, 2 rules files. After
  specialist-symlink-unification lands (wave-2, sibling deliverable), the
  count rises to 22 symlinks. Implementation uses a glob to be count-agnostic.
  Specialist symlinks are gitignored (AD-5), so the `git status --porcelain`
  check at run-all.sh pre/post is naturally unaffected by their creation.
- **Research Section C** lists the existing `test-merge-e2e.sh` fixture-setup
  patterns. The new sandbox library is orthogonal — fixture setup stays inside
  each test; only the env-var scope moves out.
- **Research Section D** confirms no centralized runner exists today. This
  spec creates `run-all.sh` as the single CI entrypoint. Individual tests
  remain directly executable (backward compatible).
- **Teardown ordering** (research Section D): the `EXIT` trap runs
  `teardown_fixtures` first, then `assert_no_worktree_mutation` — so the
  guard sees the post-teardown state, not the mid-test state.
- **POSIX sh constraint** (definition.yaml constraint #5): all three new
  files use `#!/bin/sh` shebangs. Use `command -v sha256sum` for portability;
  fall back to `shasum -a 256` if unavailable (BSD environments). Avoid
  bash-only constructs (`[[`, arrays, `$'...'`).
- **Hook model** (AD-4): this deliverable does not register hooks. The
  sibling `script-modes-fix` deliverable owns `bin/frw.d/hooks/` additions.

## Dependencies

- **Existing code reused**:
  - `tests/integration/helpers.sh` — assertion helpers preserved; global
    env-var export removed.
  - `mktemp -d` pattern from `test-install-*.sh` (research Section A).
- **Other deliverables**:
  - None. This is the wave-1 root; every other deliverable in
    definition.yaml depends on it (per team-plan.md Wave Map).
- **External**: `sha256sum` (coreutils) or `shasum -a 256` (macOS);
  `git status --porcelain` (git).
