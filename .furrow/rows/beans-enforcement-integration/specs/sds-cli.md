# sds CLI Implementation Spec

## Overview

`sds` (seeds) is a POSIX shell + jq seed tracker forked from `bn` (beans) at
`/home/jonco/src/work-harness/bin/bn`. It tracks seeds (lightweight issue records)
that integrate with the Furrow harness row lifecycle via `rws`.

Source: ~450 lines of POSIX shell + jq. Target: `bin/sds` in the furrow repo.

Runtime dependencies (unchanged from bn): `jq`, `tac` (GNU coreutils),
`flock` (util-linux). Linux only.

---

## File: `bin/sds`

### Variables (top of file)

```sh
SDS_DIR=".furrow/seeds"
SDS_ISSUES="$SDS_DIR/seeds.jsonl"
SDS_CONFIG="$SDS_DIR/config"
SDS_LOCK="$SDS_DIR/.lock"
```

### Comment header

```sh
#!/bin/sh
# seeds (sds) — minimal git-native seed tracker
# Requires: jq, tac (GNU coreutils), flock (util-linux). Linux only.
# No daemon, no database, no external runtime dependencies.
set -eu
```

### Status enum

Valid statuses (10 values):

```
open, claimed, ideating, researching, planning, speccing,
decomposing, implementing, reviewing, closed
```

- Default on `sds create`: `open`
- The `rws` CLI sets `claimed` after row initialization links a seed.
- Status validation applies in `cmd_update` and anywhere status is checked.

### Harness step-to-status mapping

| Harness step   | Seed status    |
|----------------|----------------|
| (just created) | open           |
| (row linked)   | claimed        |
| ideate         | ideating       |
| research       | researching    |
| plan           | planning       |
| spec           | speccing       |
| decompose      | decomposing    |
| implement      | implementing   |
| review         | reviewing      |
| (archived)     | closed         |

---

## Changes from bn

### 1. Path variables

| bn                          | sds                                  |
|-----------------------------|---------------------------------------|
| `BEANS_DIR=".beans"`        | `SDS_DIR=".furrow/seeds"`             |
| `BEANS_ISSUES="$BEANS_DIR/issues.jsonl"` | `SDS_ISSUES="$SDS_DIR/seeds.jsonl"` |
| `BEANS_CONFIG="$BEANS_DIR/config"` | `SDS_CONFIG="$SDS_DIR/config"` |
| `BEANS_LOCK="$BEANS_DIR/.lock"` | `SDS_LOCK="$SDS_DIR/.lock"`       |

### 2. Error prefix

All calls to `die()` use `sds:` prefix instead of `bn:`.

```sh
die() { printf 'sds: %s\n' "$*" >&2; exit 1; }
```

Error messages within `locked_update` and `cmd_close` that inline the prefix
(`printf 'bn: ...'`) must also change to `sds:`.

### 3. Help text

All references to `bn` in the help text, usage strings, and command
descriptions change to `sds`. All references to "beans" change to "seeds".
All references to "issues" in user-facing text change to "seeds".

### 4. Init message

```sh
# bn:
printf 'Initialized beans in %s/ (prefix: %s)\n' "$BEANS_DIR" "$prefix"
# sds:
printf 'Initialized seeds in %s/ (prefix: %s)\n' "$SDS_DIR" "$prefix"
```

### 5. Status validation case statement

Replace the 3-value enum with the full 10-value enum in `cmd_update`:

```sh
# bn:
case "$status" in
  open|in_progress|closed) ;;
  *) die "update: invalid status '$status'" ;;
esac

# sds:
case "$status" in
  open|claimed|ideating|researching|planning|speccing|decomposing|implementing|reviewing|closed) ;;
  *) die "update: invalid status '$status'" ;;
esac
```

### 6. `--ready` filter

The `--ready` flag changes from filtering `open|in_progress` to filtering
anything that is not `closed`. This reflects the broader status enum where
any non-closed seed with satisfied dependencies is actionable.

```sh
# bn:
select(.status == "open" or .status == "in_progress")

# sds:
select(.status != "closed")
```

### 7. Remove `migrate-from-beads` command

Delete `cmd_migrate()` and the `migrate-from-beads)` case in the dispatcher.

### 8. Add `migrate-from-beans` command

New function `cmd_migrate_from_beans()`:

