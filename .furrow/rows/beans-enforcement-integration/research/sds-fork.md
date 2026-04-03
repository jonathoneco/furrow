# Research: sds CLI Fork (D2)

## Source Analysis

`bn` at `/home/jonco/src/work-harness/bin/bn` is ~450 lines POSIX shell + jq.

### Change Surface

All paths controlled by 2 variables at file top:
- Line 7: `BEANS_DIR=".beans"` → `SDS_DIR=".furrow/seeds"`
- Line 8: `BEANS_ISSUES="$BEANS_DIR/issues.jsonl"` → `SDS_ISSUES="$SDS_DIR/seeds.jsonl"`

Status validation in single `case` statement (line 326-328):
```sh
case "$status" in
  open|in_progress|closed) ;;
  *) die "update: invalid status '$status'" ;;
esac
```

### Changes Required

| Area | Current | Target | Lines |
|------|---------|--------|-------|
| Directory var | `.beans` | `.furrow/seeds` | 7 |
| Filename var | `issues.jsonl` | `seeds.jsonl` | 8 |
| Error prefix | `bn:` | `sds:` | 14 |
| Help text | `bn ...` | `sds ...` | 566-585 |
| Init message | `Initialized beans` | `Initialized seeds` | 139 |
| Status enum | 3 values | 10 values | 326-328, 582 |
| Default status | `open` | `open` (keep — `claimed` set by rws on init) |
| `--ready` filter | `open\|in_progress` | `!= "closed"` | 234 |

### Decisions

- **Default status on create**: Keep `open`. The `rws init` flow will immediately `sds update --status claimed` after creation. This keeps sds generic.
- **`in_progress` removal**: Remove from valid statuses. Extended step-specific statuses replace it.
- **`migrate-from-beads` command**: Remove (no longer needed). Add `migrate-from-beans` for `.beans/` → `.furrow/seeds/` data migration.
- **Core mechanics unchanged**: dedup-on-read (tac + jq group_by), flock locking, merge=union all work identically with extended statuses.
- **Dependencies**: jq, tac (GNU), flock — Linux only, unchanged.

### Open Status Enum

```
open, claimed, ideating, researching, planning, speccing,
decomposing, implementing, reviewing, closed
```

10 values. `open` is the default on create. `claimed` through `reviewing` are set by `rws` during lifecycle. `closed` is set by `rws archive` or manual `sds close`.
