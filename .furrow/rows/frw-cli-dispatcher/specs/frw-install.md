# Spec: frw-install

## Interface Contract

```
frw install --global              Install globally to ~/.claude
frw install --project <path>      Install into a specific project
frw install --check [<path>]      Verify installation (default: current project)
```

### install.sh (slimmed bootstrap)

```sh
#!/bin/sh
# install.sh — Bootstrap Furrow. Symlinks frw to PATH, then delegates.
set -eu
FURROW_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Detect user bin directory
# Symlink bin/frw to ~/.local/bin/frw (or ~/bin/frw)
# Symlink bin/sds, bin/rws, bin/alm similarly
# Then: exec frw install "$@"
```

~30 lines. Only job: get `frw` (and sds/rws/alm) on PATH, then delegate.

### frw install logic

Absorbs all current `install.sh` functionality:

1. **Commands**: Symlink `commands/*.md` → `$TARGET/commands/furrow:<name>.md`
2. **Specialists**: Symlink `specialists/*.md` → `$TARGET/commands/specialist:<name>.md`
3. **Rules**: Symlink `.claude/rules/*.md` → `$TARGET/rules/` (skip self-install)
4. **Hooks**: Write/merge `settings.json` with `frw hook <name>` commands
5. **Config**: Copy `furrow.yaml` template if missing
6. **CLAUDE.md**: Inject furrow activation block
7. **Directories**: Symlink `skills/`, `schemas/`, `evals/`, `specialists/`, `references/`, `adapters/`, `templates/`, `tests/` (NOT `hooks/` or `scripts/` — no longer needed)
8. **CLI tools**: Symlink `sds`, `rws`, `alm` to user bin (frw already symlinked by bootstrap)

### frw install --check

Verify mode. Checks all symlinks, settings.json hook patterns, CLAUDE.md block. Same output format as current `install.sh --check`.

## Acceptance Criteria (Refined)

1. `install.sh --global` bootstraps frw to PATH then delegates to `frw install --global`
2. `frw install --global` creates all symlinks in `~/.claude/` (commands, specialists, rules)
3. `frw install --project <path>` creates all symlinks in `<path>/.claude/`
4. `frw install --check` returns exit 0 if installed, exit 1 with issue count if not
5. `hooks/` and `scripts/` are NOT in the project root symlink list
6. settings.json uses `frw hook <name>` pattern (not `hooks/<name>.sh`)
7. install.sh is <=40 lines (bootstrap only)
8. Re-running install is idempotent (skip existing, update changed)

## Implementation Notes

- Preserve all helper functions from current install.sh: `_ok`, `_skip`, `_fail`, `_link`, `ensure_dir`, `_canonicalize`, `symlink`
- The `settings.json` merge logic (jq-based) moves into frw install
- CLAUDE.md injection block must be updated to reflect new command table (including frw:init, frw:doctor, frw:meta, frw:update)
- `--check` mode must verify `frw hook <name>` pattern in settings.json (not `hooks/<name>.sh`)

## Dependencies

- D1: frw-dispatcher-and-modules
- D2: hook-migration (settings.json pattern must match)
- D3: script-migration (symlink list must exclude hooks/scripts)
