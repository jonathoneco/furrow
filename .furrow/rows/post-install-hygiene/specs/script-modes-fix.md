# Spec: script-modes-fix

**Wave**: 2
**Specialist**: harness-engineer
**Depends on**: test-isolation-guard

## Interface Contract

### File-mode promotion (metadata only)
Promote **20 tracked scripts** under `bin/frw.d/scripts/` from git mode
`100644` to `100755`. Verified at spec-time via `git ls-files -s
bin/frw.d/scripts/ | awk '$1 != "100755"' | wc -l` → `20` (research's
"19" figure was off-by-one). The full set: `check-artifacts.sh`,
`cross-model-review.sh`, `doctor.sh`, `evaluate-gate.sh`,
`generate-plan.sh`, `measure-context.sh`, `merge-lib.sh`,
`merge-to-main.sh`, `migrate-to-furrow.sh`, `rescue.sh`,
`run-ci-checks.sh`, `run-gate.sh`, `run-integration-tests.sh`,
`select-dimensions.sh`, `select-gate.sh`, `update-deliverable.sh`,
`update-state.sh`, `upgrade.sh`, `validate-definition.sh`,
`validate-naming.sh`.

**Mechanism**: `git update-index --chmod=+x <path>` per file, single commit.
No content change — the mode bit is the sole mutation.

**Ownership note**: This deliverable does NOT own the content of
`bin/frw.d/scripts/*.sh`. File-mode changes are metadata-only and do not
conflict with content-level file_ownership held by other deliverables
(e.g., `cross-model-review.sh` content is owned by
`cross-model-per-deliverable-diff`). Reviewers MUST NOT flag the mode-only
diff as an ownership collision.

