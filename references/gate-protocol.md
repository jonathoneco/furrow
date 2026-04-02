# Gate Protocol

## Overview

Every step transition requires a gate check. Gates are the quality enforcement
mechanism that prevents premature advancement through the step sequence.

## Gate Record Format

Each gate produces a record appended to `state.json.gates[]`:

```json
{
  "boundary": "{from_step}->{to_step}",
  "outcome": "pass | fail | conditional",
  "decided_by": "human | evaluator | auto-advance",
  "evidence": "one-line proof summary or path to gates/{boundary}.json",
  "conditions": ["only present when outcome is conditional"],
  "timestamp": "ISO 8601"
}
```

## Gate Decision Flow

1. Current step agent signals completion.
2. Gate evaluator (human, eval agent, or auto-advance) examines step output.
3. Evaluator produces a verdict: pass, fail, or conditional.
4. Gate record appended to `state.json.gates[]`.
5. On pass/conditional: advance `step` to next in sequence, set `step_status` to `not_started`.
6. On fail: current step remains active, agent addresses feedback.

## Outcomes

| Outcome | Effect | When Used |
|---------|--------|-----------|
| `pass` | Advance to next step | Output meets all requirements |
| `fail` | Stay at current step | Output has deficiencies |
| `conditional` | Advance with conditions | Output is acceptable but has caveats |

When `outcome` is `conditional`, the `conditions` array becomes a checklist for the
next step. The next step must address all conditions before its own gate.

## Trust Gradient Effect

| `gate_policy` | Who Decides | Auto-Advance Allowed |
|--------------|------------|---------------------|
| `supervised` | Human approves every gate | No |
| `delegated` | Evaluator for most; human for implement->review and review->archive | Yes, for trivial steps |
| `autonomous` | Evaluator for all gates | Yes, for all applicable steps |

Per-deliverable `gate` field overrides the top-level policy for that deliverable's
review only.

## Automated Gate Decisions

`scripts/evaluate-gate.sh` provides programmatic gate routing by trust level.
This script is called by the **eval runner** (`scripts/run-eval.sh`), NOT by
`step-transition.sh` directly. Step-transition accepts explicit verdicts from
human or evaluator — evaluate-gate.sh determines whether to auto-approve or
escalate based on the gate_policy and boundary.

## Auto-Advance

A step may auto-advance when its output adds no information beyond what the previous
step already provided. Auto-advance:
- MUST create a gate record with `decided_by: "auto-advance"`
- MUST include evidence explaining why the step was trivial
- MUST NOT apply to `implement` or `review` steps
- CAN be disabled via `gate_policy: supervised`

## Extended Gate File

When full review evidence is needed beyond the one-line summary, write a structured
file to `gates/{from}-to-{to}.json`:

```json
{
  "boundary": "{from}->{to}",
  "dimensions": [
    { "name": "dimension-name", "verdict": "pass|fail", "evidence": "one-line" }
  ],
  "overall": "pass | fail | conditional",
  "reviewer": "agent identifier",
  "cross_model": false,
  "notes": "optional reviewer narrative",
  "timestamp": "ISO 8601"
}
```

## Step Boundary Protocol

At every boundary:
1. Gate check evaluates step output.
2. Gate record appended to `state.json.gates[]`.
3. `summary.md` regenerated (latest version only; previous in git history).
4. `state.json.step` advanced; `step_status` set to `not_started`.
5. `state.json.updated_at` refreshed.
