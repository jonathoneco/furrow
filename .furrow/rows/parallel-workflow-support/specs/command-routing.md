# Spec: command-routing

## Overview

Update `/work` command routing (`commands/work.md`) and `detect-context.sh` to treat
multiple active work units as the normal happy path. The `.work/.focused` file (from
focus-infrastructure spec) names the focused unit; bare `/work` continues it silently.

Depends on: `focus-infrastructure` (provides `set_focus()`, `find_focused_work_unit()`,
`clear_focus()`, `extract_unit_from_path()` in `hooks/lib/common.sh`).

## Design Decisions (locked)

1. Bare `/work` with `.focused` pointing to a valid active unit continues that unit silently.
2. Bare `/work` without `.focused` + multiple active units prompts once, then writes `.focused`.
3. `/work --switch <name>` updates `.focused` and loads the new unit's step skill.
4. `/work <description>` creates a new unit and auto-focuses it (writes `.focused`).
5. Multiple active tasks is the normal state, not an error.

---

## File: `commands/work.md`

### New Routing Logic

Replace the current routing table with:

```
Bare /work (no description, no --switch):
  focused = find_focused_work_unit()

  focused is non-empty (valid active unit found)
    -> Continue that unit: read state.json, load skills/{step}.md
    -> If step_status is "completed": run step-transition.sh
    -> If step_status is "not_started": set to "in_progress", load skill
    -> After any transition: run auto-advance.sh

  focused is empty + 0 active units
    -> Error: "No active task. Provide a description to start new work."

  focused is empty + 1 active unit
    -> set_focus(name) on that unit
    -> Continue it (same as focused non-empty case above)

  focused is empty + N>1 active units
    -> List all active units with step, status, and updated_at
    -> Prompt user: "Multiple active tasks. Which do you want to continue?"
    -> On selection: set_focus(selected_name), continue that unit

/work <description> (description provided, no --switch):
  active_count = detect-context.sh count

  Any count (0, 1, or N)
    -> Create new work unit via init-work-unit.sh
    -> set_focus(new_name)
    -> Pass --mode and --gate-policy flags to init
    -> Set force_stop_at if --stop-at provided
    -> Load skills/ideate.md and begin ideation ceremony

  Note: existing active tasks are NOT an error. Creating while others
  are active is the whole point of parallel workflow support.

/work --switch <name> (no description):
  -> Validate .work/{name}/state.json exists
     If not: Error "Work unit '{name}' does not exist."
  -> Validate archived_at is null
     If not: Error "Work unit '{name}' is archived. Cannot switch to it."
  -> set_focus(name)
  -> Read state.json, load skills/{step}.md
  -> Display: task name, step, step_status, deliverable progress
  -> Continue execution within the current step

/work --switch <name> <description> (both provided):
  -> Error: "Cannot use --switch with a description. Use /work <description>
     to create a new unit, or /work --switch <name> to switch focus."
```

### Flag Parsing

The `--switch` flag is positional-agnostic but mutually exclusive with description:

```
/work --switch my-task          # valid: switch focus
/work --switch my-task --mode research  # error: --mode only for creation
/work my new feature            # valid: create new unit
/work --mode research my topic  # valid: create with mode
/work --switch my-task my desc  # error: --switch + description
```

Parsing order:
1. Scan args for `--switch <name>` and extract it.
2. Scan for `--mode`, `--stop-at`, `--gate-policy` flags.
3. Remaining args are the description (joined with spaces).
4. If `--switch` is present and description is non-empty, error.
5. If `--switch` is present and `--mode`/`--stop-at`/`--gate-policy` present, error:
   "Flags --mode, --stop-at, --gate-policy are only valid when creating a new work unit."

### Continuation Flow (unchanged logic, new entry points)

1. Read `.work/{name}/state.json`.
2. Display: task name, step, step_status, deliverable progress.
3. Run `commands/lib/load-step.sh "{name}"` to inject current skill.
4. Continue execution within the current step.

### New Work Initialization (updated)

1. Derive `{name}` from description (kebab-case, max 40 chars).
2. Run `commands/lib/init-work-unit.sh "{name}" "{description}"`.
3. **`set_focus(name)` to auto-focus the new unit.**
4. If `--mode research`: set `state.json.mode` to `"research"`.
5. If `--stop-at {step}`: set `state.json.force_stop_at` to step name.
6. If `--gate-policy {policy}`: pass to definition.yaml `gate_policy`.
7. Set `step_status` to `"in_progress"`.
8. Read and follow `skills/ideate.md` to begin ideation.

### Step Routing After Transition (unchanged)

After `step-transition.sh` advances the step:
1. Run `commands/lib/auto-advance.sh "{name}"` for trivial step detection.
2. If auto-advanced, repeat until a non-trivial step is reached.
3. Load the new step's skill and begin.

