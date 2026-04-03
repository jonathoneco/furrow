# Spec: bypass-prevention

## Overview
PreToolUse Bash hook that blocks direct agent calls to record-gate.sh and advance-step.sh.

## Files to Create
- `hooks/transition-guard.sh` — new PreToolUse Bash hook

## Files to Modify
- `.claude/settings.json` — add transition-guard.sh to Bash matcher hooks

## Implementation

### 1. Hook logic (transition-guard.sh)
```sh
#!/bin/sh
# transition-guard.sh — Block direct calls to record-gate.sh and advance-step.sh
# Hook: PreToolUse (matcher: Bash)
# Exit 2 to block; exit 0 to allow.
set -eu

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
FURROW_ROOT="$(cd "$HOOK_DIR/.." && pwd)"
. "$FURROW_ROOT/hooks/lib/common.sh"

input="$(cat)"
command_str="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)" || command_str=""

# Allow step-transition.sh (the orchestrator)
case "$command_str" in
  *step-transition*) exit 0 ;;
esac

# Block direct calls to internal scripts
case "$command_str" in
  *record-gate.sh*|*record-gate\ *)
    log_error "Direct record-gate.sh calls blocked — use step-transition.sh"
    exit 2
    ;;
  *advance-step.sh*|*advance-step\ *)
    log_error "Direct advance-step.sh calls blocked — use step-transition.sh"
    exit 2
    ;;
esac

exit 0
```

### 2. Settings update
Add to `.claude/settings.json` under PreToolUse Bash hooks:
```json
{ "type": "command", "command": "hooks/transition-guard.sh" }
```

### Why this works
PreToolUse Bash hooks only intercept top-level Bash tool calls from the agent. When step-transition.sh internally calls record-gate.sh and advance-step.sh as subprocesses, those subprocess invocations do NOT trigger PreToolUse hooks — only the top-level `bash step-transition.sh` call triggers the hook. The `*step-transition*` allowlist ensures the orchestrator isn't blocked.

## Acceptance Criteria Verification
- AC1: "Hook blocks Bash calls containing record-gate.sh" — test with direct Bash call, expect exit 2
- AC2: "Hook blocks Bash calls containing advance-step.sh" — test with direct Bash call, expect exit 2
- AC3: "step-transition.sh still calls them internally (not blocked)" — test full transition, expect success
