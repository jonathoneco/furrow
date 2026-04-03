# /harness:next [--phase N]

Generate handoff prompt(s) for the next work unit(s) on the roadmap.

## Syntax

```
/harness:next           → Next unstarted phase
/harness:next --phase 5 → Specific phase
```

---

## Behavior

### 1. Identify Next Work

1. Read `ROADMAP.md`. Parse phase sections by status (`DONE`, `IN PROGRESS`, `PLANNED`).
2. If `--phase N` specified: use that phase. Error if phase doesn't exist.
3. Otherwise: find the first phase with status `PLANNED` or `IN PROGRESS`.
4. If all phases are `DONE`: "All roadmap phases complete. Run `/harness:triage` to plan next work."

### 2. Extract Work Units

From the target phase, extract each work unit:
- Branch name (`work/{name}`)
- TODO IDs contained in that work unit
- Parallelism notes (which units can run concurrently)

### 3. Read TODO Context

For each TODO ID in the work unit(s):
- Read its `context` and `work_needed` from `todos.yaml`
- Read its `depends_on`, `files_touched`

### 4. Check for Active Work Units

Run `commands/lib/detect-context.sh` to find any active `.work/*/state.json`.
If active units exist that match a work unit in this phase, note them as "in progress".

### 5. Generate Handoff Prompt(s)

For each work unit in the phase, generate a self-contained handoff prompt block:

```
---

Start with: `/work {work-unit-name} — {one-line description synthesized from TODOs}`

### Scope

{Sequential or parallel} deliverables on branch `work/{name}`.
See **ROADMAP.md Phase {N}** for rationale and ordering.

Source TODOs in `todos.yaml` (read `context` and `work_needed` for full detail):
{For each TODO: `{id}` — {title}}

### Key files
{Deduplicated files_touched from all TODOs in this work unit}
- `todos.yaml` — detailed context and work_needed for each TODO
- `ROADMAP.md` — Phase {N} plan and dependency reasoning

---
```

If the phase has **parallel work units**, generate one prompt block per unit and prefix with:

```
Phase {N} has {M} parallel work units. Start each in a separate session/worktree:

{worktree commands from ROADMAP.md for this phase}
```

If the phase has **sequential work units**, generate them in order and note:

```
Phase {N} has {M} sequential work units. Complete in order:
```

### 6. Output

Display the handoff prompt(s) directly — no confirmation needed. This is a read-only command.

---

## Constraints

- Read-only: does not modify `state.json`, `todos.yaml`, or `ROADMAP.md`
- Handoff prompts reference files by path, not by content — the fresh session reads them
- TODO prose (`context`, `work_needed`) is NOT duplicated in the prompt — the prompt points at `todos.yaml`
- If a work unit spans multiple TODOs, the `/work` description synthesizes the theme, not each TODO title
