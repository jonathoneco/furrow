# Spec: two-phase-gate

## Overview
Split step-transition.sh into --request and --confirm phases with policy validation.

## Files to Modify
- `commands/lib/step-transition.sh` — add --request/--confirm flag parsing and split logic
- `schemas/state.schema.json` — add "pending_approval" to step_status enum
- `scripts/update-state.sh` — add "pending_approval" to jq enum check (line 91)
- `hooks/lib/validate.sh` — add "pending_approval" to case statement (line 106)

## Implementation

### 1. Schema: Add pending_approval
In `schemas/state.schema.json`, add `"pending_approval"` to `step_status.enum` array.
In `scripts/update-state.sh` line 91, add to the jq enum validation.
In `hooks/lib/validate.sh` line 106, add to the case statement.

### 2. step-transition.sh: Flag parsing
New signature options:
```
step-transition.sh --request <name> <outcome> <decided_by> <evidence> [conditions_json]
step-transition.sh --confirm <name>
step-transition.sh <name> <outcome> <decided_by> <evidence> [conditions_json]  # legacy (auto mode)
```

Parse first arg: if `--request` or `--confirm`, shift and enter new path. Otherwise, legacy behavior (existing single-phase flow for backward compatibility with auto/delegated modes).

### 3. --request phase
Execute existing steps 1-5 (record gate, validate artifacts, handle fail, wave conflict check, validate summary). Then:
- Read gate_policy from definition.yaml
- If supervised: set step_status to "pending_approval" via update-state.sh, exit 0 with message
- If delegated/autonomous: fall through to complete the transition inline (same as legacy)

### 4. --confirm phase
- Verify step_status = "pending_approval" (exit 5 if not)
- Read gate_policy from definition.yaml
- Validate decided_by against policy:
  - supervised: only "manual" accepted
  - delegated: "manual" or "evaluated" accepted
  - autonomous: all accepted
- Exit 6 on policy mismatch with clear error message
- Verify passing gate record exists for current boundary
- Regenerate summary.md
- Advance step via advance-step.sh
- Exit 0

### 5. Exit codes
Add:
- 5 — step_status is not "pending_approval" (--confirm called without --request)
- 6 — decided_by violates gate_policy

## Acceptance Criteria Verification
- AC1: "step-transition.sh --request writes pending gate to state.json" — verify step_status becomes "pending_approval" and gate record is appended
- AC2: "step-transition.sh --confirm validates decided_by against gate_policy" — verify policy check runs before advancement
- AC3: "In supervised mode, --confirm rejects decided_by != manual" — verify exit 6 for evaluated/prechecked
- AC4: "Cannot call --confirm without a preceding --request for same boundary" — verify exit 5 when step_status != pending_approval
