# Research: user-action-lifecycle

## Current State

**state.json schema** (schemas/state.schema.json, 186 lines):
- Core fields: name, title, step, step_status, steps_sequence, deliverables, gates
- Mutation via `frw update-state <name> <jq-expression>` — atomic (temp + move), validates, updates timestamp
- Return codes: 0 success, 1 usage, 2 not found, 3 validation, 4 jq error
- Array append pattern: `.gates += [$record]`
- Array filter pattern: `.array |= map(select(.id != $target))`

**Gate-check hook** (bin/frw.d/hooks/gate-check.sh):
- Currently returns 0 (no-op) — all validation moved into rws_transition() itself
- Extension point: can read pending_user_actions and return 2 (block) if unresolved actions exist

**Transition flow** (rws_transition):
1. Record gate (append-only, persists even if validation fails)
2. Validate step artifacts (boundary-specific checks)
3. Advance step if validation passes

**No notification infrastructure** — hooks are silent, stderr only. notify-send must be
added fresh. Available on EndeavourOS (swaync desktop notifications).

**No existing user action references** — only gate_policy (supervised/delegated/autonomous)
represents human involvement, but at step boundaries, not mid-step actions.

## Implementation Plan

**Schema addition** — new top-level array in state.schema.json:
```json
"pending_user_actions": {
  "type": "array",
  "items": {
    "type": "object",
    "required": ["id", "instructions", "created_at"],
    "properties": {
      "id": {"type": "string"},
      "instructions": {"type": "string"},
      "created_at": {"type": "string", "format": "date-time"},
      "completed_at": {"type": "string", "format": "date-time"}
    }
  }
}
```

**CLI commands:**
- `rws add-user-action [name] <id> <instructions>` — appends to array, calls notify-send
- `rws complete-user-action [name] <id>` — sets completed_at on matching action
- `rws list-user-actions [name]` — shows pending/completed actions

**Gate enforcement** — two options:
1. Extend gate-check.sh to read pending_user_actions and block if any lack completed_at
2. Add check inside rws_transition before artifact validation

Option 2 is cleaner — keeps enforcement in the same atomic operation as transition.

**notify-send integration:**
```sh
notify-send -u normal "Furrow: User Action Required" "$instructions" -i dialog-information
```

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| schemas/state.schema.json (lines 1-186) | Primary | Current schema |
| bin/frw.d/scripts/update-state.sh (lines 21-163) | Primary | Mutation pattern |
| bin/frw.d/hooks/gate-check.sh (lines 1-16) | Primary | Current hook (no-op) |
| bin/rws.bak (lines 1364-1430) | Primary | Transition logic |
| bin/rws.bak (lines 312-377) | Primary | record_gate() |
| bin/frw.d/lib/common.sh (lines 84-96) | Primary | has_passing_gate() |
