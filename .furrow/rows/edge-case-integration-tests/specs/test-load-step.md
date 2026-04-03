# Spec: test-load-step

## File
`tests/integration/test-load-step.sh`

## Fixture Requirements
- `.work/{name}/state.json` with step and gates array
- `skills/{step}.md` file must exist (or be created in fixture)
- `.work/{name}/summary.md` (referenced in output)

## Test Cases

### test_conditional_with_conditions
- state: step="review", gates array ending with:
  `{outcome: "conditional", conditions: ["Fix error handling in api.sh", "Add missing test for edge case"]}`
- Expected: exit 0, stdout contains "CONDITIONAL PASS"
- Assert stdout contains "- Fix error handling in api.sh"
- Assert stdout contains "- Add missing test for edge case"

### test_conditional_null_conditions
- state: step="review", gates array ending with:
  `{outcome: "conditional", conditions: null}`
- Expected: exit 0, stdout does NOT contain "CONDITIONAL PASS"

### test_pass_no_conditions
- state: step="review", gates array ending with:
  `{outcome: "pass"}`
- Expected: exit 0, stdout does NOT contain "CONDITIONAL PASS"

### test_missing_skill_file
- state: step="nonexistent"
- No `skills/nonexistent.md` file
- Expected: exit 3
