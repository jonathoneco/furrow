# Research: `bin/alm` extension blueprint

## Summary

`bin/alm` is a flat POSIX-sh CLI where each top-level verb dispatches to a
`cmd_<verb>` function via a single `case` in the tail of the file
(bin/alm:1498-1514), and subcommand groups (`learn`, `rationale`) follow a
nested pattern: `cmd_<group>` parses `${1:-}` as a subcommand, shifts, and
dispatches to `_<group>_<verb>` helpers (bin/alm:1039-1062, 1335-1354). The
`observe` family must be modeled on `cmd_learn` / `cmd_rationale`: one
top-level case entry `observe) cmd_observe "$@" ;;`, one `cmd_observe`
function that dispatches seven verbs to `_observe_<verb>` helpers. Validation
of `todos.yaml` is **inline** in `cmd_validate` (bin/alm:827-937) — there is
no `bin/frw.d/scripts/validate-todos.sh`; splitting `cmd_validate_todos` +
`cmd_validate_observations` + a tiny `cmd_validate` dispatcher is the cleanest
way to extend it without ballooning a single function past 150 lines. Feasibility
is high: every pattern the implementer needs (write-then-validate-then-rollback,
`yq`/`jq` piping, `state.json` traversal for `archived_at`) already exists in
the file and in `bin/rws` — this is a template-following exercise, not a
design exercise.

## Dispatch & help

**Top-level dispatch** — bin/alm:1493-1514

```sh
cmd="${1:-help}"
shift 2>/dev/null || true

case "$cmd" in
  add)         cmd_add "$@" ;;
  ...
  rationale)   cmd_rationale "$@" ;;
  ...
esac
```

**Add `observe` here** — insert a new case between `rationale` and `docs`
(alphabetical-ish, matches adjacency of "knowledge management" verbs):

```sh
  observe)     cmd_observe "$@" ;;
```

**Subcommand-group dispatch pattern to follow** — bin/alm:1039-1062
(`cmd_learn`) and bin/alm:1335-1354 (`cmd_rationale`). Both do:

1. `subcmd="${1:-}"; [ -n "$subcmd" ] || die "<group>: subcommand required (...)"`
2. `shift`
3. `case "$subcmd" in` dispatches to `_<group>_<verb>` helpers
4. A `--help|-h` case prints a usage block

`cmd_observe` should follow this exact shape, dispatching to
`_observe_add`, `_observe_list`, `_observe_show`, `_observe_resolve`,
`_observe_dismiss`, `_observe_activate`, `_observe_on_archive`.

**Help table** — bin/alm:1463-1486 (`cmd_help`). It's a literal heredoc.
Add one line between `rationale` and `docs`:

```
  observe     Watch-list management (add, list, show, resolve, dismiss, activate, on-archive)
```

## Validation plumbing

`cmd_validate` at bin/alm:827-937 is a single ~110-line function that:

- Accepts optional `[<path>]` arg; `resolve_todos_path` (bin/alm:49-55) returns
  that arg or `$ALM_TODOS`.
- Checks file exists (exit 2 for "not found"), schema exists (exit 2).
- Runs schema validation via a Python `jsonschema` heredoc (bin/alm:855-884),
  feeding `$SCHEMA_FILE` and a JSON-converted copy of the target file.
- Runs three cross-field checks on the parsed file: unique IDs
  (bin/alm:895-905), dependency reference integrity (bin/alm:907-918), slug
  format (bin/alm:920-928).
- Accumulates errors in `$errors`; exits 3 if any, else prints
  `"todos.yaml is valid"`.

**Dependencies callers rely on** — `cmd_add` (bin/alm:198) and `cmd_triage`
(bin/alm:523) both call `cmd_validate "$ALM_TODOS"` in a subshell to guard
writes. Any split must preserve the "validate a specific file path" interface.

**Recommended split** — factor, don't fork:

```
cmd_validate        # dispatcher: args → both, or --todos, or --observations
cmd_validate_todos       [<path>]   # current 110-line body, minus the top arg parse
cmd_validate_observations [<path>]  # new, mirror structure
```

Default `alm validate` should validate **both** files (if present) so existing
callers (`cmd_add`, `cmd_triage`) keep working. The cleanest API:

- `alm validate` → validate all almanac files (todos + observations if they
  exist)
