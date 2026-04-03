## Migration Note: Gate Record decided_by Values

When this branch merges to main, any existing archived work units in `.work/`
may contain gate records with old `decided_by` values:

| Old value | New value |
|-----------|-----------|
| `human` | `manual` |
| `evaluator` | `evaluated` |
| `auto-advance` | `prechecked` |

### Impact

- **Read-only consumers** (summary display, status commands): will show old values
  until records are migrated. No runtime breakage.
- **Validation consumers** (`record-gate.sh`, `update-state.sh`): only validate
  NEW records. Old records in the `gates[]` array are append-only and never
  re-validated.
- **Schema validation** (`state.schema.json`): the `decided_by` enum now accepts
  only `manual | evaluated | prechecked`. Old records will fail schema validation
  if the full `gates[]` array is validated.

### Recommended Migration

After merge to main, run a one-time migration on each `.work/*/state.json`:

```sh
# For each active or archived work unit:
for f in .work/*/state.json; do
  jq '
    .gates |= map(
      if .decided_by == "human" then .decided_by = "manual"
      elif .decided_by == "evaluator" then .decided_by = "evaluated"
      elif .decided_by == "auto-advance" then .decided_by = "prechecked"
      else . end
    )
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
```

This migration is safe because:
- Gate records are append-only (no new writes target old records)
- The mapping is 1:1 (no ambiguity)
- All existing records in practice use `"human"` (no evaluator or auto-advance records exist yet)
