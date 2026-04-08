# Decision Format Design Research

## Existing Patterns in Codebase

### ideate.md (established convention)
- Option A/B/C naming with "stated lean"
- `<!-- ideation:section:{name} -->` markers before each decision block
- Supervised mode: wait for user response
- No formal recording template

### Research templates
- `research-comparison.md`: candidates, dimensions, matrix, verdict
- `research-recommendation.md`: options, criteria table, risks
- Both use numbered citations [1][2]

### Shared skill pattern (summary-protocol.md as model)
- 32 lines, compact
- Table for required elements by step
- FORMAT + RULES hybrid
- No mode adaptation (first shared skill to include it)

## Design Constraints
- Must stay under 50 lines (step-layer context budget)
- Must be concrete/auditable, not generic advice
- Must integrate with existing summary-protocol (decisions feed into Key Findings)
- Must handle all three modes (supervised/delegated/autonomous)

## Decision Format Template (Draft)

```markdown
## Decision: {name}
**Category**: {step-specific category}
**Options**:
- A) {description} — {tradeoff}
- B) {description} — {tradeoff}
- C) {description} — {tradeoff}
**Lean**: {option} — {reasoning}
**Uncertainty**: low | medium | high
**Outcome**: {chosen option} — {rationale}
```

## Mode Behavior

| Mode | Before deciding | Recording |
|------|----------------|-----------|
| Supervised | Present options, wait for user response | Record user's choice + rationale |
| Delegated | Proceed with lean, flag high-uncertainty decisions | Record agent's choice, mark as agent-decided |
| Autonomous | Proceed with lean | Record choice, evaluator reviews rationale |

## Loop Exit Conditions (Draft)
- **Exit when**: All decision categories for the step are recorded with outcomes
- **Continue when**: Any high-uncertainty decision lacks user input (supervised) or explicit rationale (delegated)
- **Premature closure red flag**: Decisions recorded with no alternatives considered (Option A only)

## Per-Step Decision Categories

### Ideate
- Scope boundaries (what's in/out)
- Success criteria (what "done" looks like)
- Constraint priorities (which constraints are hard vs soft)

### Research
- Source trust (which sources to rely on when conflicting)
- Finding validation (whether findings match user's domain knowledge)
- Coverage sufficiency (when to stop researching)

### Plan
- Architecture trade-offs (simplicity vs extensibility, etc.)
- Dependency ordering (what blocks what)
- Risk tolerance (acceptable failure modes)

### Spec
- Acceptance criteria precision (how specific is "enough")
- Edge case coverage (which edge cases matter)
- Testability approach (how to verify each criterion)

## Sources Consulted
- Primary: skills/ideate.md (existing decision convention)
- Primary: templates/research-comparison.md, research-recommendation.md (structured comparison patterns)
- Primary: skills/shared/summary-protocol.md (compact shared skill model)
- Primary: skills/shared/gate-evaluator.md, eval-protocol.md, context-isolation.md (contract patterns)