- `alm validate --todos [PATH]` → todos only
- `alm validate --observations [PATH]` → observations only
- `alm validate <path>` (positional) → heuristic: detect which schema by
  filename or YAML shape. **Don't add the heuristic**. Preserve
  backward-compat for the two existing call sites by making
  `cmd_validate "$ALM_TODOS"` still resolve to `cmd_validate_todos "$ALM_TODOS"`
  — positional single-path arg means "validate as todos" (that's how it's
  used today).

This gives a clean extension point for observations without rewriting the
existing Python heredoc or cross-field logic.

## Path & schema resolution

**Conventions** — bin/alm:7-18:

```sh
ALM_DIR=".furrow/almanac"
ALM_TODOS="$ALM_DIR/todos.yaml"
ALM_ROADMAP="$ALM_DIR/roadmap.yaml"
ROWS_DIR=".furrow/rows"
...
SCRIPT_DIR="$(cd "$(dirname "$_alm_self")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../adapters/shared/schemas/todos.schema.yaml"
```

Key observations:

- **Path constants are plain assignments, not env-overridable.**
  `ALM_TODOS` is set directly; there is no `ALM_TODOS="${ALM_TODOS:-...}"`
  fallback. If the implementer wants env-overridable `ALM_OBSERVATIONS`,
  that would be a new convention (small, harmless, but worth asking).
- Schemas live in `adapters/shared/schemas/` resolved relative to
  `$SCRIPT_DIR`. Existing files in that dir (confirmed):
  `definition.schema.yaml`, `gate-record.schema.json`, `plan.schema.json`,
  `review-result.schema.json`, `state.schema.json`, `todos.schema.yaml`.
- `SCHEMA_FILE` is a single variable pointing at the todos schema. This
  naming will collide.

**New variables needed** — add to the Configuration block (bin/alm:7-18):

```sh
ALM_OBSERVATIONS="$ALM_DIR/observations.yaml"
SCHEMA_FILE_TODOS="$SCRIPT_DIR/../adapters/shared/schemas/todos.schema.yaml"
SCHEMA_FILE_OBSERVATIONS="$SCRIPT_DIR/../adapters/shared/schemas/observations.schema.yaml"
# Keep SCHEMA_FILE as alias for backward-compat if any downstream script reads it:
SCHEMA_FILE="$SCHEMA_FILE_TODOS"
```

`SCHEMA_FILE` is referenced only inside `cmd_validate` (bin/alm:839, 840,
852) — so the rename to `SCHEMA_FILE_TODOS` inside the split validator is
internal. Keep the `SCHEMA_FILE` alias only if `install.sh` or a hook reads
it (verify before removing).

A matching `resolve_observations_path()` helper parallel to
`resolve_todos_path` (bin/alm:49-55) should exist.

## Error handling & exit codes

**Standard error idiom** — bin/alm:22:

```sh
die() { printf 'alm: %s\n' "$1" >&2; exit "${2:-1}"; }
```

**Exit codes observed**:

| Code | Meaning | Citation |
|------|---------|----------|
| 1 | Default / usage / bad flag | bin/alm:22 default; also bin/alm:104 `"add: unknown flag"` |
| 2 | File not found (input or schema) | bin/alm:381 `die "list: todos file not found" 1` — note inconsistency! bin/alm:431 `"show: todos file not found" 1`, but bin/alm:520 `"triage: todos file not found" 2`, bin/alm:837 `"validate: file not found" 2`, bin/alm:840 `"validate: schema not found" 2` |
| 3 | Validation failure / analysis failure | bin/alm:524 `"triage: todos.yaml failed validation" 3`, bin/alm:528 `"triage: failed to parse" 3`, bin/alm:635, 640, 643 all `3`, bin/alm:933 `exit 3` from validate |

**Gotcha**: exit-code conventions are **inconsistent** for "file not found"
— `cmd_list` and `cmd_show` use `1`, `cmd_triage` and `cmd_validate` use `2`.
Observe commands should pick **2 for "not found"** and **3 for "validation
failed"** to match the stricter subset used by validate/triage, since
observations interact most closely with those.

**Flag validation pattern** — every subcommand's arg loop ends with a
catch-all `*) die "<name>: unknown flag: $1" ;;`. Required-flag checks
follow the loop, e.g. bin/alm:109-111:

