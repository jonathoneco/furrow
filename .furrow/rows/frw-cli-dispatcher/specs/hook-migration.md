# Spec: hook-migration

## Interface Contract

Each hook becomes a file `bin/frw.d/hooks/<name>.sh` containing a single function `hook_<name>()`.

The dispatcher (`bin/frw`) handles:
1. Sourcing `lib/common.sh` (shared utilities)
2. Sourcing `hooks/<name>.sh` (hook logic)
3. Calling `hook_<name> "$@"`

### Hook Module Template

```sh
# bin/frw.d/hooks/state-guard.sh
# Hook: PreToolUse (Write|Edit)
# Blocks direct writes to state.json

hook_state_guard() {
  input="$(cat)"
  # ... logic migrated from hooks/state-guard.sh ...
}
```

### Hooks to Migrate (10 total)

| Hook | Type | Stdin | Exit Codes | Current LOC |
|------|------|-------|------------|-------------|
| state-guard | PreToolUse (Write\|Edit) | JSON (file_path) | 0=allow, 2=block | 33 |
| ownership-warn | PreToolUse (Write\|Edit) | JSON (file_path) | 0=always | 77 |
| validate-definition | PreToolUse (Write\|Edit) | JSON (file_path) | 0=valid, 3=fail | 138 |
| correction-limit | PreToolUse (Write\|Edit) | JSON (file_path) | 0=allow, 2=block | 100 |
| verdict-guard | PreToolUse (Write\|Edit) | JSON (file_path) | 0=allow, 2=block | 34 |
| gate-check | PreToolUse (Bash) | JSON (command) | 0=allow, 2=block | 63 |
| work-check | Stop | None | 0=always | 86 |
| stop-ideation | Stop | None | 0=valid, 1=fail | 68 |
| validate-summary | Stop | None/arg | 0=valid, 1=fail | 90 |
| post-compact | PostCompact | None | 0=ok, 1=corrupt | 77 |

### settings.json Update

```json
{ "type": "command", "command": "frw hook state-guard" }
{ "type": "command", "command": "frw hook ownership-warn" }
{ "type": "command", "command": "frw hook validate-definition" }
{ "type": "command", "command": "frw hook correction-limit" }
{ "type": "command", "command": "frw hook verdict-guard" }
{ "type": "command", "command": "frw hook gate-check" }
{ "type": "command", "command": "frw hook work-check" }
{ "type": "command", "command": "frw hook stop-ideation" }
{ "type": "command", "command": "frw hook validate-summary" }
{ "type": "command", "command": "frw hook post-compact" }
```

## Acceptance Criteria (Refined)

1. Each of the 10 hooks exists as `bin/frw.d/hooks/<name>.sh` with a `hook_<name>()` function
2. `echo '{"tool_name":"Write","tool_input":{"file_path":".furrow/rows/x/state.json"}}' | frw hook state-guard` exits 2 (blocked)
3. `echo '{"tool_name":"Write","tool_input":{"file_path":"foo.txt"}}' | frw hook state-guard` exits 0 (allowed)
4. `.claude/settings.json` contains `frw hook <name>` for all 10 hooks, with correct matchers preserved
5. No hook sources `hooks/lib/common.sh` directly — they use `$FURROW_ROOT/bin/frw.d/lib/common.sh` (loaded by dispatcher)
6. Each hook's `# Hook:` comment header is preserved (used by doctor for registration checks)
7. Hooks that call `update-state.sh` (work-check) are updated to call `frw update-state` or source the module

## Implementation Notes

- Migration is mechanical: strip the HOOK_DIR/FURROW_ROOT preamble and common.sh sourcing from each hook, wrap remaining logic in `hook_<name>()` function
- The dispatcher pre-sources common.sh, so hooks can call `find_focused_row()` etc. directly
- Hooks that source `validate.sh` need it sourced too — add validate.sh sourcing to the hook dispatcher case for hooks that need it (post-compact, work-check)
- `gate-check` hook calls `bin/rws` — this stays as-is (rws is independent)
- `correction-limit` reads `furrow.yaml` via yq — ensure FURROW_ROOT-relative paths still resolve

## Dependencies

- D1: frw-dispatcher-and-modules (dispatcher + lib/common.sh + lib/validate.sh must exist)
