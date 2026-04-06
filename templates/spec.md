# Spec: {deliverable-name}

## Interface Contract

{Function signatures, file locations, behavior expectations.
For scripts: interface (arguments, exit codes, stdin/stdout), callers, contract guarantees.
For schemas: required fields, validation rules, consumers.}

## Acceptance Criteria (Refined)

{Refined from definition.yaml. Each criterion must be testable:
- Contains an action verb (returns, writes, blocks, validates)
- Has a measurable condition (file exists, exit code 0, field equals value)
- References specific artifacts (file paths, field names, tool names)}

## Test Scenarios

{Named test scenarios per deliverable. Each scenario supplements an AC with
concrete verification. Trivially testable ACs (e.g., "exit code 0") may omit scenarios.}

### Scenario: [descriptive name]
- **Verifies**: [AC reference]
- **WHEN**: [preconditions + action]
- **THEN**: [observable outcome]
- **Verification**: [command or check procedure]

## Implementation Notes

{Architecture decisions, constraints, patterns to follow.
Reference existing code patterns to reuse.
Note any settled decisions from the plan step.}

## Dependencies

{Scripts, libraries, schemas this component depends on.
Other deliverables that must be complete first.}
