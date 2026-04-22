# /work [description] [--mode research] [--stop-at <step>] [--gate-policy <policy>] [--switch <name>]

Primary entry point: start new work, continue existing, or switch between active rows.

## Flag Parsing

Scan arguments in order:
1. Extract `--switch <name>` if present (positional-agnostic).
2. Extract `--mode`, `--stop-at`, `--gate-policy` flags if present.
3. Remaining args are the description (joined with spaces).
4. If `--switch` is present and description is non-empty:
   -> Error: "Cannot use --switch with a description. Use /work <description> to create a new unit, or /work --switch <name> to switch focus."
5. If `--switch` is present and any of `--mode`, `--stop-at`, `--gate-policy` are present:
   -> Error: "Flags --mode, --stop-at, --gate-policy are only valid when creating a new row."

## Context Detection & Routing

### Route 1: `/work --switch <name>` (switch focus)

1. Validate `.furrow/rows/{name}/state.json` exists.
   If not: Error "Row '{name}' does not exist."
2. Validate `archived_at` is null.
   If not: Error "Row '{name}' is archived. Cannot switch to it."
3. Set focus: `rws focus "{name}"`
4. Read `state.json`, run `rws load-step "{name}"` to inject current skill.
5. Display: task name, step, step_status, deliverable progress.
6. Continue execution within the current step.
7. After any transition: run `frw run-gate` (gate enforcement happens inside `rws transition` itself).

### Route 2: `/work <description>` (create new row)

Any number of existing active tasks is fine — creating alongside them is expected.

0. **Pre-flight**: If `.furrow/seeds/seeds.jsonl` or `.furrow/furrow.yaml` does not exist,
   run `frw init` first (see `commands/init.md`). Do not proceed until init completes.
1. Derive `{name}` from description (kebab-case, max 40 chars).
2. Run `rws init "{name}" --title "{description}"`.
3. Set focus: `rws focus "{name}"`
4. If `--mode research`: set `state.json.mode` to `"research"`.
5. If `--stop-at {step}`: set `state.json.force_stop_at` to step name.
6. If `--gate-policy {policy}`: pass to definition.yaml `gate_policy`.
7. Set `step_status` to `"in_progress"`.
8. Read and follow `skills/ideate.md` to begin ideation.

### Route 3: Bare `/work` (no description, no --switch)

Resolve the focused row via `find_focused_row()` logic:

1. Read `.furrow/.focused` for the focused row name.
2. If `.focused` exists and names a valid active unit (state.json exists, `archived_at` is null):
   -> Continue that unit (go to Continuation below).
3. If `.focused` is missing, empty, or references an invalid/archived unit:
   -> Run `rws list` to enumerate active units.

   **0 active units:**
   -> Error: "No active task. Provide a description to start new work."

   **1 active unit:**
   -> Set focus: `echo '{name}' > .furrow/.focused`
   -> Continue that row (go to Continuation below).

   **Multiple active rows:**
   -> List all active rows with name, step, step_status, and updated_at.
   -> Prompt: "Multiple active tasks. Which do you want to continue?"
   -> On user selection: `echo '{selected_name}' > .furrow/.focused`
   -> Continue the selected unit (go to Continuation below).

## Continuation

1. Read `.furrow/rows/{name}/state.json`.
2. Display: task name, step, step_status, deliverable progress.
3. Run `rws load-step "{name}"` to inject current skill.
4. If step_status is "completed": run `rws transition "{name}"`.
5. If step_status is "not_started": set to "in_progress", load skill.
6. After any transition: run `frw run-gate` (gate enforcement, including step ordering and pending user actions, happens inside `rws transition` itself).
7. Continue execution within the current step.

## Step Routing After Transition

After `rws transition` advances the step:
1. Run `frw run-gate` for evaluator confirmation (pre-step evaluation is handled internally by `rws transition`).
2. If the step is trivially resolvable (prechecked), repeat until a non-trivial step is reached.
3. Load the new step's skill and begin.
