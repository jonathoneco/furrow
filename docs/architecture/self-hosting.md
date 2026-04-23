# Self-Hosting Architecture

This document describes how the Furrow source repository differs from a consumer
installation, where boundaries are enforced, and why the distinction matters.

## Source form vs installed form

- The Furrow source repository contains a `.furrow/SOURCE_REPO` sentinel file that
  marks it as the authoritative source tree. `install.sh` detects this and branches
  into source-hosting mode, skipping consumer-only operations such as `.gitignore`
  bootstrap and XDG quarantine.
- An installed (consumer) checkout contains no `.furrow/SOURCE_REPO` sentinel. Symlinks
  under `.claude/commands/specialist:*.md` and `.claude/rules/` point into the Furrow
  source tree at absolute paths resolved at install time.
- Source-mode self-install regenerates in-repo symlinks using `../../specialists/X.md`
  and `../../.claude/rules/X.md` targets (relative to `.claude/commands/`), so the
  source repo's own commands work without relying on external paths.
- Consumer installs are additive: `install.sh` writes symlinks, merges `settings.json`
  hooks, and appends `.gitignore` entries without touching existing project files.
- The `INSTALL_MODE` variable (`source` | `consumer`) is exported and available to all
  sub-scripts called during installation, enabling conditional behavior without
  re-detecting the sentinel.

## Path differences

- In the Furrow source repository, row data lives under `.furrow/rows/`, almanac entries
  under `.furrow/almanac/`, and seed records under `.furrow/seeds/`. These are committed
  to the source repo as part of its own work-tracking state.
- In a consumer project, the equivalent `.furrow/` directory is created by `frw install`
  and contains `furrow.yaml` (project config), `rows/` (project rows), and `almanac/`
  (project almanac). It is separate from the Furrow source tree.
- XDG state for installs lives at `$XDG_STATE_HOME/furrow/{slug}/` (default
  `$HOME/.local/state/furrow/{slug}/`) and holds `install-state.json` and the `bak/`
  quarantine directory. This directory is never committed to either the source repo or
  the consumer project.
- Install-artifact backups (`.bak` files produced when `symlink()` displaces a regular
  file) are moved to `$XDG_STATE_HOME/furrow/{slug}/bak/` during install or legacy
  migration, keeping both the source and consumer working trees clean.
- The `repo_slug` is derived from the git repository's basename with non-alnum/non-hyphen
  characters normalized to `-`, so different consumer projects get isolated XDG state
  directories even when installed from the same Furrow source tree.

## Boundary enforcement points

- `.furrow/SOURCE_REPO` is the primary branching sentinel: `install.sh` (top-level) and
  `bin/frw.d/install.sh` both detect it early and route to source vs consumer logic.
  The refuse-copy guard (AC-A) exits 2 with `[furrow:error] refusing to copy
  .furrow/SOURCE_REPO into consumer project` if the sentinel appears in a target that is
  not the Furrow source root, preventing accidental propagation via `cp -r`.
- `bin/frw.d/hooks/pre-commit-typechange.sh` blocks any attempt to commit a type-change
  from regular file to symlink on the protected paths `bin/alm`, `bin/rws`, `bin/sds`,
  and `.claude/rules/*`. This prevents the working-tree contamination pattern where
  `install.sh` creates symlinks in the source repo's own `bin/` directory.
- `bin/frw.d/hooks/pre-commit-bakfiles.sh` blocks staging of `bin/*.bak` and
  `.claude/rules/*.bak` files, which are install-time artifacts that should live in
  `$XDG_STATE_HOME/furrow/` rather than the repository.
- `bin/frw.d/scripts/rescue.sh` provides a recovery path when the source repo's working
  tree has been contaminated: it restores the canonical file forms from HEAD, removes
  untracked `.bak` files, and re-validates the baseline via `baseline-check`.
- `bin/frw.d/scripts/ci-contamination-check.sh` (Enforcement-B2, landing TBD) is
  intended to run in CI and fail the build if symlinks or `.bak` files appear in the
  source repo's tracked files, providing a continuous boundary check independent of
  the pre-commit hooks.
- The symlink validator in `bin/frw.d/install.sh` (`_validate_symlinks`) iterates all
  `specialist:*.md` and `rules/*.md` symlinks after creation and calls `readlink -e`
  on each; any unresolved symlink causes `install.sh` to exit 1 with a diagnostic,
  completing the AC-B validator requirement deferred from Foundation step 1b.