```sh
cmd_migrate_from_beans() {
  beans_file=".beans/issues.jsonl"
  beans_config=".beans/config"
  [ -f "$beans_file" ] || die "migrate: $beans_file not found"

  if [ ! -d "$SDS_DIR" ]; then
    # Auto-init with same prefix as beans
    if [ -f "$beans_config" ]; then
      beans_prefix=$(cat "$beans_config")
    else
      beans_prefix=$(head -1 "$beans_file" | jq -r '.id' | sed 's/-[^-]*$//')
    fi
    cmd_init --prefix "$beans_prefix"
  fi

  count=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # Transform beans format to seeds format
    transformed=$(printf '%s\n' "$line" | jq -c '
      {
        id: .id,
        title: .title,
        status: (
          if .status == "in_progress" then "claimed"
          elif .status == "closed" then "closed"
          else .status
          end
        ),
        type: (.type // "task"),
        priority: (.priority // 2),
        description: (.description // null),
        close_reason: (.close_reason // null),
        depends_on: (.depends_on // []),
        blocks: (.blocks // []),
        created_at: .created_at,
        updated_at: .updated_at,
        closed_at: (.closed_at // null)
      }
    ')
    printf '%s\n' "$transformed" >> "$SDS_ISSUES"
    count=$((count + 1))
  done < "$beans_file"

  printf 'Migrated %d seeds from beans to seeds\n' "$count"
}
```

Status mapping during migration:

| beans status  | seeds status |
|---------------|--------------|
| `open`        | `open`       |
| `in_progress` | `claimed`    |
| `closed`      | `closed`     |

Dispatcher entry:

```sh
migrate-from-beans) shift; cmd_migrate_from_beans "$@" ;;
```

### 9. Gitattributes entry

```sh
# bn:
entry="$BEANS_ISSUES merge=union"
# sds:
entry="$SDS_ISSUES merge=union"
```

This produces: `.furrow/seeds/seeds.jsonl merge=union`

### 10. Comment header

See "Comment header" section above. `"beans (bn)"` becomes `"seeds (sds)"`.

---

## Subcommands

### `sds init [--prefix NAME]`

**Purpose:** Initialize the `.furrow/seeds/` directory.

**Arguments:**
- `--prefix NAME` (optional): Project prefix for seed IDs. If omitted,
  auto-detects from the current directory name (lowercased, non-alphanumeric
  replaced with `-`).

**Behavior:**
1. If `$SDS_DIR` already exists, exit with error: `"already initialized
   ($SDS_DIR exists)"`.
2. Create `$SDS_DIR` directory.
3. Write prefix to `$SDS_CONFIG`.
4. Create empty `$SDS_ISSUES` file.
5. Add `$SDS_ISSUES merge=union` to `.gitattributes` (create if missing,
   append if not already present).
6. Print: `Initialized seeds in .furrow/seeds/ (prefix: <prefix>)`.

**Exit codes:**
- `0`: Success.
- `1`: Already initialized or unknown option.

**Output format:** Single line confirmation to stdout.

---

### `sds create --title "..." [--type T] [--priority N] [--description "..."]`

**Purpose:** Create a new seed entry.

**Arguments:**
- `--title "..."` (required): Seed title.
- `--type T` (optional, default: `task`): One of `task`, `bug`, `feature`, `epic`.
- `--priority N` (optional, default: `2`): Integer 0-4 (0=critical, 4=backlog).
- `--description "..."` (optional): Free-text description.

**Behavior:**
1. Require initialization (`.furrow/seeds/seeds.jsonl` must exist).
2. Validate `--title` is non-empty.
3. Validate `--type` is one of: `task`, `bug`, `feature`, `epic`.
4. Validate `--priority` is 0-4.
5. Generate unique ID: `<prefix>-<4 hex chars>` (from 2 random bytes via
   `/dev/urandom`). Retry up to 10 times on collision.
6. Construct JSON record with `status: "open"` and `locked_append` to data file.
7. Print the generated ID to stdout.

**JSON record schema:**

```json
{
  "id": "<prefix>-<hex>",
  "title": "...",
  "status": "open",
  "type": "task|bug|feature|epic",
  "priority": 0-4,
  "description": "..." | null,
  "close_reason": null,
  "depends_on": [],
  "blocks": [],
  "created_at": "<ISO 8601>",
  "updated_at": "<ISO 8601>",
  "closed_at": null
}
```

**Exit codes:**
- `0`: Success (prints ID to stdout).
- `1`: Missing `--title`, invalid type, invalid priority, not initialized,
  ID generation failure.

**Output format:** Single line with the generated ID (e.g., `proj-a1b2`).

---

### `sds list [--status S] [--type T] [--ready] [--json]`

