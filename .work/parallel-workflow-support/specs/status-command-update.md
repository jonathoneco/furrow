# Spec: Status Command Update for Parallel Workflows

## Current Behavior

`/status [name]` displays a single active task's details: name, title, step, step_status, mode, deliverable completion, gate history, and a suggested next action. Task discovery uses `commands/lib/detect-context.sh` or an explicit `name` argument.

## Changes

### Bare `/status` (no flags)

Behaves as today but adds a **focused indicator** line:

```
Task: parallel-workflow-support — Enable parallel active work units
Step: implement | Status: in_progress | Mode: code
Deliverables: 2/5
Focused: yes
```

The focused unit is determined by reading `.work/.focused`. If no `--all` flag is given and no `name` argument is provided, the command shows the focused unit.

### `/status --all`

Lists every active (non-archived) work unit in a compact table. The focused unit is marked with `*`.

```
  NAME                        STEP        STATUS        FOCUSED
* parallel-workflow-support   implement   in_progress   *
  api-redesign                research    not_started
  fix-login-bug               review      completed
```

Columns:
- **NAME**: work unit name (kebab-case)
- **STEP**: current step from state.json
- **STATUS**: step_status from state.json
- **FOCUSED**: `*` if this is the focused unit, blank otherwise

Sort order: focused unit first, then alphabetical by name.

No suggested-next-action or gate history in `--all` mode -- the table is overview-only.

### `/status <name>`

Shows full details for the named unit (same as current behavior plus focused indicator). Works regardless of whether the named unit is focused or dormant.

### `/status --all --update`

Not supported. `--all` and `--update` are mutually exclusive. If both are passed, show an error: `Error: --all and --update cannot be combined.`

## Focused Unit Resolution

1. Read `.work/.focused` -- contains a unit name (e.g., `parallel-workflow-support`).
2. Validate: the referenced `.work/{name}/state.json` must exist and have `archived_at: null`.
3. If valid, that unit is focused.
4. If `.work/.focused` is missing, empty, or references an invalid/archived unit, fall back to the **most-recently-updated** active unit (by `state.json` mtime).
5. Never error on invalid `.focused` state -- degrade silently to fallback.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No active units | `No active tasks. Start with /work <description>.` |
| One active unit, bare `/status` | Show that unit's details with `Focused: yes` |
| One active unit, `--all` | Table with one row, marked as focused |
| `.focused` points to archived unit | Fall back to most-recently-updated active unit |
| `.focused` points to nonexistent unit | Fall back to most-recently-updated active unit |
| `.focused` file missing | Fall back to most-recently-updated active unit |
| `--all` with `name` argument | `name` is ignored; `--all` takes precedence |

## File Ownership

- `commands/status.md` -- sole file modified by this deliverable

## Dependencies

- `focus-infrastructure` deliverable must be complete (provides `.work/.focused` and `find_focused_work_unit()`)
