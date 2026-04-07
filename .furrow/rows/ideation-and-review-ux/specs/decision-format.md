# Spec: decision-format

## Interface Contract

**File**: `skills/shared/decision-format.md`
**Consumers**: ideate.md, research.md, plan.md, spec.md (via reference)
**Type**: Shared skill fragment (FORMAT + RULES hybrid)
**Budget**: <=50 lines (step-layer context budget)

The file defines:
1. A decision template agents fill in at collaboration points
2. A mode behavior table (supervised/delegated/autonomous)
3. Loop exit conditions (when to stop iterating)

## Acceptance Criteria (Refined)

1. **Format is concrete and auditable**
   - Template contains exactly these fields: Decision name, Category, Options (>=2), Lean with reasoning, Uncertainty (low/medium/high), Outcome
   - Each field has a one-line description of what goes there
   - No generic advice ("communicate well", "be thorough")

2. **Mode adaptation is built into the format**
   - A 3-row table maps mode → behavior-before-deciding → recording-convention
   - Supervised: "present options, wait for user response"
   - Delegated: "proceed with lean, flag high-uncertainty decisions for user review"
   - Autonomous: "proceed with lean, evaluator reviews rationale post-hoc"

3. **Loop exit conditions prevent premature closure and infinite iteration**
   - Exit when: all decision categories for the step have recorded outcomes
   - Continue when: any high-uncertainty decision lacks user input (supervised) or explicit rationale (delegated/autonomous)
   - Red flag: decisions with only one option considered (no alternatives)

4. **Compatible with summary-protocol.md**
   - Decisions with outcomes feed into Key Findings section
   - Unresolved decisions feed into Open Questions section

## Implementation Notes

- Follow `summary-protocol.md` structure: heading, table, rules, guidance
- Use Option A/B/C naming (established in ideate.md step 3)
- `<!-- decision:{name} -->` marker before each decision block (mirrors ideate.md's `<!-- ideation:section:{name} -->` pattern)
- Do NOT define per-step categories here — those go inline in each step skill

## Dependencies

- None (Wave 1, no prior deliverables needed)
- Must be complete before per-step-collaboration begins
