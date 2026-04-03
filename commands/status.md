# /status [name] [--update] [--all]

Display active task progress and suggest next action. Read-only -- never mutates state.

## Arguments

- `name` (optional): Specific row. If absent, shows focused row.
- `--update`: Generate structured developer status update.
- `--all`: List all active units in a compact table.

## Flag Validation

- `--all` and `--update` are mutually exclusive. If both are passed:
  -> Error: "--all and --update cannot be combined."
- If `--all` is provided with a `name` argument, `name` is ignored; `--all` takes precedence.

## Focused Unit Resolution

Used when no `name` argument and no `--all` flag:

1. Read `.furrow/.focused` — contains a row name.
2. Validate: `.furrow/rows/{name}/state.json` must exist and have `archived_at: null`.
3. If valid, that unit is focused.
4. If `.focused` is missing, empty, or references an invalid/archived unit:
   -> Fall back to the most-recently-updated active unit (by `state.json` mtime).
5. Never error on invalid `.focused` state — degrade silently to fallback.
6. If no active units exist at all:
   -> "No active tasks. Start with /work <description>."

## Default Behavior (bare `/status` or `/status <name>`)

1. Find task via `rws status [name]` or focused unit resolution (above).
2. Read `state.json` and `definition.yaml`.
3. Display:
   - Task name and title
   - Current step and step_status
   - Mode (code/research)
   - Deliverable completion: {completed}/{total}
   - **Focused: yes/no** (whether this row matches `.furrow/.focused`)
   - Gate history (last 3 entries)
4. Suggest next action:
   - `step_status: "not_started"` -> "Run `/work` to begin {step} step."
   - `step_status: "in_progress"` -> "Run `/work` to continue {step} step."
   - `step_status: "completed"` -> "Run `/work` to evaluate gate and advance."
   - `step_status: "blocked"` -> "Resolve blocker: {last fail gate evidence}."

## With --all

Run `rws list` to get every active (non-archived) row in a compact table. The focused row is marked with `*`.

```
  NAME                        STEP        STATUS        FOCUSED
* parallel-workflow-support   implement   in_progress   *
  api-redesign                research    not_started
  fix-login-bug               review      completed
```

Columns:
- **NAME**: row name (kebab-case)
- **STEP**: current step from state.json
- **STATUS**: step_status from state.json
- **FOCUSED**: `*` if this is the focused unit, blank otherwise

Sort order: focused unit first, then alphabetical by name.

No suggested-next-action or gate history in `--all` mode — the table is overview-only.

## With --update

1. Read `state.json`, `summary.md`, and recent `gates[]` entries.
2. Generate structured update in markdown:
   - **Done**: What was completed since last update.
   - **Next**: What is planned for the next session.
   - **Blockers**: Any blocking issues.
3. Output update suitable for stand-up or async status reporting.
