# /status [name] [--update]

Display active task progress and suggest next action. Read-only -- never mutates state.

## Arguments

- `name` (optional): Specific work unit. If absent, shows active task.
- `--update`: Generate structured developer status update.

## Default Behavior

1. Find task via `commands/lib/detect-context.sh` or by `name` argument.
2. Read `state.json` and `definition.yaml`.
3. Display:
   - Task name and title
   - Current step and step_status
   - Mode (code/research)
   - Deliverable completion: {completed}/{total}
   - Gate history (last 3 entries)
4. Suggest next action:
   - `step_status: "not_started"` -> "Run `/work` to begin {step} step."
   - `step_status: "in_progress"` -> "Run `/work` to continue {step} step."
   - `step_status: "completed"` -> "Run `/work` to evaluate gate and advance."
   - `step_status: "blocked"` -> "Resolve blocker: {last fail gate evidence}."

## With --update

1. Read `state.json`, `summary.md`, and recent `gates[]` entries.
2. Generate structured update in markdown:
   - **Done**: What was completed since last update.
   - **Next**: What is planned for the next session.
   - **Blockers**: Any blocking issues.
3. Output update suitable for stand-up or async status reporting.
