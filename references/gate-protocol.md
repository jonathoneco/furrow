# Gate Protocol

## Overview

Every step transition requires a gate check. Gates enforce quality and ensure
no step advances prematurely. Gate evaluation has two phases and two moments.

## Two Evaluation Moments

| Moment | When | Question | Steps with this moment |
|--------|------|----------|----------------------|
| Pre-step | Before step begins | Should this step run, or is its output trivially determined? | research, plan, spec, decompose |
| Post-step | After step completes | Is the step's output good enough to advance? | All 7 steps |

Pre-step evaluation can determine a step adds no information beyond what previous
steps already produced. When this happens, the gate records `decided_by: prechecked`
and advances without executing the step.

## Gate Evaluation Flow

```
Step agent signals completion (or step is next in sequence)
  |
  +- Phase A (deterministic, shell)
  |   rws gate-check checks structural criteria:
  |   - Deliverable count, dependencies, specialist diversity
  |   - Acceptance criteria presence and count
  |   - Mode-specific exclusions (research mode blocks research pre-step)
  |   - gate_policy and force_stop_at overrides
  |
  |   scripts/check-artifacts.sh checks artifact presence:
  |   - Deliverable files exist per file_ownership
  |   - Owned files were modified (git diff or deliverables/ check)
  |   - Acceptance criteria from definition.yaml addressed
  |   - Seed consistency (A6): seed exists and is not closed
  |
  +- Phase B (judgment, isolated subagent)
  |   scripts/run-gate.sh prepares evaluator inputs:
  |   - definition.yaml content
  |   - evals/gates/{step}.yaml content
  |   - Phase A results
  |   - Step output paths
  |
  |   In-context agent spawns isolated subagent (Agent tool):
  |   - Subagent loads skills/shared/gate-evaluator.md
  |   - Evaluates each dimension from gate YAML
  |   - Returns per-dimension PASS/FAIL with evidence
  |
  +- Trust gradient (scripts/evaluate-gate.sh)
      Applies gate_policy to evaluator verdict:
      - supervised: WAIT_FOR_HUMAN
      - delegated: accept most, human for implement->review and review->archive
      - autonomous: accept all
```

## Gate Record Format

Each gate produces a record appended to `state.json.gates[]`:

```json
{
  "boundary": "{from_step}->{to_step}",
  "outcome": "pass | fail | conditional",
  "decided_by": "manual | evaluated | prechecked",
  "evidence": "one-line proof summary or path to gates/{boundary}.json",
  "conditions": ["only present when outcome is conditional"],
  "timestamp": "ISO 8601"
}
```

### decided_by Vocabulary

| Value | Meaning | When used |
|-------|---------|-----------|
| `manual` | Human reviewed and approved | supervised mode always; delegated mode for implement->review and review->archive |
| `evaluated` | Isolated subagent evaluated, trust gradient auto-approved | delegated mode (most gates); autonomous mode (all gates) |
| `prechecked` | Pre-step evaluation determined step not needed | Pre-step rws gate-check + evaluator agreed step is trivial |

## Trust Gradient

The trust gradient controls human oversight of evaluator verdicts -- it does NOT
control whether evaluation happens. Evaluation always runs.

| `gate_policy` | Who Decides | Pre-Step Evaluation |
|--------------|------------|---------------------|
| `supervised` | Human approves every gate (`decided_by: manual`) | Evaluator runs, verdict presented to human |
| `delegated` | Evaluator for most (`decided_by: evaluated`); human for implement->review and review->archive (`decided_by: manual`) | Allowed for all applicable steps |
| `autonomous` | Evaluator for all gates (`decided_by: evaluated`) | Allowed for all applicable steps |

Per-deliverable `gate` field overrides the top-level policy for that deliverable's
review only.

## Outcomes

| Outcome | Effect | When Used |
|---------|--------|-----------|
| `pass` | Advance to next step | Output meets all requirements |
| `fail` | Stay at current step | Output has deficiencies |
| `conditional` | Advance with conditions | Output is acceptable but has caveats |

When `outcome` is `conditional`, the `conditions` array becomes a checklist for the
next step. The next step must address all conditions before its own gate.

## Subagent Invocation Pattern

The shell layer prepares inputs but never invokes the LLM directly:

1. `scripts/run-gate.sh` runs Phase A (`scripts/check-artifacts.sh`)
2. `run-gate.sh` writes an evaluator prompt file (YAML) containing inputs for the subagent
3. `run-gate.sh` exits with code 10 ("needs subagent evaluation") and prints the prompt file path
4. The in-context agent reads the prompt file and spawns the subagent via Agent tool
5. Subagent follows `skills/shared/gate-evaluator.md` contract
6. Subagent returns structured JSON: per-dimension verdicts + overall verdict
7. In-context agent calls `scripts/evaluate-gate.sh` with the verdict to apply trust gradient

This pattern enforces generator-evaluator separation: the agent that produced the
step's output never evaluates its own work. The subagent runs with fresh context
and no access to the conversation that generated the artifacts.

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
1. Gate check evaluates step output (Phase A + Phase B).
2. Gate record appended to `state.json.gates[]`.
3. `summary.md` regenerated (latest version only; previous in git history).
4. `state.json.step` advanced; `step_status` set to `not_started`.
5. `state.json.updated_at` refreshed.

## Seed Consistency

Seeds and rows must stay synchronized throughout the lifecycle. The gate
protocol enforces this at two levels.

### Phase A: Deterministic Check (check-artifacts.sh, A6)

The `check-artifacts.sh` script performs a deterministic seed-consistency check
as part of Phase A (section A6). This check runs at every gate evaluation:

1. **Seed exists**: `state.json` must contain a non-null `seed_id`.
2. **Seed is not closed**: `sds show` confirms the seed status is not `closed`.
3. **Seed is reachable**: The `sds` command can find and return the seed record.

If any check fails, the entire Phase A verdict is `fail` and the gate blocks.
When `sds` is not available on the system, the check passes with a warning
(graceful degradation, not a hard block).

### Phase B: Seed-Sync Dimension

All 7 post-step gate evaluations include a `seed-sync` dimension in their
gate YAML rubrics. The isolated subagent evaluator checks:

- **Status alignment**: The seed status matches the expected status for the
  current row step (see mapping table below).
- **Metadata consistency**: The seed title and description are consistent with
  the row's `definition.yaml` objective.

| Row Step | Expected Seed Status |
|----------|---------------------|
| ideate | ideating |
| research | researching |
| plan | planning |
| spec | speccing |
| decompose | decomposing |
| implement | implementing |
| review | reviewing |

### Recovery Path

When seed-consistency fails, the gate blocks and requires human input to
resolve. Automatic correction is deliberately not supported -- a mismatch
between seed and row state is a procedural signal that something unexpected
happened.

Recovery steps:

1. **Diagnose**: Run `sds show <seed-id>` and `rws status <row-name>` to
   compare actual states.
2. **Determine cause**: Common causes are a manual `sds` update that skipped
   `rws`, or a crashed transition that updated the row but not the seed.
3. **Fix seed**: Use `sds update <seed-id> --status <correct-status>` to
   align the seed with the row's current step.
4. **Re-run gate**: After manual correction, re-trigger the transition with
   `rws transition <row-name>`.

Human input is required because auto-correction would mask procedural errors.
The mismatch itself is the signal that the process broke down; silently fixing
it removes that signal.
