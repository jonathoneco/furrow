# Spec: rws-cli

## Overview

`rws` is a monolithic POSIX shell + jq CLI that unifies row lifecycle management. It absorbs 13+ standalone scripts and hook logic from the Furrow harness into a single `bin/rws` file (~1200 lines estimated) with case-dispatch subcommands. After `rws` is working, all absorbed scripts are deleted.

## Architecture

### Single-file monolith

`bin/rws` is a self-contained POSIX shell script. No external sourcing of library files (hooks/lib/common.sh, hooks/lib/validate.sh are folded in as internal functions). The only external dependency is `jq` (required) and `yq` (optional, for definition.yaml parsing).

### Dispatch pattern

```sh
#!/bin/sh
set -eu

# --- internal functions (not exposed) ---
# update_state(), record_gate(), advance_step(), ...

# --- subcommand dispatch ---
cmd="${1:-help}"
shift || true

case "$cmd" in
  init)        rws_init "$@" ;;
  transition)  rws_transition "$@" ;;
  status)      rws_status "$@" ;;
  list)        rws_list "$@" ;;
  archive)     rws_archive "$@" ;;
  gate-check)  rws_gate_check "$@" ;;
  load-step)   rws_load_step "$@" ;;
  rewind)      rws_rewind "$@" ;;
  diff)        rws_diff "$@" ;;
  focus)       rws_focus "$@" ;;
  regenerate-summary) rws_regenerate_summary "$@" ;;
  validate-summary)   rws_validate_summary "$@" ;;
  help|--help|-h)     rws_help ;;
  *)           echo "Unknown command: $cmd" >&2; rws_help >&2; exit 1 ;;
esac
```

### Path conventions

All paths use `.furrow/rows/` (never `.work/`). Row state lives at `.furrow/rows/<name>/state.json`. The `.furrow/.focused` file stores the focused row name. Config is read from `.claude/furrow.yaml`. Schema validation references `schemas/state.schema.json` relative to the rws script's installed location (resolved via the symlink target's parent).

### Furrow root resolution

`rws` resolves its own location via readlink to find the Furrow install root:

```sh
SCRIPT_PATH="$(readlink -f "$0")"
FURROW_ROOT="$(cd "$(dirname "$SCRIPT_PATH")" && cd .. && pwd)"
```

This is needed for locating `schemas/state.schema.json`, `skills/*.md`, and `evals/dimensions/`.

---

## Exit Codes (global)

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage / argument error |
| 2 | State file not found |
| 3 | Validation failed (schema, artifact, summary) |
| 4 | Sub-operation failed (gate record, advance, branch creation) |
| 5 | Wrong step_status (e.g., --confirm without pending_approval) |
| 6 | Policy violation (decided_by vs gate_policy) |
| 7 | Seed mismatch (reserved for seeds-row-integration) |

---

## Public Subcommands

### 1. `rws init`

**Interface:**
```
rws init <name> [--title T] [--mode M] [--gate-policy P] [--source-todo ID] [--seed-id ID]
```

**Arguments:**
- `name` (positional, required) -- kebab-case row name. Validated: `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`
- `--title T` -- human-readable title (defaults to `name`)
- `--mode M` -- `code` or `research` (defaults from `.claude/furrow.yaml` or `"code"`)
- `--gate-policy P` -- `supervised`, `delegated`, or `autonomous` (defaults from `.claude/furrow.yaml` or `"supervised"`)
- `--source-todo ID` -- TODO entry ID this row was created from (kebab-case validated)
- `--seed-id ID` -- pre-existing seed ID to link (validated via `sds show`; reserved for seeds-row-integration deliverable)

**Behavior:**
1. Validate `name` is kebab-case.
2. Check `.furrow/rows/<name>/` does not exist.
3. Read defaults from `.claude/furrow.yaml` (mode, gate_policy).
4. Capture `base_commit` via `git rev-parse HEAD`.
5. Generate ISO 8601 timestamp.
6. Create `.furrow/rows/<name>/reviews/` directory.
7. Write `state.json` via atomic temp-file + mv with fields:
   - `name`, `title`, `description` (= title), `step: "ideate"`, `step_status: "in_progress"`
   - `steps_sequence: ["ideate","research","plan","spec","decompose","implement","review"]`
   - `deliverables: {}`, `gates: []`, `force_stop_at: null`, `branch: null`
   - `mode`, `base_commit`, `seed_id: null`, `epic_seed_id: null`
   - `created_at`, `updated_at`, `archived_at: null`
   - `source_todo` (null if empty), `gate_policy_init` (null if empty)
