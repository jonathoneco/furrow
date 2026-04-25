# Spec: repair-deliverables-cli

## Interface Contract

### Go function signature

```go
// internal/cli/row_repair.go
func (a *App) runRowRepairDeliverables(args []string) error
```

The function is called from `internal/cli/app.go` via the `runRow` dispatcher. It returns an `int`
exit code following the same convention as all other `run*` functions — the outer wrapper converts
`error` returns via `a.fail(...)`:

```go
// internal/cli/app.go — runRow() switch block (additive; wave 1 only)
case "repair-deliverables":
    return a.runRowRepairDeliverables(args[1:])
```

This edit is additive: no existing cases are modified. Wave 3 edits to `app.go` (if any) are in
different switch branches and will not conflict.

### CLI surface

```
furrow row repair-deliverables <row-name> --manifest <path> [--force-active] [--replace] [--json]
furrow row repair-deliverables --help
```

| Flag | Type | Required | Description |
|---|---|---|---|
| `<row-name>` | positional | yes | Kebab-case row identifier |
| `--manifest` | string (path) | yes | Path to YAML or JSON repair manifest |
| `--force-active` | bool | no | Allow repair of non-archived rows |
| `--replace` | bool | no | Overwrite existing deliverables present in the manifest |
| `--json` | bool | no | Emit JSON envelope on stdout (standard pattern) |

`parseArgs` call:
```go
positionals, flags, err := parseArgs(args,
    map[string]bool{"manifest": true},
    map[string]bool{"force-active": true, "replace": true},
)
```

### Manifest file format

Accepted as YAML (primary) or JSON. Schema: `schemas/repair-deliverables-manifest.schema.json`.

Example manifest (YAML):

```yaml
version: "1"
decided_by: manual
commit: e4adef5
deliverables:
  - name: backend-work-loop-support
    status: completed
    commit: e4adef5
    evidence_paths:
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md
        lines: "3-45"
        note: "test coverage"
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md
        lines: "9-16"
        note: "outcome summary"
  - name: pi-work-command
    status: completed
    commit: e4adef5
    evidence_paths:
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md
        lines: "46-52"
        note: "headless /work validation"
```

Top-level `commit` is a convenience default; per-entry `commit` overrides it. `decided_by` defaults
to `manual` if omitted. **Each deliverable entry MUST contain an `evidence_paths` array (1+ entries),
not a singular `evidence_path` field.** Each evidence-path object requires `path` (string); `lines`
(string, e.g. `"3-45"`) and `note` (string) are optional.

### Exit code catalog

| Code | Meaning |
|---|---|
| 0 | Success — all new deliverables written, state.json updated |
| 1 | Usage error — wrong flags, missing required argument |
| 2 | Row not found — state file does not exist for the given row name |
| 3 | Manifest not found — the path given to `--manifest` does not exist |
| 4 | Schema validation failed — manifest fails JSON Schema validation |
| 5 | Conflicting deliverable — entry already exists and `--replace` was not passed |
| 6 | Write error — atomic state.json write failed |

`--json` mode wraps all errors in the standard `envelope{ok: false, error: {...}}` shape with
`code` matching the table above (e.g., `"row_not_found"`, `"manifest_not_found"`, etc.).

### Atomicity contract

State mutations follow the same temp-file-rename pattern used by all row commands
(`writeJSONMapAtomic` in `internal/cli/util.go:72`):

1. Read current `state.json` into `map[string]any`.
2. Apply all manifest entries to the in-memory deliverables map.
3. Append a repair audit entry to `state["repair_audit"]` (see Audit Trail below).
4. Call `writeJSONMapAtomic(statePath, state)` — writes to `.state-*.tmp` in the same directory,
   then `os.Rename` to `state.json`. No partial writes are visible.

If any pre-write check fails (schema, conflict, missing row), the function returns before touching
state.json.

### Audit trail

The audit trail is a **sidecar JSONL file** at `.furrow/rows/<name>/repair-audit.jsonl`, NOT a field
inside `state.json`. This is locked by the row constraint "Manifest schema is additive — does not
modify state.schema.json": `state.schema.json` has `additionalProperties: false` at the top level
and forbids new fields, so `state.json.repair_audit` is not a permissible addition.

Each repair run appends one JSON object on a new line:

```json
{"timestamp":"<ISO 8601>","manifest":"<absolute path>","commit":"<commit from manifest>","decided_by":"manual","entries_added":["backend-work-loop-support","pi-work-command"],"entries_skipped":["validation-and-doc-drift"]}
```

