# Spec: phase-three-quality

Quality infrastructure: automated evaluation and cross-model review.

## Components

### 1. `scripts/run-eval.sh`

**Interface**: `run-eval.sh <name> <deliverable>`
- Exit 0 = pass (review result written)
- Exit 1 = fail (review result written with failures)
- Exit 2 = missing files

**Logic**:
1. **Phase A — Deterministic checks**:
   - Artifact existence per deliverable type (code changes or research deliverables)
   - Schema validation: if plan.json involved, validate against schema
   - Naming conventions: call `scripts/validate-naming.sh` if available
   - Acceptance criteria spot-check: parse ACs from definition.yaml, check file-existence ACs where possible
2. **Phase B — Dimension evaluation**:
   - Call `scripts/select-dimensions.sh` (Phase I) to get correct dimension file
   - Read dimensions from YAML
   - For each dimension: run deterministic checks where feasible:
     - `test-coverage`: check that test files exist for new code paths
     - `unplanned-changes`: cross-reference plan.json file_ownership with `git diff --name-only`
     - `spec-compliance`: verify files in file_ownership were actually modified
   - Dimensions that need LLM judgment: record as `"verdict": "skipped"` with note "requires evaluator"
3. **Compose review result** per `schemas/review-result.schema.json`:
   - Build JSON with phase_a (artifacts_present, acceptance_criteria, verdict), phase_b (dimensions, verdict), overall, corrections count, reviewer="run-eval", cross_model=false, timestamp
   - Atomic write to `.work/{name}/reviews/{deliverable}.json`
4. **Gate decision**: Call `scripts/evaluate-gate.sh` (Phase I) with the overall verdict. If result is WAIT_FOR_HUMAN, output a message indicating human review is needed. If PASS/FAIL/CONDITIONAL, the eval runner can be used by step-transition to auto-decide.

### 2. `scripts/cross-model-review.sh`

**Interface**: `cross-model-review.sh <name> <deliverable>`
- Exit 0 = cross-model review complete, result written
- Exit 1 = cross_model.provider not configured (skip)
- Exit 2 = invocation failed

**Logic**:
1. Read `cross_model.provider` from `.claude/harness.yaml`. If empty, exit 1.
2. Parse provider format (e.g., `"openai/gpt-4o"` or model identifier).
3. Call `scripts/select-dimensions.sh` to get dimension file.
4. Build review prompt: include deliverable acceptance criteria, dimension definitions, file diff, and instructions to evaluate per dimensions.
5. **Invoke the model**: Use `claude` CLI with `--model` flag if available. The exact invocation mechanism depends on what's accessible:
   - CC runtime: `claude --model <model> --print "<review prompt>"` (or Agent tool with model parameter)
   - Fallback: write prompt to `.work/{name}/prompts/review-{deliverable}-cross.md` and exit with instruction to invoke manually
6. Parse response, extract dimension verdicts.
7. Write cross-model review result to `.work/{name}/reviews/{deliverable}-cross.json` following review-result.schema.json with `cross_model: true`.

**Integration**: The review skill references this: "If `cross_model.provider` is configured, run `scripts/cross-model-review.sh` after the primary review."

## Acceptance Criteria (Refined)

1. `run-eval.sh` writes a valid `reviews/{deliverable}.json` conforming to review-result.schema.json
2. `run-eval.sh` Phase A detects missing artifacts and records them
3. `run-eval.sh` Phase B loads correct dimensions via select-dimensions.sh
4. `run-eval.sh` skippable dimensions are recorded as "skipped" (not silently passed)
5. `run-eval.sh` calls evaluate-gate.sh and reports its decision
6. `cross-model-review.sh` reads provider from harness.yaml
7. `cross-model-review.sh` exits 1 cleanly when provider is not configured
8. `cross-model-review.sh` invokes the configured model and captures the review
9. `cross-model-review.sh` writes review result with `cross_model: true`
10. Both scripts use select-dimensions.sh for mode-aware dimension loading