**Purpose:** List seeds with optional filters.

**Arguments:**
- `--status S` (optional): Filter by exact status value.
- `--type T` (optional): Filter by type.
- `--ready` (optional): Show seeds that are not closed and whose dependencies
  are all closed.
- `--json` (optional): Output as JSONL (one JSON object per line).

**Behavior:**
1. Require initialization.
2. Read and deduplicate all seeds (last occurrence wins per ID).
3. Apply filters in order: status, type.
4. If `--ready`: filter to seeds where `status != "closed"` and all entries
   in `depends_on` have `status == "closed"`.
5. Output results.

**Exit codes:**
- `0`: Always (even if no results).

**Output format (human):**
```
  <id>  [<status>] P<priority> (<type>) <title>
```

**Output format (--json):** One compact JSON object per line (JSONL).

**Output format (--ready, human):**
```
  <id>  [<status>] <title>
```

**Note on empty results:** Prints `No issues found.` when no seeds match
(human mode, non-ready). Ready mode with no results produces no output.

---

### `sds show <id> [--json]`

**Purpose:** Show details of a single seed.

**Arguments:**
- `<id>` (required, positional): Seed ID.
- `--json` (optional): Output as pretty-printed JSON.

**Behavior:**
1. Require initialization.
2. Find seed by ID in deduplicated data.
3. Exit with error if not found.
4. Display seed details.

**Exit codes:**
- `0`: Found and displayed.
- `1`: Not initialized or seed not found.

**Output format (human):**
```
Issue: <id>
Title: <title>
Status: <status>
Type: <type>
Priority: P<priority>
Created: <created_at>
Updated: <updated_at>
[Closed: <closed_at>]
[Description: <description>]
[Reason: <close_reason>]
[Depends on: <id>, <id>]
[Blocks: <id>, <id>]
```

**Output format (--json):** Pretty-printed JSON object.

---

### `sds update <id> [--status S] [--priority N] [--title "..."] [--description "..."]`

**Purpose:** Update one or more fields on a seed.

**Arguments:**
- `<id>` (required, positional): Seed ID.
- `--status S` (optional): New status (must be one of the 10 valid statuses).
- `--priority N` (optional): New priority (0-4).
- `--title "..."` (optional): New title.
- `--description "..."` (optional): New description.

**Behavior:**
1. Require initialization.
2. Validate status against full 10-value enum if provided.
3. Validate priority is 0-4 if provided.
4. At least one field must be specified (error otherwise).
5. Append updated record via `locked_update` (flock-protected).
6. Print confirmation.

**Status validation:**
```sh
case "$status" in
  open|claimed|ideating|researching|planning|speccing|decomposing|implementing|reviewing|closed) ;;
  *) die "update: invalid status '$status'" ;;
esac
```

**Exit codes:**
- `0`: Updated successfully.
- `1`: Not initialized, seed not found, invalid status, invalid priority,
  nothing to update.

**Output format:** `Updated <id>` to stdout.

---

### `sds close <id> [<id2>...] [--reason "..."]`

**Purpose:** Close one or more seeds.

**Arguments:**
- `<id>` (required, positional, repeatable): One or more seed IDs.
- `--reason "..."` (optional): Close reason text.

**Behavior:**
1. Require initialization.
2. For each ID:
   a. Acquire flock on `$SDS_LOCK`.
   b. Find seed by ID. Exit with error if not found.
   c. Set `status` to `"closed"`, `closed_at` to current timestamp,
      `updated_at` to current timestamp.
   d. If `--reason` provided, set `close_reason`.
   e. Append updated record.
3. Print confirmation for each closed seed.

**Exit codes:**
- `0`: All seeds closed.
- `1`: Not initialized, no IDs provided, any seed not found.

**Output format:** One `Closed <id>` line per seed.

---

### `sds search <keyword> [--status S] [--json]`

**Purpose:** Search seeds by keyword (case-insensitive substring match in raw JSONL).

**Arguments:**
- `<keyword>` (required, positional): Search term.
- `--status S` (optional): Filter results by status.
- `--json` (optional): Output as JSONL.

**Behavior:**
1. Require initialization.
2. `grep -iF` the keyword against the raw JSONL file.
3. Deduplicate matches (last occurrence per ID wins).
4. Apply status filter if provided.
5. Output results.

**Exit codes:**
- `0`: Always (even if no matches).

**Output format (human):**
```
  <id>  [<status>] <title>
    Reason: <close_reason>     (only if present)
```

**Output format (--json):** JSONL (one compact JSON object per line).