`entries_skipped` lists names that were already present and `--replace` was not set (partial-repair
behavior — see AC 9). `entries_added` lists names that were written. The file is created on first
write; subsequent runs append a new line. The sidecar is owned by the row directory and is not
read by the harness for state-driven decisions; it exists purely for audit/forensic use.

### bin/rws shim

Insertion point: `bin/rws` after line 2954 (after the `diff)` case), before the `focus)` case.
Per research.md Topic 3 §Recommended shim pattern:

```sh
repair-deliverables)
  FURROW_BIN="${FURROW_BIN:-${FURROW_ROOT}/bin/furrow}"
  if [ ! -x "$FURROW_BIN" ]; then
    die "furrow binary not found at $FURROW_BIN; run 'go build ./cmd/furrow'"
  fi
  exec "$FURROW_BIN" row repair-deliverables "$@"
  ;;
```

Key invariants (per research.md Topic 3 §Anti-patterns to avoid):
- No validation or state reads in the shim.
- `exec` preserves exit codes.
- `FURROW_BIN` env var allows override for test environments.
- `FURROW_ROOT` is already set in the bin/rws execution context — verify the exact var name during
  implement.

This is the first shell-to-Go delegation shim in the codebase. Its shape is load-bearing for
future Phase 7 ports. Wave 3 adds the `repair-deliverables` case to the main `rws` case block;
wave 1 adds only the shim body function (if wave ordering requires it). The insert is strictly
additive — no existing cases are modified.

---

## Acceptance Criteria (Refined)

1. **Exit 0 on valid manifest**: `furrow row repair-deliverables <row> --manifest <path>` exits 0
   when the manifest passes schema validation, the row exists, it is archived (or `--force-active`
   is set), and no conflicting deliverables exist (or `--replace` is set). `state.json.deliverables`
   is updated and `repair_audit` (or `repair-audit.jsonl`) gains a new entry.

2. **Manifest schema enforces required fields**: The JSON Schema at
   `schemas/repair-deliverables-manifest.schema.json` marks `deliverables[].name`, `.status`,
   `.commit`, and `.evidence_paths` (array, minItems 1) as required. Each `evidence_paths` item
   requires `path`; `lines` and `note` are optional. Missing or wrong-type values cause a schema
   validation error; CLI exits 4 (schema validation failed) with a message naming the failing path.

3. **Atomic state update + audit entry**: `state.json` is written via `writeJSONMapAtomic`
   (temp-rename). A repair entry naming timestamp, commit, decided_by, entries_added, and
   entries_skipped is appended. No intermediate state is observable.

4. **Refuses non-archived row without --force-active**: When the target row has `archived_at: null`
   and `--force-active` is absent, CLI exits 1 with message: `"row <name> is not archived; pass
   --force-active to repair active rows"`.

5. **Refuses conflicting deliverable without --replace**: When a manifest entry names a deliverable
   that already exists in `state.json.deliverables`, CLI exits 5 with message: `"deliverable
   '<name>' already exists in row '<row>'; pass --replace to overwrite"`. Message names the
   specific conflicting deliverable.

6. **Schema documented at canonical path**: `schemas/repair-deliverables-manifest.schema.json`
   exists and is valid JSON Schema (draft 2020-12). It is the schema consumers reference; no
   other schema file duplicates its content.

7. **Unit tests cover required scenarios**: `internal/cli/row_repair_test.go` contains table-driven
   tests for: happy path, missing manifest file (exit 3), schema-invalid manifest (exit 4),
   conflicting deliverable without `--replace` (exit 5), non-existent row (exit 2). Additional
   coverage per spec inputs below.

8. **bin/rws shim is pure delegation**: The `repair-deliverables` case in `bin/rws` contains no
   validation logic, no state reads, no output transformation. Shim body matches the pattern in
   research.md Topic 3 §Recommended shim pattern exactly.

9. **Partial-repair semantics**: When a manifest mixes already-present and new deliverables, the
   CLI processes new entries and skips (does not error on) existing ones, UNLESS `--replace` is
   set for the entire operation. `entries_skipped` in the audit entry names all skipped
   deliverables. No error is raised for skipped entries. If `--replace` is set, all manifest
   entries overwrite regardless of prior existence.

10. **Empty manifest fails schema validation**: A manifest with `deliverables: []` (zero entries)
    is rejected with exit 4; `schemas/repair-deliverables-manifest.schema.json` enforces
    `"minItems": 1` on the `deliverables` array.

11. **Distinct exit codes for row-not-found vs manifest-not-found**: Row not found exits 2;
    manifest file not found exits 3. Both are distinguishable in `--json` mode via `error.code`
    (`"row_not_found"` vs `"manifest_not_found"`).

