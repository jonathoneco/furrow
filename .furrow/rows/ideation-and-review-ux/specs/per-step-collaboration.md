# Spec: per-step-collaboration

## Interface Contract

**Modified files**:
- `skills/ideate.md`
- `skills/research.md`
- `skills/plan.md`
- `skills/spec.md`

**Type**: Inline section additions to existing skill files
**Budget**: <=30 additional lines per file (constraint from definition.yaml)

Each file receives a new `## Collaboration Protocol` section containing:
1. Decision categories specific to that step (3 per step)
2. High-value question examples (3 per step)
3. Reference to `skills/shared/decision-format.md`
4. "Don't assume — ask" instruction scoped to step domain

## Acceptance Criteria (Refined)

1. **Each step has at least 3 examples of high-value questions**
   - Ideate: scope boundaries, success criteria, constraint priorities
     - Example: "I see two framings — X (scope-limited) and Y (scope-expanded). Which aligns with your intent?"
     - Example: "Is {constraint} a hard requirement or negotiable?"
     - Example: "What does 'done' look like for you — X or Y?"
   - Research: source trust, finding validation, coverage sufficiency
     - Example: "Source A says X, Source B says Y. Which should we trust for this project?"
     - Example: "Does this finding match your domain experience, or should I dig deeper?"
     - Example: "I've covered {areas}. Is there a dimension I'm missing?"
   - Plan: architecture trade-offs, dependency ordering, risk tolerance
     - Example: "This trades simplicity for extensibility. Given the project size, which do you prefer?"
     - Example: "I see two dependency orders — {A then B} or {B then A}. Any reason to prefer one?"
     - Example: "This approach has {risk}. Is that acceptable or should we mitigate?"
   - Spec: acceptance criteria precision, edge case coverage, testability
     - Example: "Is '{criterion}' specific enough to test, or should I tighten it?"
     - Example: "Should we cover {edge case} or is it out of scope?"
     - Example: "How should we verify this — unit test, integration test, or manual check?"

2. **Decision categories are step-specific, not generic**
   - No category appears in more than one step
   - Each category maps to a distinct class of decisions that step faces

3. **References shared decision-format.md for recording mechanics**
   - Each Collaboration Protocol section includes: "Record decisions using the format in `skills/shared/decision-format.md`"
   - Does not duplicate the format template inline

4. **Stop hooks are compatible with mid-step iteration**
   - Collaboration Protocol section includes note: "Mid-step iteration is expected; step_status remains in_progress throughout"
   - No new stop hook validation required (existing hooks check section content, not interaction count)

5. **Supervised/delegated/autonomous behavior is clear per step**
   - Each section states: "See `skills/shared/decision-format.md` for mode-specific behavior"
   - Ideate.md: update existing mode adaptations section to reference new format (don't duplicate)

## Implementation Notes

- Insert new section after existing "Step-Specific Rules" and before "Shared References"
- Ideate.md already has interaction points (steps 3 and 5) — augment, don't replace
- Keep examples concrete (use {placeholder} for variable parts, not abstract advice)
- Each section should be ~20-25 lines to stay within 30-line budget

## Dependencies

- `decision-format` deliverable must be complete (provides the shared format reference)