8. Output: `Row initialized: .furrow/rows/<name>`

**Exit codes:**
- 0 -- success
- 1 -- usage error (missing name, invalid name format, invalid mode, invalid gate-policy)
- 2 -- row already exists

**Note:** `--seed-id` integration (auto-create seed, validate via `sds show`) is deferred to the seeds-row-integration deliverable. The `init` subcommand reserves the flag but initially only stores the value in `state.json.seed_id` without validation.

---

### 2. `rws transition --request`

**Interface:**
```
rws transition --request <name> <outcome> <decided_by> <evidence> [conditions_json]
```

**Arguments:**
- `name` (positional) -- row name
- `outcome` -- `pass`, `fail`, or `conditional`
- `decided_by` -- `manual`, `evaluated`, or `prechecked`
- `evidence` -- one-line summary string (non-empty)
- `conditions_json` -- JSON array of strings (required when outcome=conditional, forbidden otherwise)

**Behavior (request phase):**

1. Resolve state file at `.furrow/rows/<name>/state.json`. Verify exists.
2. Determine boundary: read `step`, compute `current_idx`, `next_idx`, `next_step`, form `boundary = "{current}->{next}"`.
3. If outcome != fail and current step is the last step (review): exit 3.
4. **Record gate** (internal `record_gate()`):
   - Validate boundary format (`{step}->{step}` with valid step names).
   - Validate outcome enum, decided_by enum.
   - Validate conditions: required for conditional, forbidden for non-conditional.
   - Append gate record to `gates[]` via `update_state()`.
   - Gate record: `{boundary, outcome, decided_by, evidence, [conditions], timestamp}`.
5. **Validate step artifacts** (internal `validate_step_artifacts()`): only on pass/conditional outcome. Checks per-boundary requirements (see Internal Functions section). On failure: exit 4.
6. **Handle fail outcome**: set `step_status = "in_progress"`, increment corrections on in-progress deliverables if step is implement or review, output message, exit 0.
7. **Wave conflict check**: at implement->review boundary in code mode, run `check_wave_conflicts()`. Non-blocking (warning only).
8. **Validate summary sections**: call internal `validate_summary()` on current step. On failure: exit 4.
9. **Phase split (supervised gating)**:
   - Read `gate_policy` from definition.yaml.
   - If supervised: set `step_status = "pending_approval"` via `update_state()`, output message instructing user to call `--confirm`, exit 0.
   - If delegated or autonomous: fall through to complete inline.
10. **Regenerate summary** (internal `regenerate_summary()`). Warning on failure.
11. **Advance step** (internal `advance_step()`). On failure: exit 4.
12. Output: `Transition complete: {boundary} ({outcome})`

**Exit codes:**
- 0 -- success (transition complete, or gate recorded + pending_approval)
- 1 -- usage error
- 2 -- state.json not found
- 3 -- cannot advance past review
- 4 -- sub-operation failed (gate record, artifact validation, summary validation, advance)

---

### 3. `rws transition --confirm`

**Interface:**
```
rws transition --confirm <name>
```

**Arguments:**
- `name` (positional) -- row name

**Behavior (confirm phase):**

1. Resolve state file. Verify exists.
2. Check `step_status == "pending_approval"`. If not: exit 5.
3. Determine boundary (same logic as request phase).
4. Read `gate_policy` from definition.yaml.
5. Read `decided_by` from the most recent gate record matching the current boundary.
6. **Policy enforcement**:
   - supervised: requires `decided_by == "manual"`. Else exit 6.
   - delegated: requires `decided_by in ["manual", "evaluated"]`. Else exit 6.
   - autonomous: all values accepted.
7. **Verdict nonce validation** (when `decided_by == "evaluated"`):
   - Locate verdict file in `.furrow/rows/<name>/gate-verdicts/{post_step|pre_step}-{step}.json`.
   - Locate prompt file in `.furrow/rows/<name>/gate-prompts/{post_step|pre_step}-{step}.yaml`.
   - Extract nonce from both. If prompt nonce is non-empty and doesn't match verdict nonce: exit 4.
