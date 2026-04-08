# Spec: spec-test-scenarios

## Interface Contract

Three files modified:

**templates/spec.md** — Add "Test Scenarios" section between Acceptance Criteria and Implementation Notes.

**skills/spec.md** — Add instruction to produce test scenarios per deliverable during spec step.

**evals/dimensions/spec.yaml** — Add `test-scenario-coverage` evaluation dimension.

## Acceptance Criteria (Refined)

1. `templates/spec.md` has a "Test Scenarios" section after "Acceptance Criteria (Refined)" and before "Implementation Notes"
2. Template section includes format guidance: scenario name, AC reference, WHEN/THEN, verification command
3. `skills/spec.md` step-specific rules instruct agents to produce test scenarios per deliverable
4. Skill instruction clarifies: scenarios supplement ACs, 1 AC can have 0-N scenarios, trivially testable ACs may omit scenarios
5. `evals/dimensions/spec.yaml` includes `test-scenario-coverage` dimension with pass/fail criteria
6. Dimension evaluates: non-trivial ACs have scenarios, scenarios are concrete (have observable outcome)

## Test Scenarios

### Scenario: template section ordering
- **Verifies**: AC 1
- **WHEN**: Reading templates/spec.md top to bottom
- **THEN**: Sections appear in order: Interface Contract, Acceptance Criteria, Test Scenarios, Implementation Notes, Dependencies
- **Verification**: `grep "^## " templates/spec.md` shows correct section ordering

### Scenario: spec skill mentions test scenarios
- **Verifies**: AC 3, 4
- **WHEN**: Agent reads skills/spec.md for spec step instructions
- **THEN**: Instructions include test scenario production with supplementary framing
- **Verification**: `grep -c "Test Scenario" skills/spec.md` returns >= 1

### Scenario: eval dimension catches missing scenarios
- **Verifies**: AC 5, 6
- **WHEN**: Gate evaluator runs spec post_step gate with spec missing test scenarios
- **THEN**: `test-scenario-coverage` dimension fails
- **Verification**: Gate verdict JSON shows test-scenario-coverage: FAIL

## Implementation Notes

- Template format for scenarios:
  ```
  ### Scenario: [descriptive name]
  - **Verifies**: [AC reference]
  - **WHEN**: [preconditions + action]
  - **THEN**: [observable outcome]
  - **Verification**: [command or check]
  ```
- Skill instruction should be 3-4 lines max — don't bloat the skill
- Eval dimension follows existing dimension structure in spec.yaml
- No changes to decompose — test scenarios flow to implement/review, not decompose

## Dependencies

- None. All 3 files are independent edits.
