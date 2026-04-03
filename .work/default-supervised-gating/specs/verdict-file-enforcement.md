# Spec: verdict-file-enforcement

## Overview
Require subagent evaluator to write a verdict file with nonce. Validate in step-transition.sh --confirm.

## Files to Modify
- `scripts/run-gate.sh` — generate nonce, include in prompt file
- `commands/lib/step-transition.sh` — validate verdict file in --confirm phase

## Files to Create
- `hooks/verdict-guard.sh` — block direct Write/Edit to gate-verdicts/

## Implementation

### 1. Nonce generation in run-gate.sh
Before writing the prompt file (around line 130):
```sh
nonce="$(openssl rand -hex 16 2>/dev/null)" || nonce="$(date +%s%N | sha256sum | head -c 32)"
```
Add to the prompt YAML:
```yaml
nonce: {nonce}
```

### 2. Verdict directory and file
After subagent evaluation, the evaluator writes verdict to:
`.work/{name}/gate-verdicts/{from_step}-{to_step}.json`

Create directory in run-gate.sh: `mkdir -p "${work_dir}/gate-verdicts"`

Verdict JSON format:
```json
{
  "nonce": "<must match prompt nonce>",
  "verdict": "PASS|FAIL|CONDITIONAL",
  "dimensions": [...],
  "timestamp": "<ISO 8601>"
}
```

### 3. Verdict validation in step-transition.sh --confirm
Before advancing, check:
- Verdict file exists at expected path
- Parse nonce from verdict file
- Parse nonce from most recent prompt file for this boundary
- Compare: if mismatch, exit with error
- Skip validation for decided_by=manual in supervised mode (user override)

### 4. Write guard hook (verdict-guard.sh)
Follow state-guard.sh pattern:
```sh
case "$target_path" in
  */gate-verdicts/*|gate-verdicts/*)
    log_error "gate-verdicts/ is write-protected — verdicts written by evaluator subagent only"
    exit 2
    ;;
esac
```
Add to `.claude/settings.json` PreToolUse Write|Edit hooks array.

Note: The evaluator subagent writes the file via Bash (shell command), not via the Write tool. The hook only blocks Write/Edit tool calls, so the subagent can write via a shell redirect within its evaluation script.

## Acceptance Criteria Verification
- AC1: "run-gate.sh writes nonce to prompt file" — grep for nonce field in generated prompt YAML
- AC2: "Evaluator verdict file includes nonce from prompt" — check verdict JSON has nonce field
- AC3: "step-transition.sh --confirm validates verdict file exists and nonce matches" — verify exit on missing/mismatched nonce
- AC4: "Hook blocks Write/Edit to gate-verdicts/ paths" — verify exit 2 from hook on Write to gate-verdicts/
