# Spec: Post-Merge Cleanup

## Background

The beans-integration merge (Phase 4) restructured planning files under `.furrow/almanac/`:
- `_rationale.yaml` → `.furrow/almanac/rationale.yaml` (dropped underscore prefix)
- `todos.yaml` → `.furrow/almanac/todos.yaml`
- `roadmap.yaml` → `.furrow/almanac/roadmap.yaml`

Scripts, commands, and the `alm` CLI still reference the old locations.

---

## D1: cli-path-install

### Problem
`alm`, `rws`, `sds` exist in `bin/` but are not symlinked to `~/.local/bin`, making them unavailable without `export PATH=...bin:$PATH`.

### Changes

**Immediate fix**: Symlink all three CLIs to `~/.local/bin/`:
```sh
ln -sf <furrow-root>/bin/alm ~/.local/bin/alm
ln -sf <furrow-root>/bin/rws ~/.local/bin/rws
ln -sf <furrow-root>/bin/sds ~/.local/bin/sds
```

**Verification**: `which alm && which rws && which sds` all resolve.

### AC
- [x] alm, rws, sds symlinked to ~/.local/bin and runnable without full path
- [x] install.sh symlink logic verified end-to-end

---

## D2: script-path-fixes

### Problem
`furrow-doctor.sh` and `measure-context.sh` reference `$ROOT/_rationale.yaml` — the file is now at `$ROOT/.furrow/almanac/rationale.yaml`.

### Changes

**scripts/furrow-doctor.sh** — 6 replacements:

| Line | Old | New |
|------|-----|-----|
| 50 | `"$ROOT/_rationale.yaml"` | `"$ROOT/.furrow/almanac/rationale.yaml"` |
| 51 | `entries in _rationale.yaml` | `entries in rationale.yaml` |
| 59 | `Check 3: All _rationale.yaml paths` | `Check 3: All rationale.yaml paths` |
| 62 | `"$ROOT/_rationale.yaml"` | `"$ROOT/.furrow/almanac/rationale.yaml"` |
| 336 | `'$ROOT/_rationale.yaml'` (2 occurrences) | `'$ROOT/.furrow/almanac/rationale.yaml'` |
| 378 | `'$ROOT/_rationale.yaml'` | `'$ROOT/.furrow/almanac/rationale.yaml'` |

**scripts/measure-context.sh** — 3 replacements:

| Line | Old | New |
|------|-----|-----|
| 72 | `excludes _rationale.yaml` | `excludes rationale.yaml` |
| 142 | `"$ROOT/_rationale.yaml"` | `"$ROOT/.furrow/almanac/rationale.yaml"` |
| 143 | `_rationale.yaml:` | `rationale.yaml:` |

### AC
- [ ] furrow-doctor.sh checks .furrow/almanac/rationale.yaml
- [ ] measure-context.sh references .furrow/almanac/ paths
- [ ] furrow-doctor.sh passes with no path-related failures

---

## D3: command-spec-fixes

### Problem
Command markdown files reference `_rationale.yaml` at root and `todos.yaml` without the `.furrow/almanac/` prefix.

### Changes

**commands/furrow.md** — 3 replacements:

| Line | Old | New |
|------|-----|-----|
| 12 | `` `_rationale.yaml` `` | `` `.furrow/almanac/rationale.yaml` `` |
| 31 | `` `_rationale.yaml` `` | `` `.furrow/almanac/rationale.yaml` `` |
| 36 | `` `_rationale.yaml` `` | `` `.furrow/almanac/rationale.yaml` `` |

**commands/triage.md** — update `todos.yaml` references to `.furrow/almanac/todos.yaml` in user-facing paths/error messages:

| Line(s) | Context | Change |
|---------|---------|--------|
| 3 | Description | `todos.yaml` → `.furrow/almanac/todos.yaml` |
| 17 | Validate step | `todos.yaml exists at project root` → `todos.yaml exists at .furrow/almanac/` |
| 17 | Error msg | `"No todos.yaml found..."` → `"No .furrow/almanac/todos.yaml found..."` |
| 93 | Inferred deps | `comment in todos.yaml` → `comment in .furrow/almanac/todos.yaml` |
| 215 | Write step | `Update triage fields in todos.yaml` → `...in .furrow/almanac/todos.yaml` |
| 217 | Validate step | `revert todos.yaml` → `revert .furrow/almanac/todos.yaml` |
| 221-222 | Commit stage | `todos.yaml` → `.furrow/almanac/todos.yaml` |
| 237 | Error table | `No todos.yaml` → `No .furrow/almanac/todos.yaml` |
| 238 | Error table | `Invalid todos.yaml` → `Invalid .furrow/almanac/todos.yaml` |
| 249 | Constraints | `todos.yaml is the source of truth` → `.furrow/almanac/todos.yaml...` |