```sh
[ -n "$title" ]   || die "add: --title is required"
```

## Pull-model activation query plan

`bin/rws` is the canonical reference for `state.json` queries. Three
patterns exist in it today:

**Pattern 1: check a single row's archived status** — bin/rws:134-136:

```sh
if [ -n "$_focused_name" ] && [ -f "${ROWS_DIR}/${_focused_name}/state.json" ]; then
  _archived="$(jq -r '.archived_at // "null"' "${ROWS_DIR}/${_focused_name}/state.json" 2>/dev/null)" || _archived="null"
```

**Pattern 2: scan all rows for active (archived_at == null)** — bin/rws:169-183
(`find_active_rows`):

```sh
for _state_file in ${ROWS_DIR}/*/state.json; do
  [ -f "$_state_file" ] || continue
  _archived="$(jq -r '.archived_at // "null"' "$_state_file" 2>/dev/null)" || continue
  if [ "$_archived" = "null" ]; then
    _name="$(jq -r '.name // ""' "$_state_file" 2>/dev/null)" || continue
    ...
  fi
done
```

**Pattern 3: scan all rows for archived (archived_at != null)** — bin/rws:1750,
`ls` subcommand. Same shape, opposite branch.

**"rows_since" activation query** — for an observation with predicate
`{kind: "rows_since", since: "<ISO-8601 timestamp>", n: <int>}`, compute:

```sh
# POSIX-sh, no temp files needed for the count.
_count=$(
  for _sf in "$ROWS_DIR"/*/state.json; do
    [ -f "$_sf" ] || continue
    jq -r --arg since "$since" '
      select(.archived_at != null)
      | select(.archived_at >= $since)
      | .name
    ' "$_sf" 2>/dev/null
  done | wc -l | tr -d ' '
)
if [ "$_count" -ge "$n" ]; then
  # Activate.
fi
```

ISO-8601 timestamp comparison via `jq` string comparison works because
`date -Iseconds` output (bin/alm:28-30, used everywhere) is lexicographically
sortable when normalized to the same timezone. **Gotcha**: `date -Iseconds`
includes the local TZ offset (`+00:00` or `-04:00`); if one row archived in
UTC and another with local offset, lexicographic compare breaks. Either (a)
compare parsed timestamps via `date -d ... +%s` — slow but correct, (b)
canonicalize during write, (c) accept the limitation and document it. Since
existing code (bin/rws:155) uses raw lexicographic compare on `updated_at`,
precedent favors (c).

**Alternate single-pass query** (marginally faster, avoids one `jq` per
state.json):

```sh
_count=$(jq -s --arg since "$since" '
  map(select(.archived_at != null and .archived_at >= $since)) | length
' "$ROWS_DIR"/*/state.json 2>/dev/null)
```

But this errors if the glob expands to no files — the loop form handles the
empty case via `[ -f "$_sf" ] || continue`. Prefer the loop form for
consistency with `bin/rws`.

## Validate-observations script

**No `bin/frw.d/scripts/validate-todos.sh` exists.** Confirmed with
`find bin/frw.d -name "validate*"` — the only validators are
`validate-definition.sh`, `validate-summary.sh`, `validate-naming.sh`, and
the internal `lib/validate.sh`. Todos validation lives entirely **inline in
`cmd_validate`** at bin/alm:827-937.

So there is nothing to template from. Follow this plan instead:

1. Do **not** create `bin/frw.d/scripts/validate-observations.sh`. Creating
   it would be inconsistent with how todos is handled.
2. Put the observations validation logic inline as a new function
   `cmd_validate_observations` in `bin/alm`, mirroring the shape of the
   current `cmd_validate` body (schema check via Python `jsonschema` heredoc,
   plus any cross-field checks observations needs — e.g., unique IDs,
   predicate-kind/required-field coherence, `resolved_at` and `dismissed_at`
   mutual exclusion).
3. Have the new top-level `cmd_validate` dispatcher call both
   `cmd_validate_todos` and `cmd_validate_observations` by default.

The Python `jsonschema` heredoc at bin/alm:855-881 is **fully generic** —
it takes schema and instance file paths as argv. Copy-paste without
modification; only the argv paths change.

## Gotchas & risks

