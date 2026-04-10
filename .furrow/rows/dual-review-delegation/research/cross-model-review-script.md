# Research: cross-model-review.sh Architecture

## Current Architecture

**Entry**: `bin/frw cross-model-review` dispatches to `bin/frw.d/scripts/cross-model-review.sh`

### Modes

| Mode | Flag | Function | Output |
|------|------|----------|--------|
| Deliverable | `{name} {deliverable}` | `frw_cross_model_review()` | `reviews/{deliverable}-cross.json` |
| Ideation | `{name} --ideation` | `_cross_model_ideation()` | `reviews/ideation-cross.json` |

### Provider Dispatch

```
codex|codex/*  → codex exec -c 'approval_policy="never"' -m {model} "{prompt}"
*              → claude --model {provider} --print "{prompt}"
```

Provider read from `furrow.yaml` `cross_model.provider`. Missing = skip (exit 1).

### Prompt Construction Pattern

1. Read state.json for mode, step, base_commit
2. Read definition.yaml for objective, deliverables, ACs, constraints
3. Load dimensions via `frw select-dimensions {name}` (standard mode) or hardcoded (ideation)
4. Gather changes: `git diff --stat` (code) or `ls deliverables/` (research)
5. Assemble markdown prompt with sections: AC, dimensions, changes, instructions
6. Invoke provider, parse JSON from response, validate with jq, write result

### What Needs to Change for --plan and --spec

**Argument parsing** (lines 16-22): Add `--plan` and `--spec` flags alongside `--ideation`.

**New functions**: `_cross_model_plan()` and `_cross_model_spec()` following `_cross_model_ideation()` pattern.

**Plan mode specifics**:
- Read plan.json for wave structure, specialist assignments, file ownership
- Read summary.md for architecture decisions (research findings reference)
- Load `evals/dimensions/plan.yaml` via `frw select-dimensions`
- Prompt: evaluate feasibility, coverage, research-grounding, specificity
- Output: `reviews/plan-cross.json`

**Spec mode specifics**:
- Read spec.md or specs/ directory for implementation contracts
- Read definition.yaml for AC refinement comparison
- Load `evals/dimensions/spec.yaml` via `frw select-dimensions`
- Prompt: evaluate testability, completeness, consistency, implementability
- Output: `reviews/spec-cross.json`

**Help text**: Update `bin/frw` dispatcher help to include new modes.

### Return Codes

- `0`: review complete, result written
- `1`: provider not configured (graceful skip)
- `2`: invocation failed or response parsing error

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `bin/frw.d/scripts/cross-model-review.sh` | Primary | Full script analysis |
| `bin/frw` | Primary | Dispatcher routing |
| `bin/frw.d/scripts/select-dimensions.sh` | Primary | Dimension file resolution |
| `evals/dimensions/plan.yaml` | Primary | Plan dimensions available |
| `evals/dimensions/spec.yaml` | Primary | Spec dimensions available |
