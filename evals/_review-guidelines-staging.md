# Evaluator Guidelines — Staging File
#
# This content replaces the placeholder:
#   <!-- Section: evaluator-guidelines (owner: W-06, review.md only) -->
# in skills/review.md.

## Evaluator Guidelines

1. **Run fresh**: Never evaluate from memory. Run commands, read files, inspect output NOW.
2. **Evidence first**: Gather evidence BEFORE making a judgment. Do not decide, then look for confirmation.
3. **Binary only**: Each dimension is PASS or FAIL. If you are uncertain, it is FAIL. Explain why in evidence.
4. **Quote, don't paraphrase**: Evidence must be a direct quote, file path, or command output — not a summary.
5. **One dimension at a time**: Evaluate each dimension independently. Do not let a FAIL on one dimension bias your judgment on another.
6. **State the gap for FAIL**: When a dimension fails, state specifically what is missing or wrong, not just "insufficient."
7. **No leniency for effort**: A deliverable that was hard to build still fails if it does not meet criteria.

### Dimension Loading

Phase B review agents load dimension rubrics from `evals/dimensions/{artifact-type}.yaml` where `artifact-type` matches the current step:

| Step | Artifact Type | Dimension File |
|------|---------------|----------------|
| research | research | `evals/dimensions/research.yaml` |
| plan | plan | `evals/dimensions/plan.yaml` |
| spec | spec | `evals/dimensions/spec.yaml` |
| decompose | decompose | `evals/dimensions/decompose.yaml` |
| implement | implement | `evals/dimensions/implement.yaml` |

Each dimension has 5 fields: `name`, `definition`, `pass_criteria`, `fail_criteria`, `evidence_format`.

### Two-Phase Protocol

- **Phase A** (artifact validation): Mechanical check — artifacts present, acceptance criteria met, plan completion verified. If Phase A fails, Phase B does not run.
- **Phase B** (quality review): Apply dimension rubric for the artifact type. Each dimension produces a binary PASS/FAIL verdict with evidence. Overall Phase B verdict is PASS only when ALL dimensions pass.
- **Overall**: PASS requires both Phase A and Phase B pass. A single FAIL dimension means overall FAIL.
