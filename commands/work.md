# /work [description] [--mode research] [--stop-at <step>] [--gate-policy <policy>]

Primary entry point: start new work or continue existing.

## Context Detection

Run `commands/lib/detect-context.sh` to find active tasks, then route:

```
No active task + description provided
  -> Create new work unit via `commands/lib/init-work-unit.sh`
  -> Pass --mode and --gate-policy flags to init
  -> Set force_stop_at if --stop-at provided
  -> Load `skills/ideate.md` and begin ideation ceremony

No active task + no description
  -> Error: "No active task. Provide a description to start new work."

Active task + no description
  -> Continue: read state.json, load `skills/{step}.md`
  -> If step_status is "completed": run `commands/lib/step-transition.sh`
  -> If step_status is "not_started": set to "in_progress", load skill
  -> After any transition: run `commands/lib/gate-precheck.sh` then `scripts/run-gate.sh`

Active task + description provided
  -> Error: "Active task '{name}' exists. Archive it first."

Multiple active tasks
  -> List all active tasks with step and status
  -> Ask user which to continue
```

## New Work Initialization

1. Derive `{name}` from description (kebab-case, max 40 chars).
2. Run `commands/lib/init-work-unit.sh "{name}" "{description}"`.
3. If `--mode research`: set `state.json.mode` to `"research"`.
4. If `--stop-at {step}`: set `state.json.force_stop_at` to step name.
5. If `--gate-policy {policy}`: pass to definition.yaml `gate_policy`.
6. Set `step_status` to `"in_progress"`.
7. Read and follow `skills/ideate.md` to begin ideation.

## Continuation

1. Read `.work/{name}/state.json`.
2. Display: task name, step, step_status, deliverable progress.
3. Run `commands/lib/load-step.sh "{name}"` to inject current skill.
4. Continue execution within the current step.

## Step Routing After Transition

After `step-transition.sh` advances the step:
1. Run `commands/lib/gate-precheck.sh` to check if the next step is trivially resolvable.
2. If precheck passes, run `scripts/run-gate.sh` for evaluator confirmation.
3. If prechecked and confirmed, repeat until a non-trivial step is reached.
4. Load the new step's skill and begin.
