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

## Two-Phase Protocol

- **Phase A** (artifact validation): Mechanical check — artifacts present, acceptance criteria
  met, plan completion verified. If Phase A fails, Phase B does not run.
- **Phase B** (quality review): Apply dimension rubric for the artifact type. Each dimension
  produces a binary PASS/FAIL verdict with evidence. Overall Phase B is PASS only when ALL pass.
- **Overall**: PASS requires both Phase A and Phase B. A single FAIL dimension means overall FAIL.
