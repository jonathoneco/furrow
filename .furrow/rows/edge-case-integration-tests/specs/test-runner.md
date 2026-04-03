# Spec: test-runner

## Files
- `scripts/run-integration-tests.sh` — entry point
- `tests/integration/helpers.sh` — shared test utilities

## run-integration-tests.sh

```
#!/bin/sh
set -eu
```

1. Resolve HARNESS_ROOT relative to script location
2. Discover all `tests/integration/test-*.sh` files
3. For each test file:
   - Source the file
   - Discover all functions matching `test_*`
   - Run each function, capture exit code
   - Track pass/fail counts
4. Print summary: `{passed}/{total} tests passed`
5. Exit 0 if all pass, exit 1 if any fail

## helpers.sh

### setup_fixture(name)
- Creates temp dir via `mktemp -d`
- Creates `.work/{name}/` structure inside it
- Exports `FIXTURE_DIR`, `WORK_DIR`, `HARNESS_ROOT` pointing to the temp dir
- Returns the temp dir path

### teardown_fixture()
- Removes `$FIXTURE_DIR` recursively

### assert_exit_code(description, expected, actual)
- Compares exit codes; prints PASS/FAIL with description
- Returns 0 on match, 1 on mismatch

### assert_file_exists(description, path)
- Checks file exists; prints PASS/FAIL
- Returns 0/1

### assert_file_contains(description, path, pattern)
- Greps file for pattern; prints PASS/FAIL
- Returns 0/1

### assert_json_field(description, file, jq_expr, expected)
- Runs `jq -r` with expression, compares to expected
- Returns 0/1

### Global tracking
- `TESTS_PASSED=0`, `TESTS_FAILED=0` counters incremented by assert functions
- `run_test(func_name)` wrapper that calls function, handles set -e, updates counters
