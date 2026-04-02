# Gate Prompt — Claude Code Adapter

## Purpose
Present gate decisions to the human for approval when required by the gate policy.

## Gate Policy Behavior

### Supervised (`gate_policy: supervised`)
Every gate requires human approval. Always wait for input.

1. Present the gate decision with review evidence.
2. Show named options: **Pass**, **Fail**, **Conditional** (with conditions).
3. State the evaluator's lean based on review evidence.
4. **Wait for the human to respond** — do not auto-advance.
5. Record the human's decision in `state.json` gates array.

### Delegated (`gate_policy: delegated`)
Evaluator decides for PASS outcomes. Human notified on FAIL or CONDITIONAL.

1. If evaluator verdict is PASS: record gate and advance automatically.
2. If evaluator verdict is FAIL or CONDITIONAL: present to human with evidence.
3. Wait for human response on non-PASS outcomes.

### Autonomous (`gate_policy: autonomous`)
Evaluator verdict is recorded directly. Human notified only on FAIL.

1. If evaluator verdict is PASS: record gate and advance silently.
2. If evaluator verdict is FAIL: notify the human with evidence and wait.
3. If evaluator verdict is CONDITIONAL: record and advance, note conditions.

## Gate Presentation Format

```
## Gate: {from_step} -> {to_step}

### Evidence
{summary of review evidence — dimension verdicts, acceptance criteria}

### Evaluator Lean: {PASS|FAIL|CONDITIONAL}
{one-line rationale}

### Options
1. **Pass** — advance to {to_step}
2. **Fail** — remain at {from_step}, address issues
3. **Conditional** — advance with conditions (specify below)

Your decision:
```

## Rules
- Present one gate decision at a time — never batch multiple gates.
- Per-deliverable gate overrides (`gate: human | automated`) take precedence.
- Gate records are append-only — never modify a previously recorded gate.
- Always include `timestamp` in ISO 8601 format.