**No matches:** Prints `No matches.` (human mode).

---

### `sds ready [--json]`

**Purpose:** Show seeds that are not closed and have all dependencies satisfied.

**Arguments:**
- `--json` (optional): Output as JSONL.

**Behavior:** Delegates to `cmd_list --ready [--json]`.

**Ready criteria:** `status != "closed"` AND every ID in `depends_on` has
`status == "closed"` in the current data.

**Exit codes:**
- `0`: Always.

**Output format:** Same as `sds list --ready`.

---

### `sds dep add <issue> <depends-on>`

**Purpose:** Add a dependency relationship between two seeds.

**Arguments:**
- `<issue>` (required, positional): The seed that depends on something.
- `<depends-on>` (required, positional): The seed being depended upon.

**Behavior:**
1. Require initialization.
2. Acquire flock.
3. Verify both seeds exist (exit with error if either missing).
4. Add `<depends-on>` to the `depends_on` array of `<issue>` (deduplicated).
5. Add `<issue>` to the `blocks` array of `<depends-on>` (deduplicated).
6. Append both updated records.

**Exit codes:**
- `0`: Dependency added.
- `1`: Not initialized, either seed not found.

**Output format:** `<issue> now depends on <depends-on>`

---

### `sds dep rm <issue> <depends-on>`

**Purpose:** Remove a dependency relationship.

**Arguments:**
- `<issue>` (required, positional): The seed that had the dependency.
- `<depends-on>` (required, positional): The seed that was depended upon.

**Behavior:**
1. Require initialization.
2. Acquire flock.
3. Remove `<depends-on>` from `depends_on` of `<issue>`.
4. Remove `<issue>` from `blocks` of `<depends-on>`.
5. Append both updated records.

**Exit codes:**
- `0`: Dependency removed.
- `1`: Not initialized.

**Output format:** `Removed dependency: <issue> no longer depends on <depends-on>`

---

### `sds migrate-from-beans`

**Purpose:** Migrate data from the legacy `.beans/` directory to `.furrow/seeds/`.

**Arguments:** None.

**Behavior:**
1. Check that `.beans/issues.jsonl` exists (exit with error if not).
2. If `.furrow/seeds/` is not initialized:
   a. Read prefix from `.beans/config` if it exists.
   b. Otherwise extract prefix from the first record's ID.
   c. Auto-run `cmd_init --prefix <prefix>`.
3. Read each line from `.beans/issues.jsonl`.
4. Transform each record:
   - Map `in_progress` status to `claimed`.
   - Preserve all other fields.
   - Normalize optional fields to null/empty-array defaults.
5. Append each transformed record to `$SDS_ISSUES`.
6. Print count of migrated records.

**Exit codes:**
- `0`: Migration complete.
- `1`: `.beans/issues.jsonl` not found.

**Output format:** `Migrated N seeds from beans to seeds`

**Note:** This does NOT delete `.beans/`. The caller decides when to remove it.

---

## Internal Functions (preserved from bn)

### `die()`
Print `sds: <message>` to stderr and exit 1.

### `require_init()`
Check `$SDS_ISSUES` exists; die with `"not initialized -- run 'sds init' first"`.

### `require_jq()`
Check `jq` is on PATH; die if not.

### `get_prefix()`
Read and print contents of `$SDS_CONFIG`. Die if missing.

### `now_iso()`
Print current UTC time in ISO 8601 format (`%Y-%m-%dT%H:%M:%SZ`).

### `gen_id()`
Generate `<prefix>-<4 hex>` from 2 random bytes. Retry up to 10 times on
collision. Die on exhaustion.

### `read_issues()`
Read `$SDS_ISSUES`, reverse with `tac`, deduplicate by ID (last occurrence
wins), sort by `created_at`, output as JSON array. Returns `[]` if file is empty.

### `locked_append()`
`flock -x` on `$SDS_LOCK`, append one JSON line to `$SDS_ISSUES`.

### `locked_update()`
`flock -x` on `$SDS_LOCK`, read + deduplicate, find record by ID, apply
field updates (status, priority, title, description), set `updated_at`,
append updated record.

---

## Main Dispatcher

