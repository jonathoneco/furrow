# Spec: skill-transition-protocol

## Overview
Add prescriptive transition blocks to all 7 step skills.

## Files to Modify
- `skills/ideate.md`
- `skills/research.md`
- `skills/plan.md`
- `skills/spec.md`
- `skills/decompose.md`
- `skills/implement.md`
- `skills/review.md`

## Implementation

### 1. Transition block template
Add the following section to each step skill, replacing the existing Step Mechanics section's transition guidance:

```markdown
## Supervised Transition Protocol
Before requesting a step transition:
1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
2. Present work to user per `skills/shared/summary-protocol.md`.
3. Ask explicitly: "**Ready to advance to {next_step}?** Yes / No"
4. Wait for user response. Do NOT proceed without explicit approval.
5. On "yes": call `step-transition.sh --request` with `decided_by=manual`.
6. After --request succeeds: call `step-transition.sh --confirm`.
7. On "no": ask what needs to change, address feedback, return to step 2.
```

### 2. Per-skill adjustments
- **ideate.md**: Already has section-by-section approval in mode adaptations. Add the transition block after the hard gate section. Next step: research.
- **research.md**: Next step: plan.
- **plan.md**: Next step: spec.
- **spec.md**: Next step: decompose.
- **decompose.md**: Next step: implement.
- **implement.md**: Next step: review.
- **review.md**: Terminal step — transition block says "present review findings, ask if ready to archive" instead of advancing.

### 3. Reference to summary-protocol.md
The transition block references `skills/shared/summary-protocol.md` for presentation format. This keeps the protocol DRY — presentation details live in one place.

## Acceptance Criteria Verification
- AC1: "All 7 step skills have prescriptive transition blocks" — verify each file contains ## Supervised Transition Protocol section
- AC2: "Blocks reference summary-protocol.md for presentation" — verify reference in each block
- AC3: "Blocks include explicit approval prompt language" — verify "Ready to advance" prompt in each block
