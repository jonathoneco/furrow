# Research Mode Reference

When `mode: research` is set in `definition.yaml`, the step sequence is identical
but outputs change. Research mode produces knowledge artifacts instead of code.

## Per-Step Output Differences

| Step | Code Mode Output | Research Mode Output |
|------|-----------------|---------------------|
| ideate | `definition.yaml` | `definition.yaml` (unchanged) |
| research | Prior art, architecture options | Source inventory, knowledge landscape, gap analysis |
| plan | Architecture decisions, `plan.json` | Knowledge artifact structure, `plan.json` |
| spec | Component specifications | Knowledge artifact outline with per-section acceptance criteria |
| decompose | Parallel code work items | Parallel authoring sections with `.work/{name}/deliverables/` ownership |
| implement | Code changes in git | Knowledge artifact in `.work/{name}/deliverables/` |
| review | Code quality eval (implement dimensions) | Deliverable quality eval (research-implement dimensions) |

## Dimension Selection Logic

```
if mode == "research" AND step == "implement":
  load evals/dimensions/research-implement.yaml
elif mode == "research" AND step == "spec":
  load evals/dimensions/research-spec.yaml
else:
  load evals/dimensions/{step}.yaml
```

## Citation Format

Inline citations use bracketed references:

```markdown
The system uses a sliding window algorithm [1] with per-key counters [2].

## References
1. codebase:internal/middleware/ratelimit/window.go:15-42
2. docs:internal/middleware/README.md
```

Source types: `codebase:`, `docs:`, `web:`, `cmd:`, `git:`, `tool:`.

## Deliverable Formats

| Format | When to Use | Required Sections |
|--------|-------------|-------------------|
| Report | Comprehensive investigation | Executive summary, methodology, findings, discussion, recommendations, references |
| Synthesis | Integrating multiple threads | Context, findings summary, cross-cutting themes, synthesis, implications, references |
| Recommendation | Evaluating and recommending | Context, options, evaluation criteria, per-option analysis, recommendation, risks, references |
| Comparison | Side-by-side alternatives | Context, candidates, dimensions, per-dimension analysis, comparison matrix, verdict, references |

Templates at `templates/research-{format}.md`.

## Storage

```
.work/{name}/
  deliverables/           # research implement output
    {section-name}.md     # one file per deliverable
  research/               # research step output (raw findings)
    sources.md            # source inventory (template: templates/research-sources.md)
    {topic}.md            # per-topic findings
```

## Key Rules

- Research step NEVER auto-advances (always requires gate evaluation).
- Implement outputs to `.work/{name}/deliverables/`, NOT to git working tree.
- Every factual claim must cite a source. Unsourced claims marked `[unverified]`.
- No auto-promotion of findings. All promotion is user-confirmed at archive time.
