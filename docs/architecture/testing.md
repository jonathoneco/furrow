# Testing Architecture

Integration tests under `tests/integration/` must never mutate the live
worktree. This document captures the sandbox contract, the env-var resolution
order, and the protected-path snapshot set enforced by every install/upgrade
test.

## Sandbox contract

Every integration test that touches the harness (invokes `frw`, `rws`, `alm`,
`sds`, or `install.sh`) MUST call `setup_sandbox` before any such invocation.
The contract is implemented in `tests/integration/lib/sandbox.sh` and sourced
transparently by `tests/integration/helpers.sh`.

`setup_sandbox`:

- Allocates `$TMP` via `mktemp -d` if unset.
- Creates `$TMP/home`, `$TMP/config`, `$TMP/state`, `$TMP/fixture`.
- Exports `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `FURROW_ROOT` so
  each resolves inside `$TMP`.
- Prints the fixture directory (`$TMP/fixture`) on stdout.
- Returns exit 0 on success, non-zero on any `mkdir` failure.

After `setup_sandbox` returns, no code path inside the test may resolve any
of the four env vars to a path outside `$TMP`. In particular, tests MUST
invoke the real on-disk binary via `"$PROJECT_ROOT/bin/frw"` (the real
executable exposed by `helpers.sh`), not via `"$FURROW_ROOT/bin/frw"` (the
sandboxed, empty install root).

The contract also requires:

- `snapshot_guard_targets` captures sha256 sums for the protected path set
  (see below) to `$TMP/guard.pre.sha256` before any test runs.
- `assert_no_worktree_mutation` recomputes sha256 sums after tests finish
  and exits 1 if any protected path drifted, printing the offending path(s)
  and pre/post digests to stderr.

Teardown ordering: per-test fixture cleanup runs first (`trap 'rm -rf ...' EXIT`
inside each test function), then `assert_no_worktree_mutation` runs at the end
of the script — so the guard observes the post-teardown state, not mid-test
state.

## Env-var resolution order

Harness code reads configuration via the three-tier resolver at
`bin/frw.d/lib/common.sh` (`resolve_config_value`): project-local
`.furrow/furrow.yaml` → XDG (`$XDG_CONFIG_HOME/furrow/config.yaml`) → compiled-in
default at `FURROW_ROOT/.furrow/furrow.yaml`. During integration tests each
tier points inside `$TMP`:

| Tier | Env var | Test-time location |
|------|---------|--------------------|
| Project | (no env var — inferred from cwd) | `$TMP/fixture/.furrow/furrow.yaml` or per-test fixture |
| XDG | `XDG_CONFIG_HOME` | `$TMP/config/furrow/config.yaml` |
| Fallback | `FURROW_ROOT` | `$TMP/fixture/.furrow/furrow.yaml` |
| State | `XDG_STATE_HOME` | `$TMP/state/furrow/<slug>/install-state.json` |
| Home | `HOME` | `$TMP/home` (so tools that read `$HOME` stay inside $TMP) |

`FURROW_ROOT` is the sandbox view of an "installed" Furrow root — it is empty
by default. Tests that need the real harness binary invoke it via
`"$PROJECT_ROOT/bin/frw"`; the binary then computes its own `FURROW_ROOT`
from its script path (see `bin/frw` line 8), so the binary's code paths
resolve against the real repo while the tested-process env stays sandboxed.

## Protected-path snapshot set

`snapshot_guard_targets` captures sha256 sums for every path in this set:

1. **Specialist symlink targets** — resolved targets of
   `.claude/commands/specialist:*.md`. The snapshot follows symlinks so a
   link-hijack that silently retargets a specialist still produces a digest
   drift.
2. **Harness binaries** — `bin/alm`, `bin/rws`, `bin/sds` (regular files).
3. **Almanac todos** — `.furrow/almanac/todos.yaml`.
4. **Claude rules** — every file under `.claude/rules/*.md`.

The set is discovered by glob at snapshot time. Adding a new specialist or a
new `.claude/rules/*.md` file widens the guard automatically — the line count
in `$TMP/guard.pre.sha256` equals the count of matching paths at invocation.

## Run-all invariant

`tests/integration/run-all.sh` is the central CI entrypoint. It asserts:

1. `git status --porcelain` is empty before any test runs (non-empty fails).
2. Every `tests/integration/test-*.sh` runs in a subshell with `set -e`.
3. `git status --porcelain` is empty after the suite (non-empty fails).

Individual test files remain directly executable for local development — the
per-test `assert_no_worktree_mutation` is the inner guard; `run-all.sh` is
the outer one. Both must be clean for a green suite.

## POSIX sh constraint

`lib/sandbox.sh`, `run-all.sh`, and `test-sandbox-guard.sh` are pure POSIX sh
(shebang `#!/bin/sh`). They avoid `[[`, arrays, and `$'...'`. The sha256
implementation prefers `sha256sum` (coreutils) and falls back to
`shasum -a 256` (macOS / BSD). Pre-existing `#!/bin/bash` test files are
left as-is; they interact with the POSIX sandbox library through shell-agnostic
function contracts.