**commands/work-todos.md** — same pattern:

| Line(s) | Context | Change |
|---------|---------|--------|
| 3 | Description | `todos.yaml` → `.furrow/almanac/todos.yaml` |
| 37 | Load step | `Read todos.yaml at project root` → `Read .furrow/almanac/todos.yaml` |
| 112-113 | Commit block | `git add todos.yaml` → `git add .furrow/almanac/todos.yaml` |
| 143 | Check overlap | `Read todos.yaml` → `Read .furrow/almanac/todos.yaml` |
| 172-173 | Commit block | `git add todos.yaml` → `git add .furrow/almanac/todos.yaml` |
| 181 | Report | `Added TODO ... to todos.yaml` → `...to .furrow/almanac/todos.yaml` |

**commands/next.md** — same pattern:

| Line(s) | Context | Change |
|---------|---------|--------|
| 33 | Read step | `from todos.yaml` → `from .furrow/almanac/todos.yaml` |
| 55 | Prompt template | `Source TODOs in todos.yaml` → `...in .furrow/almanac/todos.yaml` |
| 60 | Key files | `todos.yaml — detailed context` → `.furrow/almanac/todos.yaml...` |
| 88-90 | Constraints | `todos.yaml` and `ROADMAP.md` → `.furrow/almanac/todos.yaml` and `.furrow/almanac/roadmap.yaml` |

**commands/archive.md** — same pattern:

| Line(s) | Context | Change |
|---------|---------|--------|
| 36 | Extract step | `against existing todos.yaml` → `...existing .furrow/almanac/todos.yaml` |
| 38-39 | Write step | `Writes to todos.yaml` → `...to .furrow/almanac/todos.yaml` |
| 43 | Pruning step | `read todos.yaml` → `read .furrow/almanac/todos.yaml` |
| 46-48 | Partial/validate | `todos.yaml` references → `.furrow/almanac/todos.yaml` |

**bin/alm** — remove stale fallback:

| Line(s) | Old | New |
|---------|-----|-----|
| 55-56 | `elif [ -f "./todos.yaml" ]; then` / `printf '%s' "./todos.yaml"` | Remove these two lines entirely |

The `ALM_TODOS` env var and explicit arg are sufficient. The `./todos.yaml` fallback masks misconfiguration.

### AC
- [ ] triage.md references .furrow/almanac/todos.yaml, not root todos.yaml
- [ ] All command specs reference .furrow/almanac/ paths
- [ ] bin/alm has no legacy ./todos.yaml fallback

---

## D4: skill-template-refs

### Problem
`skills/plan.md` tells the agent to produce `plan.json` but never references the template at `templates/plan.json` or describes the expected schema (`wave`, `deliverables`, `assignments`). The agent guesses a freeform structure and only discovers the real schema when `rws` validation rejects it.

### Changes

**skills/plan.md** — add template reference to "What This Step Produces" or "Step-Specific Rules":

Add after line 8 (`plan.json if parallel execution is needed`):
```
  Use `templates/plan.json` as the schema reference for plan.json structure.
```

Also check other step skills for the same gap — any skill that produces a templated artifact should reference its template.

### AC
- [ ] skills/plan.md references templates/plan.json for schema
- [ ] Any other step skills with templated artifacts also reference their templates

---

## D5: stale-state-cleanup

### Problem
`.furrow/.focused` contains `merge-specialist-and-legacy-todos` which is archived.

### Change
The file already points to `post-merge-cleanup` (set by `rws focus` during row creation). Verify it's correct after implementation.

### AC
- [x] .furrow/.focused set to active row (already done)
- [ ] No references to archived rows in active state

---

## Verification Plan

After all changes:
1. `which alm rws sds` — all resolve
2. `bash scripts/furrow-doctor.sh` — no path-related failures
3. `bash scripts/measure-context.sh` — rationale line count > 0
4. `alm validate` — if todos.yaml exists, passes
