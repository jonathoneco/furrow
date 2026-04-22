# Spec: script-execution-guard

## Interface Contract

**File**: `bin/frw.d/hooks/script-guard.sh`
**Function**: `hook_script_guard()`
**Hook type**: PreToolUse (matcher: Bash)
**Stdin**: JSON with `tool_name` and `tool_input.command`
**Exit codes**: 0 (allow), 2 (block)
**Stderr on block**: `[furrow:error] bin/frw.d/ scripts are internal — use frw, rws, alm, or sds`
**Callers**: Claude Code harness via `frw hook script-guard`
**Dependencies**: `jq`, `bin/frw.d/lib/common.sh` (for `log_error`)

### Detection logic

1. Read stdin JSON, extract `.tool_input.command`
2. If command does not contain `frw.d/` → allow (return 0)
3. If command starts with an execution verb followed by a path containing `frw.d/` → block (return 2)
4. Otherwise → allow (return 0)

**Execution verbs** (case patterns):
- `bash *frw.d/*`
- `sh *frw.d/*`
- `source *frw.d/*`
- `. *frw.d/*` (dot-source, must handle `. ` not just `.`)
- `*; bash *frw.d/*` and `*&& bash *frw.d/*` (chained commands)
- `*| bash *frw.d/*` (piped execution)

**Allowed patterns** (no execution verb before frw.d/ path):
- `cat *frw.d/*`, `grep *frw.d/*`, `head *frw.d/*`, `less *frw.d/*`
- `ls *frw.d/*`, `wc *frw.d/*`, `file *frw.d/*`
- Any command without `frw.d/` in it

## Acceptance Criteria (Refined)

1. Hook file exists at `bin/frw.d/hooks/script-guard.sh` with function `hook_script_guard`
2. Hook registered in `.claude/settings.json` under PreToolUse Bash matcher
3. Blocks `bash bin/frw.d/scripts/update-state.sh` with exit 2 and stderr message
4. Blocks `source bin/frw.d/lib/common.sh` with exit 2 and stderr message
5. Blocks `. bin/frw.d/hooks/state-guard.sh` with exit 2 and stderr message
6. Blocks `sh bin/frw.d/scripts/run-gate.sh` with exit 2 and stderr message
7. Blocks chained: `echo foo && bash bin/frw.d/scripts/update-state.sh` with exit 2
8. Allows `cat bin/frw.d/scripts/update-state.sh` with exit 0
9. Allows `grep pattern bin/frw.d/lib/common.sh` with exit 0
10. Allows `frw update-state row-name step in_progress` with exit 0
11. Allows `bin/rws status` with exit 0 (no frw.d/ in command)
12. Integration test at `tests/integration/test-script-guard.sh` passes
13. `docs/architecture/cli-architecture.md` policy hooks table includes `script-guard.sh`

## Test Scenarios

### Scenario: Block direct bash execution
- **Verifies**: AC 3
- **WHEN**: Hook receives stdin `{"tool_name":"Bash","tool_input":{"command":"bash bin/frw.d/scripts/update-state.sh row-name step in_progress"}}`
- **THEN**: Exit code 2, stderr contains "bin/frw.d/ scripts are internal"
- **Verification**: `echo '{"tool_name":"Bash","tool_input":{"command":"bash bin/frw.d/scripts/update-state.sh"}}' | frw hook script-guard; echo $?`

### Scenario: Block dot-source execution
- **Verifies**: AC 5
- **WHEN**: Hook receives command `. bin/frw.d/hooks/state-guard.sh`
- **THEN**: Exit code 2
- **Verification**: `echo '{"tool_name":"Bash","tool_input":{"command":". bin/frw.d/hooks/state-guard.sh"}}' | frw hook script-guard; echo $?`

### Scenario: Block chained execution
- **Verifies**: AC 7
- **WHEN**: Hook receives command `echo foo && bash bin/frw.d/scripts/update-state.sh`
- **THEN**: Exit code 2
- **Verification**: `echo '{"tool_name":"Bash","tool_input":{"command":"echo foo && bash bin/frw.d/scripts/update-state.sh"}}' | frw hook script-guard; echo $?`

### Scenario: Allow read operations
- **Verifies**: AC 8, 9
- **WHEN**: Hook receives command `cat bin/frw.d/scripts/update-state.sh`
- **THEN**: Exit code 0
- **Verification**: `echo '{"tool_name":"Bash","tool_input":{"command":"cat bin/frw.d/scripts/update-state.sh"}}' | frw hook script-guard; echo $?`

### Scenario: Allow CLI commands
- **Verifies**: AC 10, 11
- **WHEN**: Hook receives command `frw update-state row-name step in_progress`
- **THEN**: Exit code 0 (no `frw.d/` in command string)
- **Verification**: `echo '{"tool_name":"Bash","tool_input":{"command":"frw update-state row-name step in_progress"}}' | frw hook script-guard; echo $?`

## Implementation Notes

- Clone `state-guard.sh` structure: `input="$(cat)"`, jq extraction, case matching, `log_error`
- Extract `.tool_input.command` (not `.tool_input.file_path`)
- Use nested case: first check `*frw.d/*` presence, then check execution verb patterns
- For chained commands (`&&`, `||`, `;`, `|`), the execution verb may appear mid-command — match `*bash *frw.d/*` etc.
- The `. ` (dot-source) pattern needs care: match `. *frw.d/*` but not words ending in `.`

## Dependencies

- `bin/frw.d/lib/common.sh` — `log_error` function
- `jq` — JSON parsing
- `bin/frw` hook dispatcher — `frw hook script-guard` routing
