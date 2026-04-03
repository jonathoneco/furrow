# Spec: frw-init

## Interface Contract

```
frw init [--prefix <name>]
```

Initializes a project for Furrow use. Called by `/furrow:work` pre-flight when `.furrow/seeds/seeds.jsonl` or `.claude/furrow.yaml` is missing. Idempotent — skips already-completed steps.

### Behavior

1. **Seeds**: If `.furrow/seeds/seeds.jsonl` does not exist:
   - Derive prefix: use `--prefix` if provided, else lowercase dirname with non-alnum→dash
   - Run `sds init --prefix <prefix>`

2. **Directories**: Create if missing:
   - `.furrow/rows/`
   - `.furrow/almanac/`

3. **Config**: If `.claude/furrow.yaml` does not exist:
   - Copy template from `$FURROW_ROOT/.claude/furrow.yaml`
   - Auto-detect and fill:
     - `project.name`: from directory name
     - `project.repo`: from `git remote get-url origin` (extract owner/repo)
     - `stack.language`: from `go.mod` → go, `package.json` → typescript, `pyproject.toml` → python
     - `seeds.prefix`: match sds prefix
   - Print "Review .claude/furrow.yaml and fill in remaining fields"

4. **Report**: Print what was created/skipped.

### Exit Codes

- 0: success (all steps completed or skipped)
- 1: sds init failed

## Acceptance Criteria (Refined)

1. `frw init` in a bare directory creates `.furrow/{rows,almanac,seeds}` and `.claude/furrow.yaml`
2. `frw init` in an already-initialized project skips all steps, prints skip messages
3. `frw init --prefix myproj` passes the prefix to `sds init`
4. Auto-detection correctly identifies go/typescript/python from project files
5. Git repo owner/name extracted from `git remote get-url origin` for both HTTPS and SSH URLs
6. `/furrow:work` pre-flight (commands/work.md Route 2 step 0) invokes `frw init` when needed
7. commands/init.md updated to reference `frw init` as the implementation

## Implementation Notes

- `sds init` is an external CLI call (not sourced) — sds remains independent
- Template copy uses `cp`, not symlink — each project owns its config
- SSH URL parsing: `git@github.com:owner/repo.git` → `owner/repo`
- HTTPS URL parsing: `https://github.com/owner/repo.git` → `owner/repo`
- Stack detection order: go.mod first, then package.json, then pyproject.toml/requirements.txt

## Dependencies

- D1: frw-dispatcher-and-modules (dispatcher exists to route `frw init`)
- External: `sds` CLI must be on PATH