8. **Regenerate summary**. Warning on failure.
9. **Advance step**. On failure: exit 4.
10. Output: `Transition complete: {boundary} (confirmed)`

**Exit codes:**
- 0 -- success
- 2 -- state.json not found
- 5 -- step_status is not pending_approval
- 6 -- decided_by violates gate_policy

---

### 4. `rws status`

**Interface:**
```
rws status [name]
```

**Arguments:**
- `name` (optional) -- row name. If omitted, uses focused row (via `find_focused_row()`).

**Behavior:**
1. Resolve row name (argument or focused).
2. Read `state.json` fields: name, title, step, step_status, mode, base_commit, branch, deliverables, gates, created_at, updated_at, archived_at, seed_id.
3. Output human-readable status:
   ```
   Row: <name>
   Title: <title>
   Step: <step> | Status: <step_status>
   Mode: <mode>
   Branch: <branch or "(none)">
   Deliverables: <completed>/<total>
     - <name>: <status> (wave <N>, corrections <N>)
   Gates: <count> recorded
   Created: <created_at>
   Updated: <updated_at>
   ```
4. If no name provided and no focused row found, list active rows and prompt user.

**Exit codes:**
- 0 -- success
- 1 -- usage error (no name and no focused row, or multiple active rows)
- 2 -- state.json not found

---

### 5. `rws list`

**Interface:**
```
rws list [--active|--archived|--all]
```

**Flags:**
- `--active` (default) -- rows where `archived_at` is null
- `--archived` -- rows where `archived_at` is non-null
- `--all` -- all rows

**Behavior:**
1. Scan `.furrow/rows/*/state.json`.
2. For each matching row, output one line: `<name>  <step>  <step_status>  <mode>`
3. Output count on stderr: `N row(s)`

**Exit codes:**
- 0 -- success (even if zero results)

---

### 6. `rws archive`

**Interface:**
```
rws archive <name>
```

**Arguments:**
- `name` (positional, required) -- row name

**Behavior:**
1. Resolve state file. Verify exists.
2. **Pre-condition checks** (all must pass, else exit 3):
   - Current step is `review`.
   - Step status is `completed`.
   - All deliverables have status `completed`.
   - A passing gate record exists for `implement->review` boundary.
3. Set `archived_at` to current ISO 8601 timestamp via `update_state()`.
4. Clear focus if archiving the focused row (`rm -f .furrow/.focused` if it matches).
5. Regenerate summary one final time.
6. Output: `Archived: <name>`

**Exit codes:**
- 0 -- success
- 1 -- usage error
- 2 -- state.json not found
- 3 -- pre-condition failed (with specific message)

---

### 7. `rws gate-check`

**Interface:**
```
rws gate-check <step> <def_path> <state_path>
```

**Arguments:**
- `step` -- current step name
- `def_path` -- path to definition.yaml
- `state_path` -- path to state.json

**Behavior:**
Structural pre-filter for gate evaluation. Determines if a step is eligible for pre-step evaluation (hint for the evaluator subagent, not a decision).

1. **Global exclusions**: ideate, implement, review always exit 1 (never pre-step eligible).
2. **force_stop_at**: if state's `force_stop_at` matches step, exit 1.
3. **Per-step criteria**:
   - **research**: code mode only, single deliverable, ACs reference file paths (contain `/`), context pointers don't reference directories.
   - **plan**: single deliverable, no depends_on.
   - **spec**: single deliverable, >= 2 acceptance criteria.
   - **decompose**: <= 2 deliverables, no inter-deliverable dependencies, all same specialist type.
4. Output on success: one-line description of why preconditions met.

**Exit codes:**
- 0 -- structural preconditions met (evidence on stdout)
- 1 -- structural preconditions NOT met

---

### 8. `rws load-step`

**Interface:**
```
rws load-step [name]
```

**Arguments:**
- `name` (optional) -- row name. If omitted, uses focused row.

**Behavior:**
1. Resolve row name and state file.
2. Read current step from state.json.
3. Locate skill file at `${FURROW_ROOT}/skills/${step}.md`.
4. Output Read instructions:
   ```
   Read and follow skills/<step>.md
   Read .furrow/rows/<name>/summary.md for context from previous steps.
   ```