---

## Test Scenarios

### Scenario: Happy path — archived row, all new deliverables

- **Verifies**: AC 1, AC 3
- **WHEN**: Row `pi-step-ceremony-and-artifact-enforcement` exists with `archived_at` set;
  manifest at `/tmp/repair.yaml` contains 2 deliverables not present in `state.json.deliverables`.
- **THEN**: Exit 0; both deliverables appear in `state.json.deliverables`; repair audit entry
  lists both in `entries_added`, empty `entries_skipped`.
- **Verification**: `furrow row repair-deliverables pi-step-ceremony-and-artifact-enforcement --manifest /tmp/repair.yaml --json | jq '.ok'` → `true`; `jq '.deliverables | keys' .furrow/rows/pi-step-ceremony-and-artifact-enforcement/state.json` includes both names.

### Scenario: Missing manifest file

- **Verifies**: AC 11 (manifest-not-found exit 3)
- **WHEN**: `--manifest /nonexistent/path.yaml` path does not exist on disk.
- **THEN**: Exit 3; stderr message: `"manifest not found: /nonexistent/path.yaml"`.
- **Verification**: `furrow row repair-deliverables some-row --manifest /nonexistent/path.yaml; echo $?` → `3`.

### Scenario: Schema-invalid manifest

- **Verifies**: AC 2, AC 10 (exit 4 for validation failures)
- **WHEN**: Manifest file is valid YAML but missing required field `evidence_paths` on one entry (or `evidence_paths` is empty array).
- **THEN**: Exit 4; error message names the failing field path.
- **Verification**: `furrow row repair-deliverables some-row --manifest /tmp/bad.yaml; echo $?` → `4`.

### Scenario: Empty manifest (zero deliverables)

- **Verifies**: AC 10, spec input #7a
- **WHEN**: Manifest contains `deliverables: []`.
- **THEN**: Exit 4; schema validation rejects `minItems: 1` violation.
- **Verification**: `furrow row repair-deliverables some-row --manifest /tmp/empty.yaml; echo $?` → `4`.

### Scenario: Conflicting deliverable without --replace

- **Verifies**: AC 5
- **WHEN**: Manifest names deliverable `backend-work-loop-support` which already exists in
  `state.json.deliverables`.
- **THEN**: Exit 5; message: `"deliverable 'backend-work-loop-support' already exists in row
  'pi-step-ceremony-and-artifact-enforcement'; pass --replace to overwrite"`.
- **Verification**: `furrow row repair-deliverables pi-step-ceremony-and-artifact-enforcement --manifest /tmp/conflict.yaml; echo $?` → `5`.

### Scenario: Conflicting deliverable with --replace

- **Verifies**: AC 5 (allowed path), AC 1
- **WHEN**: Same as above but `--replace` flag is present.
- **THEN**: Exit 0; deliverable entry overwritten in `state.json`.
- **Verification**: `furrow row repair-deliverables pi-step-ceremony-and-artifact-enforcement --manifest /tmp/conflict.yaml --replace; echo $?` → `0`.

### Scenario: Non-existent row

- **Verifies**: AC 7, AC 11 (row-not-found exit 2)
- **WHEN**: `<row-name>` is `no-such-row`; state file does not exist.
- **THEN**: Exit 2; message: `"state file not found for row \"no-such-row\""`.
- **Verification**: `furrow row repair-deliverables no-such-row --manifest /tmp/repair.yaml; echo $?` → `2`.

### Scenario: Partial repair — mixed existing and new deliverables

- **Verifies**: AC 9, spec input #3
- **WHEN**: Manifest lists 3 deliverables; 1 already exists in state, 2 are new.
- **THEN**: Exit 0; 2 new entries added; 1 existing entry untouched and listed in
  `entries_skipped`; no error raised.
- **Verification**: After run, `tail -1 .furrow/rows/<row>/repair-audit.jsonl | jq '.entries_skipped'` contains the
  existing name; state has both pre-existing and 2 new deliverables.

### Scenario: Non-archived row without --force-active

- **Verifies**: AC 4
- **WHEN**: Row exists but `archived_at` is null; `--force-active` not passed.
- **THEN**: Exit 1; message names the row and the required flag.
- **Verification**: `furrow row repair-deliverables active-row --manifest /tmp/repair.yaml; echo $?` → `1`.

### Scenario: Non-archived row with --force-active

- **Verifies**: AC 4 (allowed path)
- **WHEN**: Row has `archived_at: null`; `--force-active` is present; manifest is valid; no
  conflicts.
