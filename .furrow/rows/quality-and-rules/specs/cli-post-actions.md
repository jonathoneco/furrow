# Spec: cli-post-actions

## Interface Contract

Two changes to `bin/rws`:

**rws complete-deliverable** — add post-action call to `regenerate_summary()`
- After `update_state()` on line 1730
- Regeneration is best-effort (warning on failure, not fatal)

**rws update-summary** — add state.json timestamp update
- After `mv` on line 1061
- Use `update_state "$name" "."` (no-op jq to trigger timestamp)
- Or simpler: direct jq update of `updated_at` field

Both changes leverage existing `update_state()` which auto-appends `.updated_at = $now`.

## Acceptance Criteria (Refined)

1. `rws complete-deliverable` calls `regenerate_summary` after marking deliverable complete
2. `rws complete-deliverable` summary regeneration failure emits warning but does not block deliverable completion
3. `rws update-summary` updates state.json `updated_at` after writing summary section
4. `updated_at` is refreshed by: rws transition (both phases), rws complete-deliverable, rws update-summary, rws complete-step, rws archive, rws rewind
5. Calling `rws complete-deliverable` twice on the same deliverable produces same state (idempotent)

## Test Scenarios

### Scenario: complete-deliverable regenerates summary
- **Verifies**: AC 1
- **WHEN**: Row has deliverable "foo" in wave 1, `rws complete-deliverable quality-and-rules foo`
- **THEN**: summary.md is regenerated with updated deliverable count
- **Verification**: Check summary.md contains "1/N" deliverable count after command

### Scenario: update-summary touches timestamp
- **Verifies**: AC 3
- **WHEN**: `rws update-summary quality-and-rules key-findings` with content on stdin
- **THEN**: state.json `updated_at` is more recent than before the command
- **Verification**: Compare `jq .updated_at state.json` before and after

### Scenario: regeneration failure is non-fatal
- **Verifies**: AC 2
- **WHEN**: summary.md is somehow unwritable, `rws complete-deliverable` is called
- **THEN**: Deliverable is marked complete, warning emitted, command exits 0
- **Verification**: Check state.json shows deliverable completed despite regeneration failure

## Implementation Notes

- Insert `regenerate_summary "$_cd_name"` after line 1730 in `rws_complete_deliverable()`
- Wrap in `|| { echo "Warning: summary regeneration failed" >&2; }` for non-fatal behavior
- Insert `update_state "$_usm_name" "."` after line 1061 in the update-summary helper
- The `"."` jq expression is a no-op (identity) but `update_state()` appends `.updated_at = $now`
- All other subcommands already use `update_state()` — no changes needed for transition, archive, rewind, etc.

## Dependencies

- `regenerate_summary()` function (line 852 in bin/rws)
- `update_state()` function (line 212 in bin/rws)
