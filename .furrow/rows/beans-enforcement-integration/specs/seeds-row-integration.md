# Spec: seeds-row-integration

## Overview

Wire sds into rws lifecycle: auto-create seeds on init, sync status on transitions, enforce consistency via gates, auto-close on archive.

## rws init — Seed Creation

### Case 1: No --seed-id, no --source-todo
```sh
rws init my-row --title "My Row"
```
1. Create row directory and state.json
2. Read `seeds.prefix` from `.claude/furrow.yaml`
3. Call: `sds create --title "My Row" --type task`
4. Parse seed ID from sds output
5. Call: `sds update <seed_id> --status claimed`
6. Write `seed_id` to state.json

### Case 2: --seed-id provided
```sh
rws init my-row --title "My Row" --seed-id proj-a1b2
```
1. Validate seed exists: `sds show proj-a1b2` (exit 7 if not found)
2. Validate seed not closed (exit 7 if closed)
3. Create row, write `seed_id: "proj-a1b2"` to state.json
4. Update seed status: `sds update proj-a1b2 --status claimed`

### Case 3: --source-todo provided
```sh
rws init my-row --title "My Row" --source-todo beans-enforcement-integration
```
1. Read `.furrow/almanac/todos.yaml`
2. Find TODO by id
3. If TODO has `seed_id`: use it (validate exists, link to row)
4. If TODO has no `seed_id`:
   a. Create seed: `sds create --title "<todo title>" --type task`
   b. Write seed_id to state.json
   c. Backfill: update TODO entry in todos.yaml with `seed_id` field
   d. Bump TODO's `updated_at`
5. Update seed status: `sds update <seed_id> --status claimed`

## rws transition — Status Sync

After every successful step advance:
```sh
sds update "$seed_id" --status "$new_step_status"
```

Step→status mapping (hardcoded in rws):
```
ideate    → ideating
research  → researching
plan      → planning
spec      → speccing
decompose → decomposing
implement → implementing
review    → reviewing
```

This runs AFTER advance_step succeeds, BEFORE the transition completion message.

If `sds update` fails: log warning but don't fail the transition (seed sync is push-side, not blocking on push).

## rws archive — Seed Close

```sh
rws archive my-row
```
After setting `archived_at` in state.json:
```sh
sds close "$seed_id" --reason "archived: $name"
```

If close fails (seed already closed): log warning, don't block archive.

## Gate Evaluation — Seed Consistency

### Phase A (Deterministic) — check-artifacts.sh

Add after existing A5 checks:

```sh
# A6: Seed consistency (deterministic)
seed_id="$(jq -r '.seed_id // ""' "$state_file")"

if [ -z "$seed_id" ] || [ "$seed_id" = "null" ]; then
  seed_check_pass="false"
  seed_check_evidence="No seed_id in state.json — seeds are mandatory"
elif ! sds show "$seed_id" > /dev/null 2>&1; then
  seed_check_pass="false"
  seed_check_evidence="Seed not found: $seed_id"
else
  seed_status="$(sds show "$seed_id" --json | jq -r '.status')"
  if [ "$seed_status" = "closed" ]; then
    seed_check_pass="false"
    seed_check_evidence="Seed is closed: $seed_id (status=$seed_status)"
  else
    seed_check_pass="true"
    seed_check_evidence="Seed exists and is not closed: $seed_id (status=$seed_status)"
  fi
fi
```

Phase A FAIL on seed check → hard block, no Phase B evaluation.

### Phase B (Evaluator) — seed-sync dimension

File: `evals/dimensions/seed-consistency.yaml`
```yaml
dimensions:
  - name: "seed-sync"
    definition: "Whether seed status synchronizes with row step"
    pass_criteria: >-
      Seed exists, is not closed, and its status matches the current
      step per mapping: ideate→ideating, research→researching,
      plan→planning, spec→speccing, decompose→decomposing,
      implement→implementing, review→reviewing
    fail_criteria: >-
      Seed not found, seed is closed, or seed status does not match
      expected status for current step
    evidence_format: >-
      Quote seed_id from state.json, status from sds show, and
      current step. For FAIL, show expected vs actual.
```

Added to all 7 gate YAML files as `additional_dimensions`.

### Recovery (requires human input)

When seed-sync fails, rws outputs:
```
ERROR: Seed status mismatch (exit code 7)
  Row:  my-row (step: plan)
  Seed: proj-a1b2 (status: researching)
  Expected seed status: planning

To fix:
  1. Investigate why the mismatch occurred
  2. Run: sds update proj-a1b2 --status planning
  3. Re-run the gate evaluation
```

No automated recovery. User must investigate and manually correct.

## Schema Updates

### state.schema.json
- Remove: `issue_id`, `epic_id`
- Add: `seed_id` (string, required), `epic_seed_id` (string, nullable)

### todos.schema.yaml
- Add optional field: `seed_id` (string, pattern: `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`)
- Add to `source_type` enum: `"legacy"`

### furrow.yaml
Replace beans section:
```yaml
seeds:
  prefix: ""    # required, set by sds init
```

## gate-evaluator.md Update

Add to evaluation protocol:
```
For "seed-sync" dimensions: read state.json seed_id, run sds show <id>,
compare seed.status to step mapping:
  ideate → ideating, research → researching, plan → planning,
  spec → speccing, decompose → decomposing, implement → implementing,
  review → reviewing
```

## Acceptance Criteria Tests

| AC | Test |
|---|---|
| rws init auto-creates seed | After init, sds show <seed_id> succeeds |
| rws init --seed-id links existing | state.json has provided seed_id |
| rws init --source-todo backfills | todos.yaml entry gains seed_id |
| Transition syncs status | After transition to research, sds show reports "researching" |
| Gate blocks on missing seed | Remove seed_id from state.json, gate fails with exit 7 |
| Gate blocks on mismatch | Set seed to wrong status, gate fails with clear error |
| Archive closes seed | After archive, sds show reports "closed" |
| Recovery documented | Error message includes exact fix commands |
| Schema updated | jq '.properties.seed_id' state.schema.json succeeds |
