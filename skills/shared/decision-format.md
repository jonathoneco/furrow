---
layer: shared
---
# Decision Documentation Format

Record decisions at collaboration points using this format.
Emit `<!-- decision:{name} -->` before each decision block.

## Template

```
## Decision: {name}
**Category**: {step-specific category}
**Options**:
- A) {description} — {tradeoff}
- B) {description} — {tradeoff}
**Lean**: {option} — {reasoning}
**Uncertainty**: low | medium | high
**Outcome**: {chosen option} — {rationale}
```

## Mode Behavior

| Mode | Before Deciding | Recording |
|------|----------------|-----------|
| Supervised | Present options, wait for user response | Record user's choice + rationale |
| Delegated | Proceed with lean; flag high-uncertainty for user review | Record agent's choice, mark `(agent-decided)` |
| Autonomous | Proceed with lean | Record choice; evaluator reviews rationale post-hoc |

## Loop Exit Conditions

- **Exit**: All decision categories for the step have recorded outcomes.
- **Continue**: Any high-uncertainty decision lacks user input (supervised) or explicit rationale (delegated/autonomous).
- **Red flag**: Decision with only one option considered — always present >=2 alternatives.

## Integration

- Decisions with outcomes feed into `summary.md` Key Findings.
- Unresolved decisions feed into `summary.md` Open Questions.
- Per-step decision categories are defined in each step's Collaboration Protocol section.