---

## File: `commands/lib/detect-context.sh`

### Current Behavior

- Scans `.work/*/state.json` for active tasks (archived_at is null).
- Outputs one task name per line on stdout.
- Outputs the count on stderr.
- Exit code is always 0.

### Changes Required

**None.** The script is already multi-unit aware. It correctly enumerates all active
units and reports the count. The routing logic change lives entirely in `commands/work.md`.

Callers already handle:
- 0 names on stdout = no active tasks
- 1 name on stdout = single active task
- N names on stdout = multiple active tasks

### Caller Interpretation Changes

The semantic shift is in `commands/work.md`, not in `detect-context.sh`:

| Scenario | Old interpretation | New interpretation |
|----------|-------------------|-------------------|
| 0 active + no desc | Error: no active task | Same (unchanged) |
| 0 active + desc | Create new unit | Create + set_focus |
| 1 active + no desc | Continue it | find_focused_work_unit() -> continue |
| 1 active + desc | **Error**: archive first | Create new unit + set_focus |
| N active + no desc | **Error**: disambiguate | find_focused_work_unit() -> continue or prompt |
| N active + desc | N/A (blocked by 1-active error) | Create new unit + set_focus |

The critical change: "1 active + desc" and "N active + desc" are no longer errors.
`detect-context.sh` output is used only to count active units for the "bare /work with
no .focused" fallback path.

---

## Edge Cases

### `--switch` to an archived unit

```
/work --switch old-task
```

Behavior:
- `set_focus()` validates `archived_at` and returns exit code 1.
- Error message: "Work unit 'old-task' is archived. Cannot switch to it."
- `.focused` file is NOT modified.

### `--switch` to the already-focused unit

```
/work --switch current-task   # where current-task is already in .focused
```

Behavior:
- `set_focus()` writes the same name (idempotent).
- Load step skill and continue as normal.
- No special "already focused" message -- treat as a regular switch.
- This is a no-op on the file but still loads the unit for continuation.

### Creating a new unit while `--switch` is provided

```
/work --switch my-task implement caching
```

Behavior:
- Error: "Cannot use --switch with a description. Use /work <description>
  to create a new unit, or /work --switch <name> to switch focus."
- No state changes.

### `.focused` pointing to an archived unit on bare `/work`

```
# .work/.focused contains "old-task", but old-task is archived
/work
```

Behavior:
- `find_focused_work_unit()` reads `.focused`, finds "old-task".
- Validates `archived_at` -- it is non-null (archived).
- Logs warning: `[harness:warning] Focused unit 'old-task' is archived, falling back`
- Falls through to `find_active_work_unit()` (most-recently-updated).
- If fallback finds an active unit: `set_focus()` is NOT called automatically
  (the focus-infrastructure spec says `find_focused_work_unit` does not auto-repair).
- Routing continues as if `.focused` did not exist:
  - 0 active -> error
  - 1 active -> set_focus + continue
  - N active -> prompt + set_focus

### `.focused` pointing to a deleted (non-existent) unit

Same as archived case: `find_focused_work_unit()` validates `state.json` existence,
fails, falls through to `find_active_work_unit()`.

### `--switch` to a non-existent unit

```
/work --switch nonexistent
```

Behavior:
- Check `.work/nonexistent/state.json` -- does not exist.
- Error: "Work unit 'nonexistent' does not exist."
- `.focused` file is NOT modified.

---

## Acceptance Criteria Verification

| Criterion | How to verify |
|-----------|---------------|
| Bare `/work` with valid `.focused` continues silently | Set `.focused` to active unit, run `/work`, verify continuation without prompt |
| Bare `/work` without `.focused` + 1 active sets focus | Remove `.focused`, ensure 1 active unit, run `/work`, verify `.focused` written |
| Bare `/work` without `.focused` + N active prompts | Remove `.focused`, ensure 2+ active units, run `/work`, verify prompt shown |
| `/work <desc>` creates and focuses regardless of active count | Have 2 active units, run `/work new thing`, verify new unit + `.focused` updated |
| `/work --switch` updates focus and loads unit | Switch to a different active unit, verify `.focused` and skill loaded |
| `/work --switch` to archived unit errors | Archive a unit, attempt switch, verify error message and `.focused` unchanged |
| `/work --switch` + description errors | Run `/work --switch x some desc`, verify error |
| Stale `.focused` degrades gracefully | Point `.focused` to archived/deleted unit, run bare `/work`, verify fallback |
| `detect-context.sh` output unchanged | Run script with 0, 1, N active units, verify output format identical to current |
| Creation flags rejected with `--switch` | Run `/work --switch x --mode research`, verify error |