1. **`cmd_validate` is called from `cmd_add` in a subshell** (bin/alm:198:
   `if ! (cmd_validate "$ALM_TODOS" >/dev/null 2>&1); then`). If the split
   dispatcher changes the signature, `cmd_add` breaks. Preserve
   `cmd_validate <path>` → "validate as todos" as the backward-compat path.
   Same for `cmd_triage` at bin/alm:523.

2. **Exit code 3 from validate escapes the subshell.** `cmd_add` detects
   this and rolls back the entry (bin/alm:200). The new
   `cmd_validate_observations` must also `exit 3` on failure — not
   `return 3` — to match, because the subshell inherits exit semantics.
   **But** `cmd_validate`'s final `exit 3` (bin/alm:933) kills the parent
   shell if called non-subshell. Every caller that wants to continue on
   failure wraps it in `(...)`. Document this for observations too.

3. **`SCHEMA_FILE` is a global referenced at function scope.** If the split
   runs both validators in sequence, neither can assume `SCHEMA_FILE` points
   at "its" schema. Use the new `SCHEMA_FILE_TODOS` /
   `SCHEMA_FILE_OBSERVATIONS` variables inside each subfunction and stop
   relying on the global inside `cmd_validate_todos`.

4. **`set -eu` is active** (bin/alm:5). Unset vars kill the script.
   `${var:-}` idiom is mandatory for optional args — used consistently
   throughout. Observe flag parsing must follow suit.

5. **`yq -i` vs temp-file-and-mv.** `cmd_add` uses temp-file-and-mv
   (bin/alm:186-194) while `cmd_rationale add` uses `yq -i` (bin/alm:1421,
   1425). For **safe write-then-validate-then-rollback** during `observe add`,
   temp-file-and-mv is required — otherwise a schema failure after
   `yq -i` has already mutated the file and rollback is harder. Follow the
   `cmd_add` template (bin/alm:186-202), not the `cmd_rationale` one.

6. **Python heredoc at bin/alm:855-881 is fragile.** Any edit that
   disturbs indentation (Python is indent-sensitive) or quoting breaks it
   silently. When factoring into `cmd_validate_todos` / `cmd_validate_observations`,
   keep the heredoc byte-identical and only vary the argv.

7. **`source_work_unit` in todos schema vs. `row` in observations.** Existing
   todos use the legacy name `source_work_unit` (bin/alm:161, 180). Confirm
   observations schema uses the current term (`source_row` or similar) so
   the cross-reference checks don't silently break.

8. **`slugify` is todos-specific** (bin/alm:40-46). If observations IDs are
   also slugs, reuse it; if they're UUIDs or timestamped, don't. Pick up
   the schema first.

## Sources Consulted

- primary — [bin/alm:5] — `set -eu` regime governs all functions
- primary — [bin/alm:7-18] — path & schema constant conventions (ALM_DIR,
  ALM_TODOS, SCHEMA_FILE pattern)
- primary — [bin/alm:22] — `die` helper and exit-code idiom
- primary — [bin/alm:49-55] — `resolve_todos_path` pattern to mirror
- primary — [bin/alm:186-202] — write-then-validate-then-rollback template
  for `observe add`
- primary — [bin/alm:827-937] — `cmd_validate` full body; no external
  script, everything inline
- primary — [bin/alm:1039-1062] — `cmd_learn` subcommand dispatcher template
- primary — [bin/alm:1335-1354] — `cmd_rationale` subcommand dispatcher
  template
- primary — [bin/alm:1463-1486] — help table insertion point
- primary — [bin/alm:1493-1514] — top-level dispatch `case` block
- primary — [bin/rws:134-136] — single-row `archived_at` query pattern
- primary — [bin/rws:149-160] — scan all rows, filter by
  `archived_at == null`
- primary — [bin/rws:169-183] — `find_active_rows` loop to template
  "rows_since" counting
- primary — [bin/rws:1750-1753] — inverse scan for archived rows
- primary — [adapters/shared/schemas/] — schema directory (todos.schema.yaml
  present; observations.schema.yaml does **not** exist yet)
- negative — `find bin/frw.d -name "validate*"` returned only definition,
  summary, naming, and lib/validate.sh — no validate-todos.sh
- negative — `grep -rn validate-todos` in bin/ and adapters/ returned zero
  hits, confirming todos validation is inline-only
