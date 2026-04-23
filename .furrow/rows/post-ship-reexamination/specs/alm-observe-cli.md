# Spec: alm-observe-cli

## Interface Contract

**Entry point**: new top-level verb `alm observe <subcommand> [args...]` in `bin/alm`. Dispatched via existing `case "$1" in ... observe) cmd_observe "$@" ;;` at `bin/alm:1498-1514`.

**Subcommand dispatcher**: new function `cmd_observe` that shifts `$1`, matches on subcommand, and delegates to `_observe_<verb>` helpers. Pattern mirrors `cmd_learn` (bin/alm:1039-1062) and `cmd_rationale` (bin/alm:1335-1354).

**Verbs**: `add`, `list`, `show`, `resolve`, `dismiss`, `activate`, `on-archive`. Plus `--help`/`-h` on `cmd_observe` itself and each verb.

**Extended validation**: `cmd_validate` is split into a thin dispatcher plus `cmd_validate_todos` and `cmd_validate_observations`. The public `cmd_validate "<path>"` signature is preserved — `cmd_add` (bin/alm:198) and `cmd_triage` (bin/alm:523) still call it the same way. If called with no path, it validates BOTH todos.yaml AND observations.yaml and exits non-zero if either fails.

**Data files**:
- `$ALM_TODOS` — existing, points to `.furrow/almanac/todos.yaml`.
- `$ALM_OBSERVATIONS` — new, points to `.furrow/almanac/observations.yaml`.
- `$SCHEMA_FILE_TODOS` — introduced (replaces existing `$SCHEMA_FILE` for todos).
- `$SCHEMA_FILE_OBSERVATIONS` — new, points to `adapters/shared/schemas/observations.schema.yaml`.

**Contract guarantees per verb** — see Acceptance Criteria below.

## Acceptance Criteria (Refined)

### `alm observe add`

**Signature**: `alm observe add --kind <watch|decision-review> --title <text> --trigger <row_archived|rows_since|manual> [trigger-specific flags] [kind-specific flags] [--source-work-unit <id>]`

- Trigger-specific flags:
  - `--row <name>` (required when `--trigger row_archived`)
  - `--since-row <name>` and `--count <int>` (required when `--trigger rows_since`, count >= 1)
  - (no extra flags required for `--trigger manual`)
- Kind-specific flags:
  - `--signal <text>` required when `--kind watch`
  - `--question <text>`, `--options <json-or-csv>`, `--acceptance <text>` required when `--kind decision-review`
  - `--evidence <text>` (repeatable) optional for decision-review

**Behavior**:
1. Generate `id` via slugified title (kebab-case, truncated to 40 chars, unique-suffix if collision).
2. Compose the observation object in memory as a JSON-shaped record.
3. Read current `observations.yaml` (may be `[]`), append the new entry.
4. Write to a temp file; run `cmd_validate_observations "$tmp"`.
5. On validation success: atomic `mv` to `$ALM_OBSERVATIONS` and print `added observation: <id>`.
6. On validation failure: print the schema error to stderr, delete temp file, exit 2. **Do NOT touch the real observations.yaml.**

`created_at` and `updated_at` set to current UTC `Z` timestamp. `lifecycle: open` hard-coded.

### `alm observe list`

**Signature**: `alm observe list [--active | --pending | --resolved | --dismissed | --all] [--kind watch | decision-review]`

- Default: `--active`.
- `--active` = `lifecycle == open` AND computed activation `active`.
- `--pending` = `lifecycle == open` AND computed activation `pending`.
- `--resolved` = `lifecycle == resolved`.
- `--dismissed` = `lifecycle == dismissed`.
- `--all` = no filter.

**Output**: one line per matching observation, tab-separated: `id    kind    lifecycle    activation    title`. Sorted by `created_at` ascending. No header row (grep/awk-friendly by intent).

**Computed activation** (see AD-4 in team-plan.md):
- `triggered_by.type == row_archived`:
  - Resolve `state.json.archived_at` for the named row.
  - `active` iff the timestamp is non-null.
  - `pending` iff null or the state.json does not exist.
- `triggered_by.type == rows_since`:
  - Resolve baseline: `archived_at` of `since_row`.
  - `pending` iff baseline is null (baseline not yet archived).
  - Else count rows where `archived_at > baseline.archived_at` (lexicographic compare, Z-normalized).
  - `active` iff count >= `count`.
  - `pending` otherwise.
- `triggered_by.type == manual`:
  - `active` iff `manual_activation_at` field is set.
  - `pending` otherwise.