5. If the most recent gate has outcome `conditional`, append conditions:
   ```
   CONDITIONAL PASS: The following conditions must be addressed this step:
   - <condition 1>
   - <condition 2>
   ```

**Exit codes:**
- 0 -- success
- 1 -- usage error
- 2 -- state.json not found
- 3 -- skill file not found

---

### 9. `rws rewind`

**Interface:**
```
rws rewind <name> <target_step>
```

**Arguments:**
- `name` (positional) -- row name
- `target_step` (positional) -- step to rewind to

**Behavior:**
1. Resolve state file. Verify exists.
2. Validate `target_step` is in `steps_sequence`. If not: exit 3.
3. Check `target_step` index <= current step index. If target is after current: exit 4.
4. Record a fail gate with boundary `{current_step}->{target_step}` (intentionally non-sequential), decided_by=manual, evidence="User rewound: pre-step evaluation was incorrect or step needs rework".
5. Set `step = target_step`, `step_status = "not_started"` via `update_state()`.
6. Output: `Rewound: {current_step} -> {target_step}. Artifacts preserved.`

**Exit codes:**
- 0 -- success
- 1 -- usage error
- 2 -- state.json not found
- 3 -- invalid target step (not in steps_sequence)
- 4 -- target step is after current step (cannot rewind forward)

---

### 10. `rws diff`

**Interface:**
```
rws diff [name]
```

**Arguments:**
- `name` (optional) -- row name. If omitted, uses focused row.

**Behavior:**
1. Resolve row name and state file.
2. Read `base_commit` from state.json.
3. If base_commit is empty, null, or "unknown": exit 2 with error.
4. Output:
   ```
   === Row Diff: <name> ===
   Base commit: <base_commit>
   Current HEAD: <HEAD>

   <git diff --stat base_commit..HEAD>
   ```

**Exit codes:**
- 0 -- success
- 1 -- usage error
- 2 -- state.json not found or no valid base_commit

---

### 11. `rws focus`

**Interface:**
```
rws focus [name|--clear]
```

**Arguments:**
- `name` (optional) -- row name to focus
- `--clear` -- remove focus file

**Behavior:**
- `rws focus <name>`: validate row exists and is not archived, write name to `.furrow/.focused`. Exit 1 if row not found or archived.
- `rws focus --clear`: remove `.furrow/.focused` (idempotent).
- `rws focus` (no args): print current focused row name, or "No focused row" if none.

**Exit codes:**
- 0 -- success
- 1 -- usage error or row not found / archived

---

### 12. `rws regenerate-summary`

**Interface:**
```
rws regenerate-summary [name]
```

**Arguments:**
- `name` (optional) -- row name. If omitted, uses focused row.

**Behavior:**
1. Resolve row name and state file.
2. Read state fields: title, step, step_status, mode, deliverables.
3. Read objective from definition.yaml (fallback to state.json description).
4. Extract settled decisions from gates array.
5. Compute context budget (if `scripts/measure-context.sh` exists).
6. List artifact paths (definition.yaml, state.json, plan.json, research.md, spec.md, etc.).
7. **Preserve agent-written sections** from existing summary.md: Key Findings, Open Questions, Recommendations (extracted via awk between `## ` headers).
8. Write summary.md atomically (temp file + mv) with sections:
   - `# {title} -- Summary`
   - `## Task` (objective)
   - `## Current State` (step, status, deliverables, mode)
   - `## Artifact Paths`
   - `## Settled Decisions`
   - `## Context Budget`
   - `## Key Findings` (preserved)
   - `## Open Questions` (preserved)
   - `## Recommendations` (preserved)
9. Validate all required sections are present (warning on stderr if missing).

**Exit codes:**
- 0 -- success
- 1 -- usage error
- 2 -- state.json not found

---

### 13. `rws validate-summary`

**Interface:**
```
rws validate-summary [name] [--step S]
```

**Arguments:**
- `name` (optional) -- row name. If omitted, uses focused row.
- `--step S` -- step name for step-aware validation rules

**Behavior:**
1. Resolve row name and locate summary.md.
2. If no summary.md exists: exit 0 (nothing to validate).
3. If last gate was decided_by=prechecked: exit 0 (auto-advanced, skip validation).
4. **Check required sections** exist: Task, Current State, Artifact Paths, Settled Decisions, Key Findings, Open Questions, Recommendations.
5. **Check agent-written sections** have >= 1 non-empty line each:
   - Key Findings, Open Questions, Recommendations.
   - Exception: during ideate step, only Open Questions is required.