- **THEN**: Exit 0; deliverables written.
- **Verification**: `furrow row repair-deliverables active-row --manifest /tmp/repair.yaml --force-active; echo $?` → `0`.

---

## Implementation Notes

### Pattern to follow

`runRowRepairDeliverables` in `internal/cli/row_repair.go` follows the same structure as
`runRowArchive` (`internal/cli/row.go:400-516`):

1. `parseArgs` for flags and positionals.
2. `findFurrowRoot()` → resolve state path via `statePathForRow(root, rowName)`.
3. `fileExists(statePath)` → exit 2 if missing.
4. `loadJSONMap(statePath)` → load current state.
5. Check `archived_at` → exit 1 unless `--force-active`.
6. Load and parse manifest (YAML via `gopkg.in/yaml.v3`, already in `go.mod`).
7. Schema-validate manifest in-process (see Schema Validation below).
8. Check each manifest entry against existing deliverables map → exit 5 on conflict if no
   `--replace`.
9. Apply entries to in-memory state.
10. Append audit entry.
11. `writeJSONMapAtomic(statePath, state)` → exit 6 on error.
12. Return 0.

### Atomic write pattern

Use `writeJSONMapAtomic` from `internal/cli/util.go:72`. This is the canonical pattern: write to
`.state-*.tmp` in the same directory, `os.Rename` to target. No bespoke temp logic.

### Schema validation

No external JSON Schema library is in `go.mod`. Implement manifest schema validation inline in Go
using the required-field checks and type assertions — do not add new external dependencies (per
constraint "No new external dependencies in Go code"). The JSON Schema file at
`schemas/repair-deliverables-manifest.schema.json` documents the schema for tooling and humans;
the Go code enforces it manually using the same field set.

Validation logic:
- Top-level: `version` (optional string), `decided_by` (optional, default `"manual"`),
  `commit` (optional string default), `deliverables` (required array, minItems 1).
- Per entry: `name` (required string, non-empty), `status` (required, one of
  `not_started|in_progress|completed|blocked`), `commit` (required string, non-empty),
  `evidence_paths` (required array, minItems 1). Each `evidence_paths` item is an object with
  `path` (required string, non-empty), `lines` (optional string), `note` (optional string).

### Error wrapping

`fmt.Errorf("repair-deliverables: %w", err)` per project Go convention.

### Manifest schema design

`schemas/repair-deliverables-manifest.schema.json` — draft 2020-12, matching existing schema
style (`learning.schema.json`, `state.schema.json`):

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "repair-deliverables-manifest.schema.json",
  "title": "Repair Deliverables Manifest",
  "type": "object",
  "required": ["deliverables"],
  "additionalProperties": false,
  "properties": {
    "version": { "type": "string" },
    "decided_by": { "type": "string", "default": "manual" },
    "commit": { "type": "string", "description": "Default commit for entries that omit commit" },
    "deliverables": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["name", "status", "commit", "evidence_paths"],
        "additionalProperties": false,
        "properties": {
          "name": { "type": "string", "minLength": 1 },
          "status": { "type": "string", "enum": ["not_started", "in_progress", "completed", "blocked"] },
          "commit": { "type": "string", "minLength": 1 },
          "evidence_paths": {
            "type": "array",
            "minItems": 1,
            "items": {
              "type": "object",
              "required": ["path"],
              "additionalProperties": false,
              "properties": {
                "path": { "type": "string", "minLength": 1 },
                "lines": { "type": "string" },
                "note": { "type": "string" }
              }
            }
          }
        }
      }
    }
  }
}
```

### Wave boundary note (spec input #4)

`app.go` and `bin/rws` are touched in wave 1 (this deliverable) and again in wave 3
(`pi-adapter-foundation-archive`). Wave 1 edits are strictly additive:
- `app.go`: one new `case "repair-deliverables":` line in `runRow()`.
- `bin/rws`: one new case block inserted after line 2954.

Wave 3 edits touch different switch cases (`archive`) and different functions (`rowBlockers`).
No conflicts. Implementer should note this in the wave 1 commit message.

---

## Dependencies

- `schemas/state.schema.json` — consumed (deliverables map shape drives the update target);
  not modified.
- `internal/cli/util.go:writeJSONMapAtomic` — atomic write helper; reused directly.
- `internal/cli/util.go:loadJSONMap`, `findFurrowRoot`, `statePathForRow`, `fileExists` —
  existing helpers reused.
- `gopkg.in/yaml.v3` — already in `go.mod`; used to parse YAML manifests.
- No new external dependencies.
- No `depends_on` other deliverables — this is the first deliverable in the row and has no
  predecessor.
