# Spec: archive-integration

Deliverable from `.work/todos-workflow/definition.yaml`.

## Component

Modify the existing archive command (`commands/archive.md`) to integrate two new
ceremony steps: TODO extraction (surfacing new TODOs from the completing work unit)
and TODO pruning (resolving TODOs that this work unit was created to address). Also
add an optional `source_todo` field to the definition schema to support the
pruning linkage.

## Files Modified

| File | Change |
|------|--------|
| `commands/archive.md` | Insert TODO extraction (step 4) and pruning (step 5) into ceremony sequence |
| `adapters/shared/schemas/definition.schema.yaml` | Add optional `source_todo` property |

No new files are created. Both modifications extend existing artifacts.

## New Archive Sequence

The current archive ceremony has 6 steps. The new sequence inserts two steps
between component promotion and state marking:

| Step | Action | Existing/New |
|------|--------|--------------|
| 1 | Find task, verify review gate passed | Existing |
| 2 | **Learnings promotion**: `commands/lib/promote-learnings.sh "{name}"` | Existing |
| 3 | **Component promotion**: `commands/lib/promote-components.sh "{name}"` | Existing |
| 4 | **TODO extraction**: Run `/work-todos --extract {name}` flow | **New** |
| 5 | **TODO pruning**: Check `source_todo` linkage, propose resolution | **New** |
| 6 | Set `state.json.archived_at` to current ISO 8601 timestamp | Existing (was step 4) |
| 7 | Regenerate final `summary.md` via `commands/lib/generate-summary.sh "{name}"` | Existing (was step 5) |
| 8 | Git commit with message: `chore: archive {name}` | Existing (was step 6) |

Placement rationale: extraction runs after all promotion ceremonies are complete
(learnings and components have been reviewed), so the agent has full context about
what was promoted vs. skipped. Pruning runs after extraction so that any TODOs
just added are visible if needed. Both steps execute before `archived_at` is set,
keeping the work unit in an active state while the user makes decisions.

## Extraction Step Detail

### Trigger

Always runs during archive. The extraction flow may produce zero candidates, in
which case it completes silently.

### Behavior

The archive command delegates to the `work-todos` command in extract mode:

```
/work-todos --extract {name}
```

This invokes the full extraction ceremony as defined in `commands/work-todos.md`:

1. Run `scripts/extract-todo-candidates.sh "{name}"` to collect raw candidates
   from three sources:
   - `summary.md` open questions
   - `learnings.jsonl` unpromoted pitfalls
   - `reviews/*.json` failed/non-pass dimensions
2. Read existing `todos.yaml` (if it exists) for deduplication
3. For each candidate: reason about semantic overlap with existing entries
4. Present each candidate with a proposed action:
   - **add**: Create a new entry in `todos.yaml`
   - **merge**: Combine with an existing entry (specify which)
   - **skip**: Duplicate or not actionable
5. User confirms or overrides each proposed action
6. Write confirmed entries to `todos.yaml`

### Output within archive flow

After the extraction ceremony completes, report:

```
TODO extraction: {added} added, {merged} merged, {skipped} skipped.
```

If the extraction script returns zero candidates:

```
TODO extraction: no candidates found.
```

### Error handling

- If `todos.yaml` does not exist and the user confirms at least one candidate,
  create the file with the confirmed entries.
- If `scripts/extract-todo-candidates.sh` is missing or fails, warn and continue
  the archive (do not block archive on extraction failure).
- If `/work-todos` command definition is missing, warn and skip extraction.

## Pruning Step Detail

### Trigger

Only runs if the work unit's `definition.yaml` contains a `source_todo` field.
If the field is absent, this step is skipped silently.

### Behavior

1. Read `.work/{name}/definition.yaml` and check for `source_todo` field.
2. If absent: skip silently, proceed to step 6.
3. If present, extract the TODO id value (e.g., `source_todo: review-edge-cases`).
4. Read `todos.yaml` at the project root.
5. Find the entry with matching `id`.
6. If no matching entry found:
   - Warn: `"TODO '{id}' referenced by source_todo not found in todos.yaml (may have been removed already)."`
   - Proceed to step 6.
7. If matching entry found, present to the user:

```
This work unit was started from TODO '{id}': {title}
Mark as resolved? [yes / no / partial]
```

8. Handle the user's response:

| Response | Action |
|----------|--------|
| **yes** | Remove the entry from `todos.yaml` entirely |
| **no** | Keep the entry as-is, no modifications |
| **partial** | Append to the entry's `context` field: `"\n\nPartially addressed by work unit '{name}' (archived {timestamp})."` and update `updated_at` to current ISO 8601 timestamp |

### Output within archive flow

After pruning completes, report:

```
TODO pruning: '{id}' marked as {resolution}.
```

Or if skipped:

```
(no source_todo linkage)
```

### Error handling

- If `todos.yaml` does not exist but `source_todo` is set, warn that the TODO
  file is missing and skip pruning.
