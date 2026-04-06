# Research: specialist-expansion

## New Specialist Designs

Five new specialists researched with reasoning patterns designed to shift
agent behavior away from defaults.

### Summary

| Specialist | Patterns | model_hint | Key Differentiator |
|---|---|---|---|
| frontend-designer | 8 | sonnet | Rendering strategy selection, hydration cost, state colocation |
| css-specialist | 7 | sonnet | Algorithm-first layout, specificity budgeting, compositing layers |
| accessibility-auditor | 8 | opus | ARIA-as-repair, focus management architecture, announcement strategy |
| prompt-engineer | 8 | opus | Structural constraint over behavioral, instruction placement, failure modes |
| technical-writer | 7 | sonnet | Diataxis mode discipline, progressive disclosure, maintenance-cost |

### Quality Assessment

All 5 designs follow the template standard format. Reasoning patterns are
genuinely opinionated and decision-framework-oriented, not generic advice.
Specific strengths:

- **frontend-designer**: "Rendering strategy selection" (3 questions that
  determine SSG/ISR/SSR/client) is a real decision framework
- **css-specialist**: "Algorithm-first layout selection" and "specificity
  budget management" encode expert heuristics the model doesn't default to
- **accessibility-auditor**: "Semantic HTML first, ARIA as repair" is the
  fundamental expert heuristic that changes behavior significantly
- **prompt-engineer**: "Structural constraint over behavioral instruction"
  and "failure mode prediction" are meta-reasoning patterns genuinely useful
  for AI tooling work
- **technical-writer**: "Diataxis mode discipline" and "maintenance-cost
  awareness" are concrete frameworks that prevent generic docs

### Concerns

1. **frontend-designer** references React-specific patterns (useEffect,
   React.memo) — should be framework-agnostic or explicitly scoped
2. **css-specialist** is comprehensive at 7 patterns but may need trimming
   to stay under 80-line limit
3. **accessibility-auditor** at opus is justified — nuanced judgment needed
4. **prompt-engineer** at opus is justified — meta-reasoning about model
   behavior benefits from deeper thinking

### Rationale Grounding

harness-engineer.md already lists rationale.yaml in its Context Requirements.
The expansion deliverable should make this reference explicit and add a
reasoning pattern about grounding decisions in recorded rationale.

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| references/specialist-template.md (source code) | Primary | Template format requirements |
| specialists/harness-engineer.md (source code) | Primary | Exemplar for reasoning pattern quality |
| specialists/complexity-skeptic.md (source code) | Primary | Exemplar for opinionated patterns |
| specialists/api-designer.md (source code) | Primary | Exemplar for domain framework encoding |
| WAI-ARIA Authoring Practices (training data) | Tertiary | Accessibility interaction patterns — well-established |
| Diataxis framework (training data) | Tertiary | Documentation mode taxonomy — well-established |