```sh
require_jq

case "${1:-}" in
  init)                shift; cmd_init "$@" ;;
  create)              shift; cmd_create "$@" ;;
  list)                shift; cmd_list "$@" ;;
  show)                shift; cmd_show "$@" ;;
  update)              shift; cmd_update "$@" ;;
  close)               shift; cmd_close "$@" ;;
  search)              shift; cmd_search "$@" ;;
  dep)                 shift; cmd_dep "$@" ;;
  ready)               shift; cmd_ready "$@" ;;
  migrate-from-beans)  shift; cmd_migrate_from_beans "$@" ;;
  -h|--help|help)
    cat <<'EOF'
seeds (sds) — minimal git-native seed tracker

Commands:
  sds init [--prefix NAME]              Initialize .furrow/seeds/ directory
  sds create --title "..." [--type T] [--priority N] [--description "..."]
  sds list [--status S] [--type T] [--ready] [--json]
  sds show <id> [--json]                Show seed details
  sds update <id> [--status S] [--priority N] [--title "..."] [--description "..."]
  sds close <id> [<id2>...] [--reason "..."]
  sds search <keyword> [--status S] [--json]
  sds dep add <issue> <depends-on>      Add dependency
  sds dep rm <issue> <depends-on>       Remove dependency
  sds ready [--json]                    Show seeds with no open blockers
  sds migrate-from-beans                Import .beans/issues.jsonl

Status: open, claimed, ideating, researching, planning, speccing,
        decomposing, implementing, reviewing, closed
Types: task, bug, feature, epic
Priority: 0=critical, 1=high, 2=medium, 3=low, 4=backlog
EOF
    ;;
  "")
    die "no command specified (try 'sds help')"
    ;;
  *)
    die "unknown command '$1' (try 'sds help')"
    ;;
esac
```

---

## Data Format

### seeds.jsonl

Append-only JSONL file. Each line is a complete JSON object representing the
current state of a seed at the time of write. Deduplication happens at read
time (last line per ID wins).

**Concurrency:** All writes use `flock -x` on `$SDS_LOCK`.

**Git merge strategy:** `merge=union` in `.gitattributes` ensures concurrent
branch edits append rather than conflict.

### config

Single line containing the project prefix string (e.g., `proj`).

---

## install.sh Integration

The `install.sh` symlink table must include an entry for `sds`:

```sh
sds          bin/sds
```

This creates a symlink at `~/.local/bin/sds` (or the configured install
prefix) pointing to `bin/sds` in the furrow repo.

---

## Acceptance Criteria Tests

### AC1: bin/sds exists as POSIX shell + jq script

```sh
test -f bin/sds
head -1 bin/sds | grep -q '#!/bin/sh'
grep -q 'jq' bin/sds
```

### AC2: sds init --prefix proj creates .furrow/seeds/config

```sh
cd "$(mktemp -d)"
git init
sds init --prefix proj
test -f .furrow/seeds/config
test "$(cat .furrow/seeds/config)" = "proj"
test -f .furrow/seeds/seeds.jsonl
grep -qF '.furrow/seeds/seeds.jsonl merge=union' .gitattributes
```

### AC3: sds create --title "test" --type task creates entry in seeds.jsonl

```sh
id=$(sds create --title "test seed" --type task)
test -n "$id"
grep -q "\"id\":\"${id}\"" .furrow/seeds/seeds.jsonl
grep -q '"status":"open"' .furrow/seeds/seeds.jsonl
grep -q '"type":"task"' .furrow/seeds/seeds.jsonl
```

### AC4: sds update <id> --status implementing succeeds

```sh
id=$(sds create --title "status test")
sds update "$id" --status implementing
sds show "$id" --json | jq -e '.status == "implementing"'
```

### AC5: All 10 statuses accepted

```sh
for status in open claimed ideating researching planning speccing \
              decomposing implementing reviewing closed; do
  id=$(sds create --title "test-$status")
  sds update "$id" --status "$status"
  actual=$(sds show "$id" --json | jq -r '.status')
  test "$actual" = "$status"
done

# Invalid status rejected
id=$(sds create --title "reject test")
! sds update "$id" --status "in_progress" 2>/dev/null
```

### AC6: --json flag outputs valid JSONL

```sh
sds create --title "json test 1"
sds create --title "json test 2"
sds list --json | while IFS= read -r line; do
  printf '%s' "$line" | jq -e . >/dev/null
done
```

### AC7: Data stored in .furrow/seeds/seeds.jsonl with flock

```sh
test -f .furrow/seeds/seeds.jsonl
grep -q 'flock' bin/sds
# Verify lock file used
sds create --title "lock test"
# Lock file should exist after operations
test -f .furrow/seeds/.lock || true  # lock file created on first write
```

### AC8: install.sh symlink table includes sds

```sh
grep -qE 'sds\s+bin/sds' install.sh
```
