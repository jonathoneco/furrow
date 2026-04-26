---
layer: shared
---
# Evaluator Protocol — Guidelines, Dimension Loading, Two-Phase Review

## Evaluator Guidelines

1. **Run fresh**: Never evaluate from memory. Run commands, read files, inspect output NOW.
2. **Evidence first**: Gather evidence BEFORE making a judgment. Do not decide, then confirm.
3. **Binary only**: Each dimension is PASS or FAIL. If uncertain, it is FAIL. Explain why.
4. **Quote, don't paraphrase**: Evidence must be a direct quote, file path, or command output.
5. **One dimension at a time**: Evaluate independently. A FAIL on one must not bias another.
6. **State the gap for FAIL**: Say specifically what is missing or wrong, not just "insufficient."
7. **No leniency for effort**: A hard-to-build deliverable still fails if it does not meet criteria.

## Dimension Loading

Phase B review agents load rubrics from `evals/dimensions/{artifact-type}.yaml`:

| Step | Artifact Type | Dimension File |
|------|---------------|----------------|
| research | research | `evals/dimensions/research.yaml` |
| plan | plan | `evals/dimensions/plan.yaml` |
| spec | spec | `evals/dimensions/spec.yaml` |
| decompose | decompose | `evals/dimensions/decompose.yaml` |
| implement | implement | `evals/dimensions/implement.yaml` |

Each dimension has 5 fields: `name`, `definition`, `pass_criteria`, `fail_criteria`, `evidence_format`.

## Gate Evaluation

Gate evaluations use `evals/gates/{step}.yaml` files, parallel to `evals/dimensions/`:

| Directory | Purpose | When loaded |
|-----------|---------|-------------|
| `evals/dimensions/` | Quality dimensions for artifact review (Phase B) | Post-step review |
| `evals/gates/` | Gate-specific criteria for step transitions | Pre-step and post-step |

### Gate YAML Structure

```yaml
# evals/gates/{step}.yaml
pre_step:  # Only for research, plan, spec, decompose
  dimensions:
    - name: "kebab-case-identifier"
      definition: "What this dimension evaluates"
      pass_criteria: "Concrete condition for PASS"
      fail_criteria: "Concrete condition for FAIL"
      evidence_format: "How to present evidence"

post_step:
  dimensions_from: "evals/dimensions/{step}.yaml"  # Reference, not duplicate
  additional_dimensions:  # Optional gate-specific criteria
    - name: "..."
      ...
```

### Key conventions

- `dimensions_from` references `evals/dimensions/` files — gate YAMLs do not duplicate dimension content
- `pre_step` dimensions are always inline (gate-specific, no shared reference)
- `additional_dimensions` under `post_step` adds gate-specific criteria beyond the standard dimensions
- Ideate, implement, and review have `post_step` only (no `pre_step`)
- Gate evaluators follow `skills/shared/gate-evaluator.md` for invocation and isolation contract

## Two-Phase Protocol

- **Phase A** (artifact validation): Mechanical check — artifacts present, acceptance criteria
  met, plan completion verified. If Phase A fails, Phase B does not run.
- **Phase B** (quality review): Apply dimension rubric for the artifact type. Each dimension
  produces a binary PASS/FAIL verdict with evidence. Overall Phase B is PASS only when ALL pass.
- **Overall**: PASS requires both Phase A and Phase B. A single FAIL dimension means overall FAIL.
