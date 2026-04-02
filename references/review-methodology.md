# Review Methodology

## Overview

Review uses a two-phase evaluation. Phase A validates structural completeness.
Phase B evaluates quality. Both must pass for an overall pass verdict.

## Phase A — Artifact Validation

Phase A checks that all expected outputs exist and acceptance criteria are met.

### Checklist

1. **Artifacts present**: Do all expected output files exist?
2. **Acceptance criteria**: For each criterion in `definition.yaml`:
   - Is the criterion met? (boolean)
   - What is the evidence? (one-line proof)
3. **Plan completion**: Cross-reference against `plan.json`:
   - Were all planned files touched?
   - Are there unplanned changes (files outside `file_ownership`)?

### Phase A Output

```json
{
  "artifacts_present": true,
  "acceptance_criteria": [
    { "criterion": "text from definition", "met": true, "evidence": "proof" }
  ],
  "plan_completion": {
    "planned_files_touched": true,
    "unplanned_changes": []
  },
  "verdict": "pass"
}
```

Phase A verdict is `fail` if any acceptance criterion is not met or required
artifacts are missing.

## Phase B — Quality Review

Phase B evaluates the substance of the output against quality dimensions.
Dimensions vary by artifact type (see `references/eval-dimensions.md`).

### Process

1. Read the eval dimensions for the artifact type.
2. For each dimension, assess pass/fail with one-line evidence.
3. Produce an overall Phase B verdict.

### Phase B Output

```json
{
  "dimensions": [
    { "name": "dimension-name", "verdict": "pass", "evidence": "proof" }
  ],
  "verdict": "pass"
}
```

Phase B verdict is `fail` if any critical dimension fails.

## Overall Verdict

```
overall = "pass" if phase_a.verdict == "pass" AND phase_b.verdict == "pass"
overall = "fail" otherwise
```

## Review Result File

One file per deliverable at `reviews/{deliverable}.json`:

```json
{
  "deliverable": "name",
  "phase_a": { ... },
  "phase_b": { ... },
  "overall": "pass | fail",
  "corrections": 0,
  "reviewer": "agent-id",
  "cross_model": false,
  "timestamp": "ISO 8601"
}
```

## Correction Cycles

When a deliverable fails review:
1. `corrections` counter increments in `state.json.deliverables[name]`.
2. Implementation agent receives specific feedback from the review result.
3. After correction, a new review runs with `corrections` incremented in the result.
4. The correction cycle repeats until pass or human intervention.

## Cross-Model Review

For high-risk deliverables (flagged during ideation or with `gate: human`):
- A second model provides an independent review.
- The review result includes `cross_model: true`.
- Both reviews must pass for an overall pass.