6. Collect all errors and output on stderr.

**Exit codes:**
- 0 -- valid (or no summary, or auto-advanced step)
- 1 -- validation failure (errors on stderr)

---

## Internal Functions

These are defined inside `bin/rws` but not exposed as subcommands. They are called by the public subcommand functions.

### `update_state()`

**Signature:** `update_state <name> <jq_expression>`

**Behavior:**
1. Locate `.furrow/rows/<name>/state.json`. If missing: return 2.
2. Apply jq expression to state, with automatic `updated_at` timestamp injection: `<jq_expr> | .updated_at = $now`.
3. Write to temp file.
4. **Schema validation** (structural checks via jq):
   - Required fields: name, title, description, step, step_status, steps_sequence, deliverables, gates, mode, base_commit, created_at, updated_at, archived_at.
   - Enum validation: step (7 valid values), step_status (5 valid values), mode (code/research).
   - Type checks: steps_sequence is array of length 7, deliverables is object, gates is array.
   - Nullable string checks: archived_at, seed_id, epic_seed_id, force_stop_at, branch.
   - Deliverable entry validation: status enum, wave is number, corrections is number.
   - Gate entry validation: boundary format, outcome enum, decided_by enum, evidence non-empty, conditions required for conditional outcome.
5. On validation failure: remove temp file, return 3.
6. Atomic write: `mv` temp to state file.
7. Output: `State updated: <path>`

**Returns:** 0=success, 1=args, 2=not-found, 3=validation, 4=jq-failed

### `record_gate()`

**Signature:** `record_gate <name> <boundary> <outcome> <decided_by> <evidence> [conditions_json]`

**Behavior:**
1. Validate boundary format: `{step}->{step}` with valid step names on both sides.
2. Validate outcome enum: pass, fail, conditional.
3. Validate decided_by enum: manual, evaluated, prechecked.
4. Validate conditions: required for conditional, forbidden for non-conditional. Must be JSON array.
5. Build gate record JSON object with timestamp.
6. Append to gates array via `update_state()`.
7. Output: `Gate recorded: {boundary} ({outcome})`

**Returns:** 0=success, 1=args, 2=not-found, 3=validation

### `advance_step()`

**Signature:** `advance_step <name>`

**Behavior:**
1. Read current step, find index in steps_sequence.
2. If at final step: return 3.
3. Compute next step.
4. Verify passing gate record exists for `{current}->{next}` boundary. If none: return 4.
5. Set `step = next_step`, `step_status = "not_started"` via `update_state()`.
6. **Branch creation trigger**: at decompose->implement boundary, if `branch` is null/empty, call `create_work_branch()`.
7. Output: `Advanced: {current} -> {next}`

**Returns:** 0=success, 1=args, 2=not-found, 3=invalid-transition, 4=no-gate

### `validate_step_artifacts()`

**Signature:** `validate_step_artifacts <name> <boundary>`

**Behavior:**
Per-boundary artifact checks. Each boundary has specific requirements:

