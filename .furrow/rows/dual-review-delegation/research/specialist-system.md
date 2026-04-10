# Research: Specialist System and Step Skill Structure

## Current _meta.yaml Schema

21 specialists, each entry:
```yaml
{key}:
  file: {name}.md
  description: "{one-line domain description}"
  note: (optional) "{boundary clarification}"
```

## Current Specialist Frontmatter

```yaml
---
name: {key}
description: "{one-line}"
type: specialist
model_hint: sonnet|opus
---
```

No `scenarios` field exists yet. The `scenarios` field will be a new addition.

## Scenarios Field Design

```yaml
scenarios:
  - When: "{concrete action or decision context}"
    Use: "{what reasoning pattern applies}"
```

3-5 entries per specialist. `When` describes the task trigger. `Use` references actual section content from "How This Specialist Reasons."

### Example for Abstract Specialists

**systems-architect** (the hardest case — abstract domain):
```yaml
scenarios:
  - When: "Drawing module boundaries and evaluating coupling/cohesion trade-offs"
    Use: "Boundary tension test and complexity budget patterns"
  - When: "Analyzing dependency direction and identifying architectural violations"
    Use: "Dependency direction rule and reversibility premium"
  - When: "Evaluating whether to add a new component or abstraction layer"
    Use: "Platform absorption tracking and boundary-deliverable alignment"
```

## Step Skill Section Structure

All step skills follow consistent section ordering:

1. What This Step Does / Produces
2. Model Default
3. Step-Specific Rules
4. Collaboration Protocol
5. **Step-Level Specialist Modifier** (existing)
6. **Specialist Delegation** (NEW — insert here)
7. Agent Dispatch Metadata
8. Shared References
9. Team Planning
10. Step Mechanics
11. Supervised Transition Protocol
12. Learnings

### Specialist Delegation Section Template

~15-20 lines per step. Instructs the agent to:
1. Read `specialists/_meta.yaml` for the scenarios index
2. Select relevant specialists based on task context
3. Record selections in summary.md with rationale
4. Delegate to selected specialists as sub-agents (not loaded into orchestration)

### Context Budget Impact

Current step skills: ~90 lines each. Adding ~20 lines = ~110 lines.
Within 350-line total budget (ambient ~150 + work ~150 + step ~50 = 350).
Step layer budget is 50 lines — adding 20 lines brings step contribution to the work-context layer instead.
Specialist templates (60-80 lines) load into sub-agents only, not counted against injected budget.

## Current Specialist Flow (Decompose → Implement)

1. Decompose: agent reads specs, assigns specialist per deliverable in plan.json
2. Implement: agent loads specialist template into sub-agent context
3. Review: specialist anti-patterns inform review evaluation

## Enhanced Flow (All Steps)

Same explicit selection, but now at plan/spec/research/ideate too:
- Step agent reads _meta.yaml, selects from scenarios
- Delegates to specialists as sub-agents for domain-specific work
- Records selections in summary.md

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `specialists/_meta.yaml` | Primary | Current schema |
| `specialists/go-specialist.md` | Primary | Frontmatter format |
| `specialists/systems-architect.md` | Primary | Abstract specialist structure |
| `specialists/test-engineer.md` | Primary | Concrete specialist structure |
| `references/specialist-template.md` | Primary | Normative requirements |
| `skills/plan.md` | Primary | Step skill section structure |
| `skills/spec.md` | Primary | Step skill section structure |
| `skills/decompose.md` | Primary | Current specialist assignment |
| `skills/research.md` | Primary | Step skill section structure |
