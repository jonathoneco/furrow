# Research: Dual-Review Protocol Implementation

## Current Pattern

The dual-review protocol runs two independent reviewers in parallel at Phase B of gate evaluation:

1. **Fresh Claude reviewer** via `claude -p --bare` — maximum isolation (strips MCP, hooks, CLAUDE.md, memory). Receives only: review prompt template, artifact paths, acceptance criteria, evaluation dimensions. Model: opus.

2. **Cross-model reviewer** via `frw cross-model-review {name} {deliverable|--ideation}` — invokes external provider (codex or claude --model). Reads artifacts independently, evaluates same dimensions.

### Ideate vs Review Implementation Differences

| Aspect | Ideate | Review |
|--------|--------|--------|
| Fresh reviewer | Agent tool subagent (isolated context) | `claude -p --bare` subprocess |
| Cross-model flag | `--ideation` | `{deliverable}` |
| Dimensions | Hardcoded (feasibility, alignment, etc.) | From `evals/dimensions/{step}.yaml` |
| Output location | `reviews/ideation-cross.json` | `reviews/{deliverable}-cross.json` |
| Synthesis | Framing quality assessment | Per-dimension agree/disagree |

### Isolation Boundary

**Reviewer receives**: artifacts, ACs, eval dimensions, specialist template (if specialist-informed)
**Reviewer does NOT receive**: summary.md, conversation history, state.json, prior step outputs, CLAUDE.md

### Adaptation for Plan and Spec

Both plan and spec should follow the review step pattern (not ideation):
- Use `claude -p --bare` for fresh reviewer (maximum isolation)
- Use `frw cross-model-review {name} --plan|--spec` for cross-model
- Load dimensions from `evals/dimensions/plan.yaml` and `evals/dimensions/spec.yaml`
- Run at end-of-step before gate evaluation (same trigger point)
- Write to `reviews/plan-cross.json` and `reviews/spec-cross.json`

### Specialist-Informed Review

Per user decision: the dual-reviewer receives the specialist template alongside artifacts. This shapes HOW the review is conducted (specialist reasoning patterns inform the evaluation) without violating generator-evaluator separation (the specialist is domain knowledge, not generator context).

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `skills/review.md` | Primary | Dual-reviewer protocol definition |
| `skills/ideate.md` | Primary | Ideate dual outside voice pattern |
| `skills/shared/gate-evaluator.md` | Primary | Evaluator isolation contract |
| `skills/shared/context-isolation.md` | Primary | Sub-agent context rules |
| `templates/review-prompt.md` | Primary | Review prompt construction |
| `commands/review.md` | Primary | `claude -p --bare` invocation flags |