| Boundary | Required Artifacts |
|----------|-------------------|
| ideate->research | definition.yaml exists, non-empty, passes schema validation |
| research->plan | research.md or research/synthesis.md exists, non-empty, has >= 1 `## ` heading |
| plan->spec | If deliverable_count > 1: plan.json exists and passes validation |
| spec->decompose | spec.md or specs/*.md exist. If deliverable_count > 1: specs/ dir has a .md per deliverable |
| decompose->implement | plan.json exists and valid. branch field is non-null/non-empty |
| implement->review | Code mode: base_commit set, git diff shows changes. Research mode: deliverables/ dir has non-empty files |
| review->archive | reviews/ dir has .json per deliverable, each with `"overall": "pass"` |

**Returns:** 0=valid, 1=args, 2=not-found, 3=validation-failed

### `regenerate_summary()`

Same logic as the public `rws regenerate-summary` subcommand, but as an internal function callable from `transition` and `archive`. The public subcommand is a thin wrapper.

### `check_wave_conflicts()`

**Signature:** `check_wave_conflicts <name>`

**Behavior:**
1. Read `.furrow/rows/<name>/.unplanned_changes` file. If missing/empty: return 0 (clean).
2. Read `plan.json` for file_ownership assignments.
3. For each changed file, check if it falls within any specialist's file_ownership globs.
4. Report overlapping files on stderr.

**Returns:** 0=clean, 1=conflicts-detected, 2=missing-files

### `create_work_branch()`

**Signature:** `create_work_branch <name>`

**Behavior:**
1. Compute branch name: `work/<name>`.
2. If branch exists: `git checkout <branch>`.
3. If not: `git checkout -b <branch>`.
4. Record branch name in state.json via `update_state()`.

**Returns:** 0=success, 1=args, 2=not-found

### `find_focused_row()`

**Signature:** `find_focused_row`

**Behavior:**
1. Read `.furrow/.focused`. If file exists and contains a valid row name:
   - Verify `.furrow/rows/<name>/state.json` exists.
   - Verify row is not archived (`archived_at` is null). Fail-open on jq error.
   - Output `.furrow/rows/<name>`, return 0.
2. If .focused is stale/invalid: warn on stderr, fall through.
3. **Fallback**: scan `.furrow/rows/*/state.json` for most recently updated active row (highest `updated_at` among non-archived rows).
4. Output the found directory path, or empty string if none.

### `find_active_rows()`

**Signature:** `find_active_rows`

**Behavior:**
1. Scan `.furrow/rows/*/state.json`.
2. For each non-archived row: output name on stdout.
3. Output count on stderr.

---

## Domain Hooks Absorbed

These hooks are folded into `rws` subcommands and internal functions. They no longer exist as standalone hook scripts.

| Hook | Absorbed Into | Notes |
|------|--------------|-------|
| `hooks/gate-check.sh` | `rws transition` | Gate validation is internal to the transition flow |
| `hooks/summary-regen.sh` | `rws regenerate-summary` + automatic in transition | Summary regen triggered inside transition and exposed as subcommand |
| `hooks/timestamp-update.sh` | `update_state()` internal | Every `update_state()` call auto-updates `updated_at` |
| `hooks/transition-guard.sh` | Removed entirely | No longer needed -- there are no internal scripts to call directly. Agents call `rws transition`. |

## Hooks That Remain (updated to call rws)

These hooks stay as standalone hook scripts but are updated to call `rws` subcommands instead of internal scripts:

| Hook | Update |
|------|--------|
| `hooks/validate-summary.sh` | Calls `rws validate-summary` instead of inline logic |
| `hooks/correction-limit.sh` | Reads `.furrow/rows/` paths instead of `.work/` |
| `hooks/state-guard.sh` | Blocks writes to `.furrow/rows/*/state.json` (path updated) |
| `hooks/verdict-guard.sh` | Blocks writes to `.furrow/rows/*/gate-verdicts/` (path updated) |
| `hooks/ownership-warn.sh` | Reads `.furrow/rows/` paths instead of `.work/` |
| `hooks/stop-ideation.sh` | Uses `rws focus` resolution, reads `.furrow/rows/` paths |
| `hooks/work-check.sh` | Renamed to `hooks/row-check.sh`. Calls `rws validate-summary`, uses `.furrow/rows/` paths |
| `hooks/post-compact.sh` | Uses `rws status` and `rws load-step` for context recovery |

---

## Scripts Deleted After rws Is Working

All absorbed scripts are deleted (not stubbed). Total: 14 scripts + 4 hooks + 2 libraries.

### Scripts (scripts/)

1. `scripts/update-state.sh` -- absorbed into `update_state()` internal function
2. `scripts/record-gate.sh` -- absorbed into `record_gate()` internal function
3. `scripts/advance-step.sh` -- absorbed into `advance_step()` internal function
4. `scripts/validate-step-artifacts.sh` -- absorbed into `validate_step_artifacts()` internal function
5. `scripts/regenerate-summary.sh` -- absorbed into `regenerate_summary()` / `rws regenerate-summary`
6. `scripts/check-wave-conflicts.sh` -- absorbed into `check_wave_conflicts()` internal function
7. `scripts/create-work-branch.sh` -- absorbed into `create_work_branch()` internal function
8. `scripts/archive-work.sh` -- absorbed into `rws archive`
9. `scripts/work-unit-diff.sh` -- absorbed into `rws diff`

### Command libraries (commands/lib/)

10. `commands/lib/init-work-unit.sh` -- absorbed into `rws init`
11. `commands/lib/step-transition.sh` -- absorbed into `rws transition`
12. `commands/lib/detect-context.sh` -- absorbed into `find_active_rows()` internal function
13. `commands/lib/rewind.sh` -- absorbed into `rws rewind`
14. `commands/lib/load-step.sh` -- absorbed into `rws load-step`
15. `commands/lib/gate-precheck.sh` -- absorbed into `rws gate-check`

### Hook scripts (hooks/)

16. `hooks/gate-check.sh` -- gate validation folded into `rws transition`
17. `hooks/summary-regen.sh` -- summary regen folded into `rws transition` + `rws regenerate-summary`
18. `hooks/timestamp-update.sh` -- timestamp update folded into `update_state()`
19. `hooks/transition-guard.sh` -- no longer needed (agents call `rws` directly)

### Shared libraries (hooks/lib/)

20. `hooks/lib/common.sh` -- all functions folded into `bin/rws` internals
21. `hooks/lib/validate.sh` -- all validation functions folded into `bin/rws` internals

---

## Claude Code Command Updates

All Claude Code command files (under `commands/`) must be updated to call `rws` subcommands instead of the absorbed scripts:

| Command | Before | After |
|---------|--------|-------|
| `/furrow:work` | `commands/lib/init-work-unit.sh` | `rws init` |
| `/furrow:work` (resume) | `commands/lib/detect-context.sh` + `commands/lib/load-step.sh` | `rws list --active` + `rws load-step` |
| `/furrow:checkpoint` | `commands/lib/step-transition.sh` | `rws transition` |
| `/furrow:status` | inline state reads | `rws status` |
| `/furrow:archive` | `scripts/archive-work.sh` | `rws archive` |
| `/furrow:reground` | `hooks/post-compact.sh` logic | `rws status` + `rws load-step` |
| `/furrow:redirect` | `commands/lib/rewind.sh` | `rws rewind` |
| `/furrow:review` | `scripts/work-unit-diff.sh` | `rws diff` |

---

## Acceptance Criteria Verification

| AC | Verification |
|----|-------------|
| bin/rws exists as POSIX shell + jq | `file bin/rws` shows shell script, `shellcheck bin/rws` passes |
| rws init creates state.json | `rws init test-row && jq '.step' .furrow/rows/test-row/state.json` returns "ideate" |
| rws transition --request/--confirm | Create row, transition with supervised policy, verify pending_approval then confirm |
| rws status shows row state | `rws status test-row` outputs step, deliverables |
| rws list --active | Shows non-archived rows |
| rws archive marks archived | `rws archive <name> && jq '.archived_at' .furrow/rows/<name>/state.json` is non-null |
| rws gate-check runs pre-step filter | `rws gate-check research def.yaml state.json` exits 0 or 1 |
| rws load-step outputs skill content | `rws load-step test-row` outputs "Read and follow skills/ideate.md" |
| rws rewind steps back | `rws rewind test-row ideate` records fail gate and resets step |
| rws diff shows diff | `rws diff test-row` outputs git diff --stat |
| rws --help documents all subcommands | `rws --help` lists all 13 subcommands |
| No direct calls to absorbed scripts | `grep -rn 'advance-step\|record-gate\|init-work-unit\|step-transition\|detect-context\|validate-step-artifacts\|regenerate-summary\|gate-precheck\|archive-work\|work-unit-diff' commands/ hooks/ --include='*.sh' --include='*.md'` returns zero results (excluding this spec and deletion verification) |
| Absorbed scripts deleted | `ls scripts/update-state.sh` fails; same for all 20 listed files |
| Claude Code commands call rws | Spot-check: `grep 'rws ' commands/` shows rws invocations |
| Domain hooks folded | `hooks/gate-check.sh`, `hooks/summary-regen.sh`, `hooks/timestamp-update.sh`, `hooks/transition-guard.sh` do not exist |
| Policy hooks updated | `hooks/validate-summary.sh` calls `rws validate-summary`; `hooks/correction-limit.sh` uses `.furrow/rows/` paths |
| install.sh includes rws | `grep 'rws' install.sh` shows symlink entry |
