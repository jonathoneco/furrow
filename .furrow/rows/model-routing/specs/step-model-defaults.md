# Spec: step-model-defaults

## Interface Contract

Each step skill in `skills/*.md` (7 files) gains a `## Model Default` section with a `model_default` value.

**Format:**
```markdown
## Model Default
model_default: sonnet
```

Placement: after `## What This Step Produces` section, before `## Step-Specific Rules`.
Consumers: lead agent reads this when spawning sub-agents within a step.

## Acceptance Criteria (Refined)

- All 7 step skill files contain `## Model Default` section
- `model_default: opus` appears in exactly 2 files: research.md, review.md
- `model_default: sonnet` appears in exactly 5 files: ideate.md, plan.md, spec.md, decompose.md, implement.md
- Section is placed after `## What This Step Produces` and before `## Step-Specific Rules`
- No other content in the step skill files is modified
- Each step skill file remains within the 50-line context budget

## Implementation Notes

- Step skills use markdown (no YAML frontmatter), so a dedicated H2 section is the natural format
- Consistent placement across all 7 files for predictable parsing by lead agent
- The section is 2 lines (header + value), minimal budget impact

## Dependencies

- None — this deliverable is independent