- If `todos.yaml` exists but has no entry matching the `source_todo` id, warn
  (entry may have been removed manually or by a prior archive) and skip.
- If `todos.yaml` cannot be parsed (invalid YAML), warn and skip pruning
  (do not block archive).

## Schema Change

### `adapters/shared/schemas/definition.schema.yaml`

Add `source_todo` to the `properties` block. Do **not** add it to the `required`
array -- it is optional.

```yaml
source_todo:
  type: string
  pattern: "^[a-z][a-z0-9]*(-[a-z0-9]+)*$"
  description: "ID of the TODO entry this work unit was created from"
```

This field reuses the same kebab-case slug pattern as TODO entry `id` values
(defined in `todos.schema.yaml`) and deliverable `name` values (already in
`definition.schema.yaml`). The shared pattern ensures referential consistency.

### Placement in schema

Insert after the `mode` property (last current property), before
`additionalProperties: false`:

```yaml
  mode:
    type: string
    enum: ["code", "research"]
    default: "code"
  source_todo:
    type: string
    pattern: "^[a-z][a-z0-9]*(-[a-z0-9]+)*$"
    description: "ID of the TODO entry this work unit was created from"
additionalProperties: false
```

### Impact on existing work units

Because `source_todo` is optional and `additionalProperties: false` already
governs the schema, existing `definition.yaml` files without this field remain
valid. No migration is needed.

## Acceptance Criteria

From `definition.yaml`:

1. **`commands/archive.md` updated to invoke TODO extraction after promote-learnings
   ceremony** -- the extraction step appears as step 4 in the archive sequence,
   after component promotion (step 3) and before state marking (step 6).

2. **Pruning ceremony: if archived work unit has `source_todo` in `definition.yaml`,
   propose marking that TODO resolved** -- step 5 reads `source_todo`, looks up
   the matching entry in `todos.yaml`, and presents the resolution prompt.

3. **User confirms resolution with yes/no/partial** -- all three options are
   presented and handled as specified in the pruning step detail.

4. **Resolved TODOs removed from `todos.yaml`; partial adds a note** -- "yes"
   removes the entry entirely; "partial" appends a completion note to `context`
   and bumps `updated_at`.

### Verification checklist

```
# archive.md has extraction step referencing /work-todos --extract
grep -q 'work-todos.*extract' commands/archive.md

# archive.md has pruning step referencing source_todo
grep -q 'source_todo' commands/archive.md

# archive.md documents yes/no/partial options
grep -q 'yes.*no.*partial' commands/archive.md

# definition.schema.yaml has source_todo property
yq '.properties.source_todo' adapters/shared/schemas/definition.schema.yaml

# source_todo is NOT in the required array
yq '.required[] | select(. == "source_todo")' adapters/shared/schemas/definition.schema.yaml | grep -c . | grep -q '^0$'

# source_todo has the correct pattern
yq '.properties.source_todo.pattern' adapters/shared/schemas/definition.schema.yaml | grep -q 'a-z'

# Existing definitions still validate (no required field added)
scripts/validate-definition.sh .work/todos-workflow/definition.yaml
```

## Edge Cases

### No `todos.yaml` exists yet

The extraction step creates `todos.yaml` if the user confirms at least one
candidate. The pruning step skips with a warning if the file is missing.

### `source_todo` references a non-existent entry

The TODO may have been manually removed or resolved by a prior archive. Warn
the user and skip pruning -- do not error.

### `source_todo` references an entry that was just added by extraction

Unlikely in practice (a work unit created from a TODO would not re-extract that
same TODO), but if it happens, the pruning step correctly finds and proposes
resolution of the freshly-added entry. The user can choose "no" to keep it.

### Extraction produces zero candidates

All three sources may be empty or missing. The extraction script returns an empty
JSON array `[]`. The archive command reports "no candidates found" and proceeds.

### User declines all extraction candidates

If the user skips every candidate, no writes to `todos.yaml` occur. The archive
continues normally.

### Multiple work units referencing the same `source_todo`

Each archive independently proposes resolution. If the first archive resolves
the TODO (yes), the second archive will encounter "entry not found" and warn.
This is correct behavior -- the TODO is already gone.

### Extraction or pruning script failure

Neither step should block the archive. If extraction fails (script error, missing
command), warn and continue. If pruning fails (YAML parse error, missing file),
warn and continue. The core archive operations (set `archived_at`, regenerate
summary, git commit) must always complete.

### `todos.yaml` has been manually edited with invalid YAML

If `todos.yaml` cannot be parsed during pruning, warn and skip. Do not attempt
to fix or validate the file during archive -- that is the responsibility of
`scripts/validate-todos.sh`.

### Partial resolution note formatting

The note appended during "partial" resolution uses a double newline separator
to keep it visually distinct from existing context content:

```
\n\nPartially addressed by work unit '{name}' (archived {timestamp}).
```

The `updated_at` field is set to the archive timestamp (same value used for
`state.json.archived_at`), ensuring temporal consistency.
