## Research: Parallel Workflow Support

### R1: `find_active_work_unit()` — The Bottleneck

Located in `hooks/lib/common.sh`. Iterates `.work/*/state.json`, filters by `archived_at == "null"`,
returns the **most recently updated** unit directory. Called by 6+ hooks and used as the sole
mechanism for unit resolution.

**Key insight**: This function is a correct single-unit heuristic that becomes ambiguous with multiple
active units. It cannot be "fixed" — it must be replaced by two purpose-specific functions.

### R2: Hook Input Mechanism

All PreToolUse/PostToolUse hooks receive stdin JSON:
```json
{"tool_name": "Write", "tool_input": {"file_path": "...", ...}}
```
Path extraction pattern used everywhere:
```sh
target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""')"
```
Bash hooks extract `.tool_input.command`. Stop/PostCompact hooks receive **no stdin** — they
must resolve units from disk.

**Key insight**: We cannot modify Claude Code's hook JSON schema. Path-scoped hooks can extract
the unit from the target path. Session-scoped hooks need `.work/.focused`.

### R3: Complete Hook Inventory & Scoping Strategy

| Hook | Event | Input | Current Resolution | New Strategy |
|------|-------|-------|--------------------|--------------|
| state-guard.sh | PreToolUse (Write\|Edit) | stdin JSON | Path-based (no unit lookup) | **No change** |
| timestamp-update.sh | PostToolUse (Write\|Edit) | stdin JSON | find_active_work_unit() | **Path-scoped** |
| ownership-warn.sh | PreToolUse (Write\|Edit) | stdin JSON | find_active_work_unit() | **Path-scoped** |
| summary-regen.sh | PostToolUse (Write\|Edit) | stdin JSON | find_active_work_unit() | **Path-scoped** |
| validate-definition.sh | PreToolUse (Write\|Edit) | stdin JSON | Path-based (no unit lookup) | **No change** |
| correction-limit.sh | PreToolUse (Write\|Edit) | stdin JSON | Inline discovery | **Path-scoped** |
| gate-check.sh | PreToolUse (Bash) | stdin JSON | find_active_work_unit() | **Command-scoped** |
| stop-ideation.sh | Stop | No stdin | Inline discovery | **Focus-scoped** |
| validate-summary.sh | Stop | No stdin | Inline discovery | **Focus-scoped** |
| work-check.sh | Stop | No stdin | find_active_work_unit() | **All-units** |
| post-compact.sh | PostCompact | No stdin | find_active_work_unit() | **Focus-scoped** |

**Newly identified**: `validate-summary.sh` — not in original scope, needs same treatment as
`stop-ideation.sh` (focus-scoped).

### R4: `is_work_unit_file()` — Existing Helper

`common.sh` already has `is_work_unit_file(path)` that checks if a path is inside `.work/`.
This can be extended to also extract the unit name — the building block for `extract_unit_from_path()`.

### R5: Archive Flow

`scripts/archive-work.sh` takes a unit name, validates preconditions (step=review, status=completed,
all deliverables completed, passing implement->review gate), then sets `archived_at`. No knowledge
of `.focused` — needs a single addition: clear `.focused` if the archived unit matches.

### R6: Status Command

`commands/status.md` accepts optional `name` argument. Uses `detect-context.sh` to find the active
task when no name given. Currently shows one unit's details. Needs `--all` flag to list all active
units with focused indicator.

### R7: `validate-step-artifacts.sh` Bug

The `ideate->research` boundary is missing from the case statement — falls through to `*)` wildcard
and errors. This is a pre-existing bug unrelated to parallel support but should be fixed. The
ideation gate is validated by `definition.yaml` schema validation, so the artifact check for this
boundary should verify definition.yaml exists and is valid.

### R8: Helpers Needed in `common.sh`

New functions to add:
- `extract_unit_from_path(path)` — parse `.work/{name}/...` → return `.work/{name}`
- `find_focused_work_unit()` — read `.work/.focused`, validate, fallback to find_active_work_unit()
- `set_focus(name)` — write unit name to `.work/.focused`
- `clear_focus()` — delete `.work/.focused`

Existing functions to keep:
- `find_active_work_unit()` — still used as fallback in `find_focused_work_unit()`
- `is_work_unit_file()` — still valid, unit-agnostic
- `read_state_field()`, `current_step()`, etc. — take work_dir, already unit-scoped

### R9: Backward Compatibility

When exactly one active unit exists:
- `find_focused_work_unit()` returns it (regardless of `.focused` file state)
- `find_active_work_unit()` returns it (unchanged)
- All hooks behave identically to today
- `.focused` file is optional — never required for single-unit operation

### R10: Settings Configuration

Hooks are registered in `.claude/settings.json` under `hooks` keyed by event type. No per-unit
registration possible — hooks fire for all tool calls. Unit scoping must happen inside the hook
scripts themselves, not at the registration layer.
