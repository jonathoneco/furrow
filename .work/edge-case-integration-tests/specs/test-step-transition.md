# Spec: test-step-transition

## File
`tests/integration/test-step-transition.sh`

## Fixture Requirements
- `.work/{name}/state.json` with step, steps_sequence, deliverables map, gates array
- Scripts that step-transition.sh calls must be available:
  - `scripts/record-gate.sh`
  - `scripts/update-state.sh`
  - `scripts/validate-step-artifacts.sh`
  - `scripts/regenerate-summary.sh`
  - `scripts/advance-step.sh`
- Full harness structure (symlink or copy) since subcalls are chained

## Test Cases

### test_fail_increments_in_progress_only
- state: step="implement", deliverables: {"api": {status: "in_progress", corrections: 0}, "docs": {status: "completed", corrections: 0}}
- Run: step-transition.sh {name} fail manual "test failure"
- Expected: exit 0, api.corrections=1, docs.corrections=0

### test_fail_leaves_completed_untouched
- Same as above but verify docs.corrections stays 0 and docs.status stays "completed"
- This is effectively asserted in the same test as above

### test_pass_at_final_step
- state: step="review" (final step in sequence)
- Run: step-transition.sh {name} pass manual "all reviews pass"
- Expected: exit 3 (cannot advance past final step)

### test_fail_at_final_step
- state: step="review"
- Run: step-transition.sh {name} fail manual "review failed"
- Expected: exit 0, step still "review", step_status reset to "in_progress"