### `alm observe show <id>`

- Print all fields of the observation (pretty-printed — not raw YAML dump).
- Include a computed block: `activation: <active|pending>`; for `rows_since`, also print `qualifying_archived_rows: N / target: M` and `baseline: <since_row archive timestamp or "not archived yet">`.
- Exit 0. Non-existent id → exit 2 with "observation not found: <id>".

### `alm observe resolve <id>`

**Signature for watch**: `alm observe resolve <id> --outcome <pass|fail|inconclusive> [--note <text>]`
**Signature for decision-review**: `alm observe resolve <id> --option <option-id> --rationale <text>`

**Behavior**:
1. Load observation by id.
2. Preflight: if `lifecycle != open`, print `cannot resolve: lifecycle is <current>` to stderr and exit 2. No mutation.
3. Validate flag set matches observation kind (watch → outcome; decision-review → option+rationale). Mismatch → exit 2.
4. Set `lifecycle: resolved`, populate `resolution` block with fields + `resolved_at: <now Z>`, bump `updated_at`.
5. Write-temp → validate → atomic mv (same pattern as `add`).
6. Print `resolved observation: <id>`.

### `alm observe dismiss <id>`

**Signature**: `alm observe dismiss <id> [--reason <text>]`

**Behavior**: same as resolve, but:
- `lifecycle != open` → exit 2.
- Set `lifecycle: dismissed`; populate `dismissal: {dismissed_at: <now Z>, reason?: <text>}`.
- Same write-temp → validate → atomic mv.

### `alm observe activate <id>`

**Signature**: `alm observe activate <id>`

**Behavior**:
1. Load observation.
2. If `triggered_by.type != manual`, print `cannot activate: trigger type is <type>; activate only works on manual triggers` to stderr and exit 2.
3. If `manual_activation_at` already set, print `already activated at <timestamp>` to stderr and exit 0 (idempotent).
4. Else set `manual_activation_at` to current UTC Z, bump `updated_at`.
5. Same write-temp → validate → atomic mv.

### `alm observe on-archive <row>`

**Signature**: `alm observe on-archive <row-name>`

