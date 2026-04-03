# /furrow:next [--phase N]

Generate handoff prompt(s) for the next row(s) on the roadmap.

## Syntax

```
/furrow:next           → Next unstarted phase
/furrow:next --phase 5 → Specific phase
```

---

## Behavior

### 1. Identify Next Work

1. Read `.furrow/almanac/roadmap.yaml`. Parse phase sections by status (`DONE`, `IN PROGRESS`, `PLANNED`).
2. If `--phase N` specified: use that phase. Error if phase doesn't exist.
3. Otherwise: find the first phase with status `PLANNED` or `IN PROGRESS`.
4. If all phases are `DONE`: "All roadmap phases complete. Run `/furrow:triage` to plan next work."

### 2. Extract Rows

From the target phase, extract each row:
- Branch name (`work/{name}`)
- TODO IDs contained in that row
- Parallelism notes (which rows can run concurrently)

### 3. Read TODO Context

For each TODO ID in the row(s):
- Read its `context` and `work_needed` from `.furrow/almanac/todos.yaml`
- Read its `depends_on`, `files_touched`

### 4. Check for Active Rows

Run `rws list` to find any active `.furrow/rows/*/state.json`.
If active rows exist that match a row in this phase, note them as "in progress".

### 5. Generate Handoff Prompt(s)

For each row in the phase, generate a self-contained handoff prompt block:

```
---

Start with: `/work {row-name} — {one-line description synthesized from TODOs}`

### Scope

{Sequential or parallel} deliverables on branch `work/{name}`.
See **.furrow/almanac/roadmap.yaml Phase {N}** for rationale and ordering.

Source TODOs in `.furrow/almanac/todos.yaml` (read `context` and `work_needed` for full detail):
{For each TODO: `{id}` — {title}}

### Key files
{Deduplicated files_touched from all TODOs in this row}
- `.furrow/almanac/todos.yaml` — detailed context and work_needed for each TODO
- `.furrow/almanac/roadmap.yaml` — Phase {N} plan and dependency reasoning

---
```

If the phase has **parallel rows**, generate one prompt block per row and prefix with:

```
Phase {N} has {M} parallel rows. Start each in a separate session/worktree:

{worktree commands from .furrow/almanac/roadmap.yaml for this phase}
```

If the phase has **sequential rows**, generate them in order and note:

```
Phase {N} has {M} sequential rows. Complete in order:
```

### 6. Output

Display the handoff prompt(s) directly — no confirmation needed. This is a read-only command.

---

## Constraints

- Read-only: does not modify `state.json`, `.furrow/almanac/todos.yaml`, or `.furrow/almanac/roadmap.yaml`
- Handoff prompts reference files by path, not by content — the fresh session reads them
- TODO prose (`context`, `work_needed`) is NOT duplicated in the prompt — the prompt points at `.furrow/almanac/todos.yaml`
- If a row spans multiple TODOs, the `/work` description synthesizes the theme, not each TODO title
