# Spec: user-action-lifecycle

## Interface Contract

**Files modified**: bin/rws, schemas/state.schema.json, skills/shared/,
.claude/rules/step-sequence.md, .claude/settings.json
**File removed**: bin/frw.d/hooks/gate-check.sh
**Consumers**: Agent during implement step, rws_transition() for enforcement

**Schema addition** (state.schema.json):
- `pending_user_actions`: array of objects, each with:
  - `id` (string, required) — kebab-case identifier
  - `instructions` (string, required) — what the user needs to do
  - `created_at` (string, date-time, required) — when declared
  - `completed_at` (string, date-time, nullable) — when user confirmed done
- Default value for new rows: `[]`

**Commands added to bin/rws**:
- `rws add-user-action [name] <id> <instructions>` — appends action to
  pending_user_actions array via `frw update-state`
  - Exit codes: 0 success, 1 usage, 2 row not found, 3 duplicate id
- `rws complete-user-action [name] <id>` — sets completed_at on matching
  action via `frw update-state`
  - Exit codes: 0 success, 1 usage, 2 row not found, 3 action not found
- `rws list-user-actions [name]` — prints pending/completed actions to stdout
  - Format: `[PENDING] id — instructions` or `[DONE] id — instructions`
  - Exit codes: 0 success, 2 row not found

**Transition enforcement** (inside rws_transition()):
- Before artifact validation, check pending_user_actions for any item
  where completed_at is null
- If uncompleted actions exist: print error listing them, return exit 1,
  gate record still persists (existing behavior)
- Evidence: when all actions are complete at transition time, include
  "user_actions: all N completed" in gate evidence

**Skill instructions** (skills/shared/user-actions.md or similar):
- When to declare: interactive logins, PR reviews, deploy approvals,
  manual verifications, any action requiring the user outside Claude Code
- Pattern: `rws add-user-action <name> <id> <instructions>` → tell user
  what to do → `rws list-user-actions <name>` to check → user runs
  `rws complete-user-action <name> <id>` when done

**Cleanup**:
- Remove bin/frw.d/hooks/gate-check.sh
- Remove gate-check hook registration from .claude/settings.json
- Update .claude/rules/step-sequence.md to remove gate-check references

## Acceptance Criteria (Refined)

1. `pending_user_actions` array exists in state.schema.json with id,
   instructions, created_at (required) and completed_at (nullable)
2. `rws add-user-action` appends to state and exits 3 on duplicate id
3. `rws complete-user-action` sets completed_at and exits 3 if id not found
4. `rws list-user-actions` shows status with [PENDING]/[DONE] prefix
5. `rws transition` blocks (exit 1) when uncompleted user actions exist,
   printing the list of pending actions to stderr
6. Gate evidence includes user action completion count when transitioning
7. gate-check.sh is removed and its hook registration deleted from settings.json
8. step-sequence.md no longer references gate-check hook
9. Agent instructions exist in skills/shared/ describing when and how to
   use add-user-action/complete-user-action

## Test Scenarios

### Scenario: Add and complete action round-trip
- **Verifies**: AC 1, 2, 3, 4
- **WHEN**: `rws add-user-action test-row approve-pr "Review and approve PR #123"`
  then `rws list-user-actions test-row` then
  `rws complete-user-action test-row approve-pr` then
  `rws list-user-actions test-row`
- **THEN**: First list shows `[PENDING] approve-pr`, second shows `[DONE] approve-pr`
- **Verification**: Run commands in sequence, check stdout

### Scenario: Transition blocked by pending action
- **Verifies**: AC 5
- **WHEN**: `rws add-user-action test-row manual-check "Verify deploy"`
  then `rws transition test-row pass manual "evidence"`
- **THEN**: Transition fails (exit 1), stderr lists pending action
- **Verification**: `rws transition test-row pass manual "test" 2>&1; echo $?` → 1

### Scenario: Transition succeeds after completion
- **Verifies**: AC 5, 6
- **WHEN**: Add action, complete it, then transition
- **THEN**: Transition succeeds, gate evidence mentions "user_actions: all 1 completed"
- **Verification**: Check state.json gate record evidence field

### Scenario: Duplicate id rejected
- **Verifies**: AC 2
- **WHEN**: Add action with id "x", then add another with id "x"
- **THEN**: Second call exits 3
- **Verification**: `rws add-user-action test-row x "dup"; echo $?` → 3

## Implementation Notes

- State mutation: `.pending_user_actions += [{id: $id, instructions: $instr, created_at: $now, completed_at: null}]`
- Completion: `.pending_user_actions |= map(if .id == $id then .completed_at = $now else . end)`
- Transition check: `.pending_user_actions | map(select(.completed_at == null)) | length > 0` → block
- gate-check.sh removal: delete file, remove from settings.json hooks array,
  update step-sequence.md to say enforcement is in rws_transition()
- The skill instructions file should be brief (10-15 lines) — pattern + examples only

## Dependencies

- schemas/state.schema.json (schema to extend)
- bin/rws rws_transition() function (enforcement integration point)
- bin/frw.d/lib/common.sh (update_state helper)
- worktree-summary deliverable (wave 2 must complete first — shared bin/rws edits)
