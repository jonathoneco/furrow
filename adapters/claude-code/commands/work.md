# /work Command — Claude Code Adapter

## Purpose
Main entry point for Furrow. Creates new rows or resumes active ones.

## Usage
```
/work [description]
```

## Behavior

### With no active row
If `description` is provided:
1. Initialize a new row directory at `.furrow/rows/{kebab-case-name}/`.
2. Create `state.json` with step set to `ideate` and status `not_started`.
3. Load `skills/ideate.md` for the ideation step.
4. Begin the ideation ceremony.

### With an active row
1. Run the work loader skill to discover and display current state.
2. Load the current step's skill file.
3. Continue work at the current step.

### With `--stop-at {step}` flag
Set `force_stop_at` in `state.json` to prevent auto-advance at the named step.

## Context Loading
This command triggers the work loader skill (`skills/work-loader.md`) which handles:
- Row discovery
- State reading and display
- Step skill injection
- Progressive context loading
- Pre-step evaluation via `rws gate-check` and `frw run-gate`

## State Initialization
New rows are initialized with:
```json
{
  "name": "{kebab-case-name}",
  "title": "{from description}",
  "description": "{from description}",
  "step": "ideate",
  "step_status": "not_started",
  "steps_sequence": ["ideate", "research", "plan", "spec", "decompose", "implement", "review"],
  "deliverables": {},
  "gates": [],
  "force_stop_at": null,
  "branch": null,
  "mode": "code",
  "base_commit": "{current git SHA}",
  "created_at": "{ISO 8601}",
  "updated_at": "{ISO 8601}",
  "archived_at": null
}
```
