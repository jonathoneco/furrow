# Research: script-execution-guard

## Implementation Pattern

The hook follows the exact pattern of `state-guard.sh` and `verdict-guard.sh`:

```
hook_script_guard() {
  input="$(cat)"
  command_str="$(echo "$input" | jq -r '.tool_input.command // ""')" || command_str=""
  # Check if command contains frw.d/ AND starts with an execution verb
  # Allow: cat, grep, head, etc. (read-only)
  # Block: bash, sh, source, . (execution)
  return 0 or 2
}
```

### Key implementation details

1. **JSON field**: `.tool_input.command` (not `.tool_input.file_path` — this is Bash, not Write/Edit)
2. **Pattern match**: `frw.d/` substring in command string
3. **Execution verb detection**: Match leading `bash `, `sh `, `source `, `. ` before the frw.d/ path
4. **Exit codes**: 0 (allow), 2 (block)
5. **Error format**: `log_error "message"` → `[furrow:error] message` on stderr

### Registration

Add to existing `Bash` matcher in `.claude/settings.json`:
```json
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "frw hook gate-check" },
    { "type": "command", "command": "frw hook script-guard" }
  ]
}
```

### Edge cases confirmed

- `frw hook <name>` commands do NOT contain `frw.d/` in the command string — no false positive
- `frw update-state ...` commands do NOT contain `frw.d/` — no false positive
- `bash bin/frw.d/scripts/update-state.sh` DOES contain `frw.d/` + execution verb — correctly blocked
- `cat bin/frw.d/scripts/update-state.sh` contains `frw.d/` but no execution verb — correctly allowed

### Test pattern

From `tests/integration/` conventions:
- Source `helpers.sh`, use `setup_test_env`
- Track TESTS_RUN/PASSED/FAILED counters
- Call `print_summary` at end
- Hook tests simulate stdin JSON and check exit codes

### Documentation update

Add row to `docs/architecture/cli-architecture.md` policy hooks table:
```
| `script-guard.sh` | No | Blocks direct execution of bin/frw.d/ scripts |
```

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `bin/frw.d/hooks/state-guard.sh` | Primary | Hook structure, JSON parsing, exit code convention |
| `bin/frw.d/hooks/verdict-guard.sh` | Primary | Same pattern confirmation |
| `bin/frw.d/hooks/gate-check.sh` | Primary | Bash PreToolUse JSON format (`.tool_input.command`) |
| `.claude/settings.json` | Primary | Hook registration format, matcher groups |
| `bin/frw.d/lib/common.sh` | Primary | `log_error`/`log_warning` function signatures |
| `docs/architecture/cli-architecture.md` | Primary | Policy hooks table format |
| `tests/integration/test-lifecycle.sh` | Primary | Test framework conventions |