### New hook: `bin/frw.d/hooks/pre-commit-script-modes.sh`
- **Shebang**: `#!/bin/sh` (POSIX sh per constraint #5)
- **Invocation**: merged into `.claude/settings.json` by `install.sh`
  per AD-4 (hooks register via settings.json, not `.git/hooks`).
- **Behavior**: Iterates every `bin/frw.d/scripts/*.sh` in the staged tree.
  For any file whose git index mode is `100644`, exits non-zero with
  message `pre-commit-script-modes: <path> must be 100755`. Clean tree
  exits 0.
- **Stdin/stdout**: no stdin; diagnostics on stderr; exit code is the signal.

### Dispatcher invariant
`bin/frw`'s `exec` path for `rescue` (line 207) remains identical to
`merge-sort-union` (line 184) — no dispatcher special-case. After the
mode promotion, `exec "$FURROW_ROOT/bin/frw.d/scripts/rescue.sh" "$@"` no
longer returns `EACCES` (research `install-artifacts.md` Section A).

## Acceptance Criteria (Refined)

1. **Git-mode promotion** — After the implement commit, `git ls-files -s
   bin/frw.d/scripts/ | awk '$1 != "100755"'` returns zero lines. The
   20 previously-100644 scripts now ship as 100755; no script's content
   was modified (verified by `git show HEAD` containing only `old mode
   100644 / new mode 100755` entries, zero content hunks).
2. **`rescue --diagnose` returns exit 0** — `bin/frw rescue --diagnose`
   runs to completion on a clean worktree and exits 0. Previously it
   failed with `exec: permission denied`.
3. **Hook exists and rejects regressions** — File
   `bin/frw.d/hooks/pre-commit-script-modes.sh` exists with shebang
   `#!/bin/sh` and mode 100755; running it after staging any
   `bin/frw.d/scripts/*.sh` at mode 100644 exits non-zero and prints the
   offending path on stderr.
4. **Hook is registered via `.claude/settings.json`** — `install.sh`
   merges `pre-commit-script-modes` into `.claude/settings.json` under
   the same `hooks.PreToolUse` (or equivalent pre-commit) entry as
   existing hooks. A fresh install into a sandbox fixture produces a
   `settings.json` that contains the string `pre-commit-script-modes`.
5. **Regression test `tests/integration/test-script-modes.sh`** —
   Asserts every `bin/frw.d/scripts/*.sh` is mode 100755 via
   `git ls-files -s`. Any non-executable script causes exit 1 with the
   offending name printed.
6. **Regression test `tests/integration/test-rescue.sh`** — Runs
   `bin/frw rescue --diagnose` inside the sandbox (uses `setup_sandbox`
   per test-isolation-guard contract) and asserts exit 0.
7. **No dispatcher special-case** — `bin/frw`'s exec path at line 207 is
   textually identical to the exec paths for every other subcommand
   (e.g., line 184 for merge-sort-union). Verified by `grep -nE
   '^[[:space:]]*exec "\$FURROW_ROOT/bin/frw\.d/scripts/' bin/frw` —
   all matches share the same shape (`exec "$FURROW_ROOT/bin/frw.d/scripts/<name>.sh" "$@"`),
   no rescue-specific branch.

## Test Scenarios

### Scenario: all scripts ship as 100755
- **Verifies**: AC-1, AC-5
- **WHEN**: The implement commit is merged and
  `tests/integration/test-script-modes.sh` runs inside the sandbox.
- **THEN**: Test exits 0. If any script later regresses to 100644, the
  test exits 1 and prints the offending path.
- **Verification**:
  ```sh
  git ls-files -s bin/frw.d/scripts/ | awk '$1 != "100755" { print $4; exit 1 }'
  ```

### Scenario: rescue --diagnose succeeds after mode fix
- **Verifies**: AC-2, AC-6
- **WHEN**: `setup_sandbox` prepares an install fixture, `install.sh`
  runs into it, then `bin/frw rescue --diagnose` is invoked.
- **THEN**: Command exits 0; stderr does not contain "Permission
  denied"; stdout contains the diagnose preamble.
- **Verification**:
  ```sh
  setup_sandbox
  install.sh >/dev/null
  bin/frw rescue --diagnose; test $? -eq 0
  ```

### Scenario: pre-commit hook catches a 100644 regression
- **Verifies**: AC-3, AC-4
- **WHEN**: A developer stages a new script at mode 100644 via
  `git update-index --add --cacheinfo 100644,<sha>,bin/frw.d/scripts/new.sh`
  and the pre-commit hook fires.
- **THEN**: Hook exits non-zero; stderr contains
  `pre-commit-script-modes: bin/frw.d/scripts/new.sh must be 100755`.
  The commit is blocked.
- **Verification**:
  ```sh
  ./bin/frw.d/hooks/pre-commit-script-modes.sh 2>&1 | \
    grep -q "must be 100755" && test ${PIPESTATUS[0]} -ne 0
  ```

## Implementation Notes

- **Mode-promotion commit**: Use one atomic commit
  `fix(scripts): promote 20 harness scripts to 100755`; body lists each
  path. No content diff — reviewers can confirm via
  `git show --stat HEAD | grep -v '^ bin/frw.d/scripts'` being empty and
  `git show HEAD` containing only `old mode 100644 / new mode 100755`
  entries.
- **Hook placement**: Follow the pattern of
  `bin/frw.d/hooks/pre-commit-bakfiles.sh` — POSIX sh, called by a git
  pre-commit dispatcher, short exit-on-first-error loop. See
  `install-artifacts.md` Section B for the existing hook inventory and
  dispatch model.
- **settings.json merge**: Reuse the `jq -s` merge pattern already in
  `bin/frw.d/install.sh:602-630` (quoted in `install-artifacts.md`
  Section B). Do NOT write a second merge helper.
- **Sandbox**: All new tests MUST call
  `tests/integration/lib/sandbox.sh::setup_sandbox` from the
  wave-1 `test-isolation-guard` deliverable; never touch the live
  worktree under any failure path (constraint #4 in definition.yaml).
- **Out of scope**: No rename tracing, no shebang audits, no rewrite of
  script contents. Mode bits only.

## Dependencies

- **Wave-1 prereq**: `test-isolation-guard` — provides
  `tests/integration/lib/sandbox.sh::setup_sandbox` which both new tests
  adopt.
- **install.sh merge machinery**: existing `jq -s` block in
  `bin/frw.d/install.sh:602-630` — consumed, not modified.
- **bin/frw dispatcher**: untouched; the fix is metadata-only upstream
  of the exec call site (line 207).
- **No runtime dependency** on other wave-2 deliverables — all six
  wave-2 deliverables operate on disjoint files per the plan's
  ownership analysis.
