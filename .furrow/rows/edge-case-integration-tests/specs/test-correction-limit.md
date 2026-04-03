# Spec: test-correction-limit

## File
`tests/integration/test-correction-limit.sh`

## Fixture Requirements
- `.work/{name}/state.json` with step="implement", deliverables with corrections counts
- `.work/{name}/plan.json` with file_ownership globs per deliverable
- `.work/.focused` pointing to the test unit
- stdin: JSON with tool_name and tool_input.file_path

## Test Cases

### test_at_limit_blocked
- state: deliverable "api" with corrections=3, status="in_progress"
- plan: "api" owns `src/api/*.js`
- stdin: `{"tool_name":"Write","tool_input":{"file_path":"src/api/handler.js"}}`
- Expected: exit 2, stderr contains "Correction limit"

### test_under_limit_allowed
- state: deliverable "api" with corrections=1, status="in_progress"
- plan: "api" owns `src/api/*.js`
- stdin: same as above
- Expected: exit 0

### test_unowned_file_passes
- state: deliverable "api" with corrections=3, status="in_progress"
- plan: "api" owns `src/api/*.js`
- stdin: `{"tool_name":"Write","tool_input":{"file_path":"README.md"}}`
- Expected: exit 0 (file not owned by any at-limit deliverable)

### test_non_implement_step_skips
- state: step="review", deliverable "api" with corrections=3
- stdin: file matching api glob
- Expected: exit 0 (only enforces during implement)

### test_filepath_field_variant
- state: same as at_limit_blocked
- stdin: `{"tool_name":"Edit","tool_input":{"filePath":"src/api/handler.js"}}`
- Expected: exit 2 (recognizes filePath as well as file_path)
