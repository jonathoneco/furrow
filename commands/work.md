# /work [description] [--mode research] [--stop-at <step>] [--gate-policy <policy>] [--switch <name>]

Primary entry point: start new work, continue existing, or switch between active units.

## Flag Parsing

Scan arguments in order:
1. Extract `--switch <name>` if present (positional-agnostic).
2. Extract `--mode`, `--stop-at`, `--gate-policy` flags if present.
3. Remaining args are the description (joined with spaces).
4. If `--switch` is present and description is non-empty:
   -> Error: "Cannot use --switch with a description. Use /work <description> to create a new unit, or /work --switch <name> to switch focus."
5. If `--switch` is present and any of `--mode`, `--stop-at`, `--gate-policy` are present:
   -> Error: "Flags --mode, --stop-at, --gate-policy are only valid when creating a new work unit."

## Context Detection & Routing

### Route 1: `/work --switch <name>` (switch focus)

1. Validate `.work/{name}/state.json` exists.
   If not: Error "Work unit '{name}' does not exist."
2. Validate `archived_at` is null.
   If not: Error "Work unit '{name}' is archived. Cannot switch to it."
3. Set focus: `echo '{name}' > .work/.focused`
4. Read `state.json`, load `skills/{step}.md`.
5. Display: task name, step, step_status, deliverable progress.
6. Continue execution within the current step.

### Route 2: `/work <description>` (create new unit)

Any number of existing active tasks is fine — creating alongside them is expected.

1. Derive `{name}` from description (kebab-case, max 40 chars).
2. Run `commands/lib/init-work-unit.sh "{name}" "{description}"`.
3. Set focus: `echo '{name}' > .work/.focused`
4. If `--mode research`: set `state.json.mode` to `"research"`.
5. If `--stop-at {step}`: set `state.json.force_stop_at` to step name.
6. If `--gate-policy {policy}`: pass to definition.yaml `gate_policy`.
7. Set `step_status` to `"in_progress"`.
8. Read and follow `skills/ideate.md` to begin ideation.

### Route 3: Bare `/work` (no description, no --switch)

Resolve the focused unit via `find_focused_work_unit()` logic:

1. Read `.work/.focused` for the focused unit name.
2. If `.focused` exists and names a valid active unit (state.json exists, `archived_at` is null):
   -> Continue that unit (go to Continuation below).
3. If `.focused` is missing, empty, or references an invalid/archived unit:
   -> Run `commands/lib/detect-context.sh` to enumerate active units.

   **0 active units:**
   -> Error: "No active task. Provide a description to start new work."

   **1 active unit:**
   -> Set focus: `echo '{name}' > .work/.focused`
   -> Continue that unit (go to Continuation below).

   **Multiple active units:**
   -> List all active units with name, step, step_status, and updated_at.
   -> Prompt: "Multiple active tasks. Which do you want to continue?"
   -> On user selection: `echo '{selected_name}' > .work/.focused`
   -> Continue the selected unit (go to Continuation below).

## Continuation

1. Read `.work/{name}/state.json`.
2. Display: task name, step, step_status, deliverable progress.
3. Run `commands/lib/load-step.sh "{name}"` to inject current skill.
4. If step_status is "completed": run `commands/lib/step-transition.sh`.
5. If step_status is "not_started": set to "in_progress", load skill.
6. After any transition: run `commands/lib/auto-advance.sh`.
7. Continue execution within the current step.

## Step Routing After Transition

After `step-transition.sh` advances the step:
1. Run `commands/lib/auto-advance.sh "{name}"` for trivial step detection.
2. If auto-advanced, repeat until a non-trivial step is reached.
3. Load the new step's skill and begin.
