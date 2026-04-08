# Spec: enforcement-wiring

## Interface Contract

Files:
- `skills/implement.md` — add mandatory specialist loading requirement
- `skills/spec.md` — add step-level specialist modifier
- `skills/review.md` — add step-level specialist modifier

Consumers: agents executing spec, implement, and review steps

## Acceptance Criteria (Refined)

1. `skills/implement.md` contains a MUST-level requirement before agent dispatch:
   "Before dispatching any agent for a deliverable, you MUST read and load the
   specialist template from `specialists/{specialist}.md` as assigned in plan.json.
   If the file does not exist, STOP and surface the error. This is a blocking
   requirement."
2. `skills/implement.md` contains plan.json validation instruction: "Before
   starting implementation, validate that every deliverable's `specialist` field
   in plan.json references an existing file in `specialists/`. Surface any
   missing specialists as errors."
3. `skills/spec.md` contains a specialist modifier: instruction text telling
   the agent how specialist reasoning applies during the spec step (emphasize
   contract completeness, boundary definition, constraint enumeration)
4. `skills/implement.md` contains a specialist modifier: instruction text telling
   the agent how specialist reasoning applies during implementation (emphasize
   incremental correctness, testability, spec adherence)
5. `skills/review.md` contains a specialist modifier: instruction text telling
   the agent how specialist reasoning applies during review (emphasize
   acceptance criteria verification, anti-pattern detection per specialist table)

## Implementation Notes

- Specialist loading instructions go in the existing "Specialist Loading" or
  "Team Planning" sections of each skill
- Step modifiers should be 2-4 sentences each — concise framing, not essays
- The modifier tells the agent HOW the specialist's reasoning patterns apply
  to this step's concerns, not what the specialist IS
- `skills/review.md` is also modified by review-consent-isolation (wave 2) —
  enforcement-wiring is wave 3, so it sees those changes

## Dependencies

- review-consent-isolation must complete first (both touch skills/review.md)
- Specialist files must exist in `specialists/` for validation to work