**Behavior** (STATELESS — no write to observations.yaml):
1. Resolve `.furrow/rows/<row>/state.json:archived_at`. If null or file missing, exit 1 with stderr `row <row> is not archived yet`.
2. Iterate observations with `lifecycle: open`. For each, compute activation twice:
   - **With-row**: activation using the current archive history (includes `<row>`'s archived_at).
   - **Without-row**: activation that would result if `<row>`'s archived_at were treated as `null` (i.e., `<row>` had not yet archived).
3. An observation "becomes active because of <row>" iff with-row is `active` AND without-row is `pending`. This covers all three edge cases cleanly:
   - `row_archived` where `row == <row>`: without-row pending, with-row active. Matches.
   - `rows_since` where `since_row == <row>`: without-row pending (baseline null), with-row active if count threshold met. Matches.
   - `rows_since` where `since_row != <row>` but `<row>` is the Nth qualifying archive pushing count over threshold: without-row is `pending` (one less qualifying row), with-row is `active`. Matches.
4. Print a human-readable block to stdout listing each matching observation: `id, kind, title, activation_reason` (same `activation_reason` format as D3).
5. If none match, print `no observations activated by archive of <row>`.
6. Exit 0.

**No state mutation** — this is purely a display helper. Users run `alm observe resolve|dismiss` separately.

### `alm validate` (extended)

- `alm validate` (no args) runs `cmd_validate_todos "$ALM_TODOS"` and `cmd_validate_observations "$ALM_OBSERVATIONS"`. Prints each file's status line. Exit 0 iff BOTH pass; exit non-zero with a consolidated error listing if either fails.
- `alm validate <path>` — inferred from filename: if basename matches `todos*.yaml`, run todos validator; if `observations*.yaml`, run observations validator. Else, exit 2 with "unknown schema target: <path>".
- Existing callers (`cmd_add` at line 198, `cmd_triage` at line 523) pass explicit `$todos_path` — behavior preserved.

### Help

- `bin/alm` help table grows `observe` row with one-line description.
- `alm observe --help` lists all seven verbs with one-line descriptions.
- `alm observe <verb> --help` prints usage for that verb.

## Test Scenarios

### Scenario: add-watch-happy-path
- **Verifies**: `add` with watch kind
- **WHEN**: `alm observe add --kind watch --title "does dispatch work" --trigger rows_since --since-row parallel-agent-wiring --count 3 --signal "Agent tool calls visible in multi-deliverable rows"`
- **THEN**: observations.yaml has 1 entry with `lifecycle: open`, `kind: watch`, `signal: ...`; stdout prints `added observation: <id>`
- **Verification**: `alm observe list --pending` shows the entry; `alm validate` exits 0

### Scenario: add-rejects-bad-trigger-type
- **Verifies**: trigger enum enforcement (via schema)
- **WHEN**: `alm observe add --kind watch --title X --trigger row_merged --row X --signal Y`
- **THEN**: exit code 2; stderr mentions the enum; observations.yaml unchanged
- **Verification**: diff observations.yaml before/after shows no change; stderr check

### Scenario: activation-rows-since-pending
- **Verifies**: pending when baseline unarchived
- **WHEN**: observation has `triggered_by: {type: rows_since, since_row: unarchived-row, count: 3}`
- **THEN**: `alm observe list --active` does NOT show it; `alm observe list --pending` DOES; `show` prints `baseline: not archived yet`
- **Verification**: run both list filters; grep output

### Scenario: activation-rows-since-active
- **Verifies**: active after count threshold met
- **WHEN**: baseline row is archived at T0; 3+ rows have archived_at > T0
- **THEN**: `alm observe list --active` shows the observation; `show` prints `qualifying_archived_rows: 3 / target: 3`
- **Verification**: run list + show

### Scenario: resolve-wrong-kind-flags
- **Verifies**: kind/flag mismatch
- **WHEN**: observation is `kind: watch`, user runs `alm observe resolve <id> --option X --rationale Y`
- **THEN**: exit 2; stderr mentions "use --outcome/--note for watch"
- **Verification**: observations.yaml unchanged; stderr check

### Scenario: resolve-already-resolved
- **Verifies**: lifecycle preflight
- **WHEN**: observation is `lifecycle: resolved`, user runs `alm observe resolve <id> ...`
- **THEN**: exit 2; stderr mentions current lifecycle
- **Verification**: observations.yaml unchanged

### Scenario: dismiss-happy-path
- **Verifies**: dismiss lifecycle transition
- **WHEN**: `alm observe dismiss <id> --reason "no longer relevant"`
- **THEN**: observation has `lifecycle: dismissed`, `dismissal: {dismissed_at, reason}`
- **Verification**: `alm observe show <id>` prints dismissed state

### Scenario: activate-non-manual-trigger
- **Verifies**: activation is manual-only
- **WHEN**: observation has `triggered_by.type == row_archived`; user runs `alm observe activate <id>`
- **THEN**: exit 2; stderr mentions "activate only works on manual triggers"
- **Verification**: observations.yaml unchanged

### Scenario: show-happy-path
- **Verifies**: `show` displays all fields plus computed activation
- **WHEN**: Observations.yaml has entry with `id: X`, `triggered_by: {type: rows_since, since_row: foo, count: 3}`, and 2 rows archived past `foo`'s archive time.
- **THEN**: `alm observe show X` prints all persisted fields plus computed block with `activation: pending`, `qualifying_archived_rows: 2 / target: 3`.
- **Verification**: `alm observe show X | grep -q 'qualifying_archived_rows: 2'` exits 0.

### Scenario: resolve-watch-happy-path
- **Verifies**: `resolve` watch kind
- **WHEN**: Observation X is `kind: watch`, `lifecycle: open`. User runs `alm observe resolve X --outcome pass --note "dispatch working"`.
- **THEN**: X becomes `lifecycle: resolved` with `resolution: {outcome: pass, note: "dispatch working", resolved_at: <now Z>}`; stdout `resolved observation: X`.
- **Verification**: `alm observe show X` shows resolved state; `alm validate` exits 0.

### Scenario: resolve-decision-review-happy-path
- **Verifies**: `resolve` decision-review kind
- **WHEN**: Observation Y is `kind: decision-review` with `options: [{id: a, ...}, {id: b, ...}]`. User runs `alm observe resolve Y --option a --rationale "meets acceptance"`.
- **THEN**: Y becomes `lifecycle: resolved` with `resolution: {option_id: a, rationale: "meets acceptance", resolved_at: <now Z>}`.
- **Verification**: `alm observe show Y` shows resolved state; `alm validate` exits 0.

### Scenario: on-archive-surfaces-activations
- **Verifies**: on-archive display
- **WHEN**: a row X is archived; an observation with `triggered_by: {type: row_archived, row: X}` has `lifecycle: open`
- **THEN**: `alm observe on-archive X` prints the observation's id/title in stdout
- **Verification**: grep output; diff observations.yaml (must be unchanged)

### Scenario: validate-extended-covers-both-files
- **Verifies**: `alm validate` runs both validators
- **WHEN**: observations.yaml is malformed (missing required field)
- **THEN**: `alm validate` (no args) exits non-zero; stderr mentions observations file; todos validation output still shown
- **Verification**: run `alm validate` with known-bad observations.yaml; assert exit != 0

### Scenario: validate-path-inferred-by-filename
- **Verifies**: path-mode dispatch
- **WHEN**: `alm validate .furrow/almanac/observations.yaml`
- **THEN**: only the observations validator runs; todos not touched
- **Verification**: strace/log pattern or output match

## Implementation Notes

**Reference AD-3, AD-4** (team-plan.md).

**`cmd_validate` split strategy**:
```
cmd_validate() {
  case "${1:-}" in
    "")
      # No arg: validate both
      _rc=0
      cmd_validate_todos "$ALM_TODOS" || _rc=$?
      cmd_validate_observations "$ALM_OBSERVATIONS" || _rc=$?
      return $_rc
      ;;
    *)
      # Path arg: infer by basename
      case "$(basename "$1")" in
        todos*.yaml) cmd_validate_todos "$1" ;;
        observations*.yaml) cmd_validate_observations "$1" ;;
        *) die "validate: unknown schema target: $1" 2 ;;
      esac
      ;;
  esac
}
```

Each per-file validator wraps the existing yq-to-JSON + python3 Draft202012Validator pipeline (bin/alm:855-881) byte-identical except for schema file path. Use `$SCHEMA_FILE_TODOS` and `$SCHEMA_FILE_OBSERVATIONS` rather than the existing global `$SCHEMA_FILE`.

**Pull-model activation query** (per AD-4):
```sh
_observe_compute_activation() {
  # stdin: observation JSON; stdout: "active" or "pending"
  _trig_type=$(jq -r '.triggered_by.type')
  case "$_trig_type" in
    row_archived)
      _row=$(jq -r '.triggered_by.row')
      _archived=$(jq -r '.archived_at // "null"' "$ROWS_DIR/$_row/state.json" 2>/dev/null || echo "null")
      [ "$_archived" = "null" ] && echo "pending" || echo "active"
      ;;
    rows_since)
      _since=$(jq -r '.triggered_by.since_row')
      _target=$(jq -r '.triggered_by.count')
      _baseline=$(jq -r '.archived_at // "null"' "$ROWS_DIR/$_since/state.json" 2>/dev/null || echo "null")
      if [ "$_baseline" = "null" ]; then echo "pending"; return; fi
      _count=0
      for _sf in "$ROWS_DIR"/*/state.json; do
        _a=$(jq -r '.archived_at // "null"' "$_sf" 2>/dev/null) || continue
        [ "$_a" = "null" ] && continue
        [ "$_a" \> "$_baseline" ] && _count=$((_count + 1))
      done
      [ "$_count" -ge "$_target" ] && echo "active" || echo "pending"
      ;;
    manual)
      _manual_ts=$(jq -r '.manual_activation_at // "null"')
      [ "$_manual_ts" = "null" ] && echo "pending" || echo "active"
      ;;
  esac
}
```

Invariant: all `archived_at` timestamps are UTC with trailing `Z`. Lexicographic compare only correct under that invariant. Document in a comment.

**Write-validate-mv pattern** for every verb that mutates observations.yaml:
```sh
_observe_write_validated() {
  # $1 = full new JSON array; writes observations.yaml atomically iff valid
  _tmp=$(mktemp)
  _err=$(mktemp)
  printf '%s' "$1" | yq -P -o=yaml '.' > "$_tmp"
  # Capture validation output once; print on failure.
  if cmd_validate_observations "$_tmp" > "$_err" 2>&1; then
    rm -f "$_err"
    mv "$_tmp" "$ALM_OBSERVATIONS"
  else
    cat "$_err" >&2
    rm -f "$_tmp" "$_err"
    return 2
  fi
}
```

**Help table**: add `observe  Manage post-ship observations` to the help listing near `bin/alm:1476`.

## Dependencies

- **Blocks on**: D1 (observations-schema) — both for schema file availability and for the CLI to validate against.
- **Unblocks**: D3 (archive integration invokes `alm observe on-archive`); D4 (migration writes to observations.yaml via `alm observe add` or directly-with-validate).
- External tools: `yq`, `jq`, `python3` (with `jsonschema` module). Already dependencies of `cmd_validate`.
