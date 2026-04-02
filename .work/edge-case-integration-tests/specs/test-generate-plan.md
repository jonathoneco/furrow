# Spec: test-generate-plan

## File
`tests/integration/test-generate-plan.sh`

## Fixture Requirements
- Temp dir with `.work/{name}/definition.yaml`
- `hooks/lib/validate.sh` must be sourceable (symlink or copy HARNESS_ROOT)

## Test Cases

### test_linear_chain
- definition: A depends_on B, B depends_on C, C has no deps
- Expected: plan.json with wave 1=[C], wave 2=[B], wave 3=[A]
- Assert: exit 0, plan.json exists, wave assignments correct via jq

### test_diamond_dependency
- definition: D depends_on [B, C], B depends_on A, C depends_on A
- Expected: wave 1=[A], wave 2=[B,C], wave 3=[D]
- Assert: exit 0, D in wave 3

### test_cycle_detection
- definition: A depends_on B, B depends_on C, C depends_on A
- Expected: exit 3, stderr contains "cycle"
- Assert: exit 3, no plan.json written

### test_multi_root_dag
- definition: A (no deps), B (no deps), C depends_on A, D depends_on B
- Expected: wave 1=[A,B], wave 2=[C,D]
- Assert: exit 0, A and B both in wave 1

### test_missing_specialist
- definition: deliverable with no specialist field
- Expected: exit 3, stderr contains "specialist"
- Assert: exit 3, no plan.json written
