# Research: transition-simplification

## Problem

`rws transition` uses a two-phase ceremony (`--request` then `--confirm`) with
an intermediate `pending_approval` state. User approval happens BEFORE either
phase (the step skill asks "Ready to advance?" and waits for "yes"). The two
phases run back-to-back with no user interaction between them.

## Current Flow

```
1. Agent asks user: "Ready to advance to {next}?"
2. User says "yes"
3. Agent calls: rws transition --request <name> pass manual "<evidence>"
   -> Records gate in state.json.gates[]
   -> Validates step artifacts
   -> Sets step_status to "pending_approval"
4. Agent calls: rws transition --confirm <name>
   -> Validates decided_by matches gate_policy
   -> Validates verdict nonce (if evaluated)
   -> Advances step
   -> Syncs seed status
```

## What pending_approval Buys

1. **Crash recovery**: If session dies between request and confirm, state shows
   transition was attempted. In practice, the next session would re-run the
   transition anyway.
2. **Policy enforcement**: Confirm checks decided_by against gate_policy. This
   check could happen in a single command.
3. **Nonce validation**: Ensures verdict matches prompt. Also trivially done
   in a single command.

## Proposed Single Command

```
rws transition <name> --outcome pass --decided-by manual --evidence "..."
```

Atomically: record gate -> validate artifacts -> check policy -> validate nonce
-> advance step -> sync seed. No intermediate state.

## Files Referencing Two-Phase Transition

All 7 step skills have a "Supervised Transition Protocol" section that
references the two-phase pattern:
- skills/ideate.md (lines 55-59)
- skills/research.md (lines 51-53)
- skills/plan.md
- skills/spec.md
- skills/decompose.md
- skills/implement.md
- skills/review.md (lines 42-44, "archive" variant)

## Interaction with gate-check-hook-fix

The corrected gate-check hook now checks `has_passing_gate()` which looks for
a gate record in state.json. The `--request` phase writes the gate record.
If we collapse to a single command, the gate record is still written — just
not as a separate visible step. The hook must check BEFORE the transition
writes the gate (pre-transition guard) or the check is meaningless.

Two options:
1. Hook checks for an existing gate from a prior evaluator run (pre-transition)
2. Transition command does its own gate validation internally (no hook needed)

Option 2 is cleaner — the transition command already validates everything.
The hook becomes redundant once transition is atomic.

## Migration

1. Collapse `rws_transition()` --request and --confirm into single flow
2. Remove `pending_approval` state from step_status enum
3. Update all 7 step skills to use new syntax
4. Decide if gate-check hook is still needed post-simplification

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `bin/rws` lines 1361-1560 (source code) | Primary | Full transition implementation |
| `skills/ideate.md` lines 53-59 (source code) | Primary | Supervised transition protocol |
| `bin/frw.d/hooks/gate-check.sh` (source code) | Primary | Hook interaction with gate records |
| `bin/frw.d/lib/common.sh:87` (source code) | Primary | `has_passing_gate()` function |
