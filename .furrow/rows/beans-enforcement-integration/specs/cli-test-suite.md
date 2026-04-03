# Spec: cli-test-suite

## Overview

Delete old integration tests, write new test suite framed around the three CLIs.

## Files to Delete

- tests/integration/test-step-transition.sh
- tests/integration/test-correction-limit.sh
- tests/integration/test-load-step.sh
- tests/integration/test-check-artifacts.sh

## Files to Create

### tests/integration/test-sds.sh

Test all sds operations:

```sh
# Setup
sds init --prefix test-proj
assert_file_exists .furrow/seeds/config
assert_file_exists .furrow/seeds/seeds.jsonl

# Create
id=$(sds create --title "Test seed" --type task --json | jq -r '.id')
assert_not_empty "$id"

# Show
sds show "$id" --json | jq -e '.status == "open"'

# Update with extended statuses
for status in claimed ideating researching planning speccing decomposing implementing reviewing; do
  sds update "$id" --status "$status"
  sds show "$id" --json | jq -e ".status == \"$status\""
done

# Invalid status rejected
! sds update "$id" --status "in_progress" 2>/dev/null

# Close
sds close "$id" --reason "test complete"
sds show "$id" --json | jq -e '.status == "closed"'

# List
sds create --title "Open seed" --type task
count=$(sds list --json | jq -s 'length')
assert_ge "$count" 2

# Ready (dependency filtering)
id_a=$(sds create --title "Dep A" --type task --json | jq -r '.id')
id_b=$(sds create --title "Dep B" --type task --json | jq -r '.id')
sds dep add "$id_b" "$id_a"
# id_b should NOT appear in ready (blocked by id_a)
! sds ready --json | jq -e "select(.id == \"$id_b\")"
sds close "$id_a"
# now id_b should appear in ready
sds ready --json | jq -e "select(.id == \"$id_b\")"

# Search
sds search "Dep" --json | jq -e 'length > 0'

# Migrate from beans
# (test with mock .beans/ directory)
```

### tests/integration/test-rws.sh

Test rws lifecycle operations:

```sh
# Setup: ensure .furrow/ structure exists, sds initialized

# Init
rws init test-row --title "Test Row"
assert_file_exists .furrow/rows/test-row/state.json
jq -e '.step == "ideate"' .furrow/rows/test-row/state.json
jq -e '.seed_id != null' .furrow/rows/test-row/state.json

# Status
rws status test-row  # should output step info

# List
rws list --active | grep -q "test-row"

# Focus
rws focus test-row
assert_file_contains .furrow/.focused "test-row"
rws focus --clear
assert_file_not_exists .furrow/.focused  # or empty

# Load step
rws load-step test-row  # should output ideate skill content

# Transition (two-phase supervised)
rws transition --request test-row pass manual "test evidence"
jq -e '.step_status == "pending_approval"' .furrow/rows/test-row/state.json
rws transition --confirm test-row
jq -e '.step == "research"' .furrow/rows/test-row/state.json

# Verify seed status synced
seed_id=$(jq -r '.seed_id' .furrow/rows/test-row/state.json)
sds show "$seed_id" --json | jq -e '.status == "researching"'

# Rewind
rws rewind test-row ideate
jq -e '.step == "ideate"' .furrow/rows/test-row/state.json

# Diff
rws diff test-row  # should show git diff from base_commit

# Regenerate summary
rws regenerate-summary test-row
assert_file_exists .furrow/rows/test-row/summary.md

# Archive (requires full lifecycle — may need simplified test)
# ... advance through all steps to review, then:
# rws archive test-row
# jq -e '.archived_at != null' .furrow/rows/test-row/state.json
# sds show "$seed_id" --json | jq -e '.status == "closed"'
```

### tests/integration/test-alm.sh

Test alm operations:

```sh
# Setup: ensure .furrow/almanac/ exists with valid todos.yaml

# Validate
alm validate  # exit 0

# Add
alm add --title "Test TODO" --context "Testing" --work "Write test"
alm validate  # still valid
alm list --json | jq -e '.[] | select(.title == "Test TODO")'

# Show
id=$(alm list --json | jq -r '.[0].id')
alm show "$id"  # should display detail

# Extract (requires a row with artifacts)
rws init extract-test --title "Extract Test"
# ... create summary.md with Open Questions ...
alm extract extract-test | jq -e 'length >= 0'

# Triage
alm triage
assert_file_exists .furrow/almanac/roadmap.yaml

# Next
alm next  # should output handoff prompt

# Render
alm render | grep -q "Phase"  # Markdown output

# Schema: seed_id accepted
# Add seed_id to a TODO entry, validate passes
```

### tests/integration/test-lifecycle.sh (integration)

Full end-to-end lifecycle with seed sync:

```sh
# Initialize seeds
sds init --prefix lifecycle-test

# Create row from TODO
alm add --title "Lifecycle Test" --context "E2E" --work "Complete lifecycle"
rws init lifecycle-row --title "Lifecycle Test" --source-todo lifecycle-test

# Verify seed created and linked
seed_id=$(jq -r '.seed_id' .furrow/rows/lifecycle-row/state.json)
assert_not_empty "$seed_id"
sds show "$seed_id" --json | jq -e '.status == "claimed"'

# TODO backfilled with seed_id
alm show lifecycle-test | grep -q "$seed_id"

# Transition through steps, verify seed sync at each
for step in research plan spec decompose implement review; do
  # (simplified — real transitions need artifacts)
  # Verify seed status matches after each transition
done

# Archive
# rws archive lifecycle-row
# sds show "$seed_id" --json | jq -e '.status == "closed"'
```

### tests/integration/helpers.sh

Update all path references:
- `.work/` → `.furrow/rows/`
- Helper functions use `.furrow/` paths
- Cleanup functions remove `.furrow/` test directories

## Acceptance Criteria

| AC | Test |
|---|---|
| Old tests deleted | ls tests/integration/test-step-transition.sh fails |
| test-sds.sh exists | Covers init, create, update (all statuses), list, show, close, ready, dep, search |
| test-rws.sh exists | Covers init, transition, status, list, archive, rewind, diff, focus |
| test-alm.sh exists | Covers add, extract, validate, triage, next |
| Integration test exists | Full lifecycle with seed sync at every boundary |
| helpers.sh updated | No .work/ references |
