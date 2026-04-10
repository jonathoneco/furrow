# Research: Gate Integration for Dual-Review Evidence

## Gate Evaluation Flow

```
Step completion → Phase A (deterministic shell) → Phase B (isolated subagent) → Trust gradient → Gate record
```

### Phase A: `frw run-gate` → `check-artifacts.sh`
- Validates: deliverable files exist, ACs addressed, seed reachable
- Exit 0 = pass (no Phase B needed for precheck). Exit 10 = Phase B needed.

### Phase B: Isolated subagent via Agent tool
- Contract: `skills/shared/gate-evaluator.md`
- Receives: definition.yaml, gate YAML, Phase A results, step output paths
- Prohibited: summary.md, conversation history, state.json
- Evaluates dimensions from `evals/dimensions/{step}.yaml` or inline gate dimensions
- Returns: per-dimension PASS/FAIL with evidence

### Trust Gradient: `frw evaluate-gate`
- `supervised` → `decided_by: manual` (all gates)
- `delegated` → `decided_by: evaluated` (most), manual for implement→review
- `autonomous` → `decided_by: evaluated` (all)

## Current Dual-Review in Gates

### Ideate Gate (`evals/gates/ideate.yaml`)
Has a `cross-model` dimension:
```yaml
- name: "cross-model"
  definition: "Whether cross-model or fresh-context review evidence exists"
  pass_criteria: "Evidence exists. Findings incorporated or explicitly rejected with rationale."
  fail_criteria: "No evidence. Findings ignored without rationale."
```

### Review Gate (`evals/gates/review.yaml`)
No explicit `cross-model` dimension — dual-review is embedded in the Phase B protocol itself (the review IS the dual-review).

## Required Changes for Plan and Spec

### Add `dual-review` dimension to post-step gates

**evals/gates/plan.yaml** — add to `additional_dimensions`:
```yaml
- name: "dual-review"
  definition: "Whether fresh-context and cross-model review evidence exists for the plan"
  pass_criteria: "Both reviews exist. Findings incorporated or rejected with rationale."
  fail_criteria: "Missing review evidence or findings ignored."
  evidence_format: "Cite review sources, disposition of findings"
```

**evals/gates/spec.yaml** — same pattern.

### Gate Record Structure

```json
{
  "boundary": "research->plan",
  "outcome": "pass",
  "decided_by": "manual",
  "evidence": "gates/research-to-plan.json (fresh-context + cross-model synthesized)",
  "timestamp": "ISO 8601"
}
```

### Extended Gate File

`gates/{boundary}.json` includes per-dimension verdicts plus `dual-review` dimension recording:
- Both reviewer sources
- Agreement status
- Disagreements with resolution rationale
- Unique findings and their disposition (incorporated vs rejected)

### Evidence Data Flow

1. Step agent completes plan/spec artifacts
2. Dual-review runs (fresh subagent + cross-model) as part of Phase B
3. Findings synthesized into extended gate file
4. Gate record in state.json points to extended file
5. Summary.md updated with review evidence section

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `references/gate-protocol.md` | Primary | Full gate flow |
| `skills/shared/gate-evaluator.md` | Primary | Evaluator isolation |
| `evals/gates/plan.yaml` | Primary | Plan gate dimensions |
| `evals/gates/spec.yaml` | Primary | Spec gate dimensions |
| `evals/gates/ideate.yaml` | Primary | Cross-model dimension pattern |
| `evals/gates/review.yaml` | Primary | Review gate structure |
