# Spec: precheck-supervised-update

## Overview
Remove supervised-mode early exit from gate-precheck.sh so pre-step evaluation runs for all policies.

## Files to Modify
- `commands/lib/gate-precheck.sh` — remove lines 35-39

## Implementation

### 1. Remove supervised early exit
Delete these lines from gate-precheck.sh:
```sh
# Supervised mode disables pre-step evaluation
gate_policy="$(yq -r '.gate_policy // "supervised"' "${def_path}" 2>/dev/null)" || gate_policy="supervised"
if [ "${gate_policy}" = "supervised" ]; then
  exit 1
fi
```

### 2. No other changes needed
- evaluate-gate.sh already returns WAIT_FOR_HUMAN for supervised mode on all boundaries
- Pre-step evaluator YAMLs (research, plan, spec, decompose) already define their dimensions
- The /work command flow already calls gate-precheck → run-gate → evaluate-gate in sequence

### 3. Resulting flow in supervised mode
1. gate-precheck.sh runs structural checks (same as delegated/autonomous)
2. If structural criteria NOT met → exit 1, step runs normally
3. If criteria met → exit 0, run-gate.sh runs subagent evaluator
4. Evaluator returns verdict
5. evaluate-gate.sh returns WAIT_FOR_HUMAN
6. Agent presents: "Evaluator recommends skipping {step}: {reason}. Skip? [yes/no]"
7. User approves → step-transition.sh --request with decided_by=manual, then --confirm
8. User rejects → step runs normally

## Acceptance Criteria Verification
- AC1: "gate-precheck.sh no longer exits early for supervised mode" — verify lines removed, supervised mode falls through to per-step checks
- AC2: "Pre-step evaluation runs and produces verdict" — run with supervised definition, verify evaluator is invoked
- AC3: "Agent presents skip recommendation with explicit yes/no prompt" — covered by skill-transition-protocol deliverable
- AC4: "User rejection causes step to run normally" — agent honors user "no" and begins step work
