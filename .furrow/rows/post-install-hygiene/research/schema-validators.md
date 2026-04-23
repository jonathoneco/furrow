# Schema Validator Consolidation Research

## Section A — Draft2020-12Validator Pattern in validate-definition.sh

**File**: `bin/frw.d/scripts/validate-definition.sh` (lines 36–55)

### Exact Python Subprocess Invocation

```sh
schema_errors=$(python3 -c "
import json, sys
try:
    from jsonschema import Draft202012Validator
except ImportError:
    print('SKIP: jsonschema not installed (need >=4.0)', file=sys.stderr)
    sys.exit(0)
with open(sys.argv[1]) as f:
    schema = json.load(f)
with open(sys.argv[2]) as f:
    instance = json.load(f)
# Use Draft202012Validator to match schema's \$schema declaration
# (https://json-schema.org/draft/2020-12/schema). The older Draft 7 class
# silently ignores 2020-12 keywords like unevaluatedProperties.
validator = Draft202012Validator(schema)
errs = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
for e in errs:
    path = '.'.join(str(p) for p in e.absolute_path) or '(root)'
    print(f'Schema error at {path}: {e.message}')
" "$SCHEMA_FILE" "$json_tmp" 2>&1)
```

### Pattern Details
- **Invocation**: `python3 -c "<script>"` with schema and document as positional args (`sys.argv[1]`, `sys.argv[2]`)
- **Error handling**: Catches import failure gracefully (prints SKIP, exits 0)
- **Validator class**: `Draft202012Validator` from `jsonschema`
- **Error format**: `Schema error at <path>: <message>` per error, sorted by path
- **Failure**: captured in variable `schema_errors`, returned via stdout; non-empty string indicates validation failure
- **Exit code handling**: Python subprocess exits 0 regardless (error collection is in-band)

### Existing Helper Function?
**No**: There is no existing wrapper in `bin/frw.d/lib/`. The pattern appears only in `validate-definition.sh` (and in test file `tests/integration/test-validate-definition-draft.sh`). The deliverable calls for creating a shared helper `validate-json.sh` to consolidate this pattern.

---

## Section B — Inline jq Validation Block in generate-reintegration.sh

**File**: `bin/frw.d/scripts/generate-reintegration.sh` (lines 357–401)

### Inline jq Block (lines 358–396)

```sh
# --- validate against schema (jq-based) ---
_validate_result="$(printf '%s' "$_reint_json" | jq -r '
  def check_required(obj; fields):
    fields | map(
      if obj[.] == null then "missing:" + . else empty end
    ) | .[];

  def check_pattern(val; pat):
    if (val | type) != "string" then "not-string"
    elif (val | test(pat) | not) then "pattern-mismatch"
    else "ok"
    end;

  . as $doc |

  # Required top-level fields
  (check_required($doc; ["schema_version","row_name","branch","base_sha","head_sha","generated_at","commits","files_changed","decisions","open_items","test_results"]) // empty),

  # schema_version must be "1.0"
  (if $doc.schema_version != "1.0" then "invalid:schema_version" else empty end),

  # row_name pattern
  (if ($doc.row_name | type) == "string" and ($doc.row_name | test("^[a-z][a-z0-9]*(-[a-z0-9]+)*$") | not) then "pattern:row_name" else empty end),

  # branch pattern
  (if ($doc.branch | type) == "string" and ($doc.branch | test("^[A-Za-z0-9._/-]+$") | not) then "pattern:branch" else empty end),

  # sha patterns
  (if ($doc.base_sha | type) == "string" and ($doc.base_sha | test("^[0-9a-f]{7,40}$") | not) then "pattern:base_sha" else empty end),
  (if ($doc.head_sha | type) == "string" and ($doc.head_sha | test("^[0-9a-f]{7,40}$") | not) then "pattern:head_sha" else empty end),

  # commits array
  (if ($doc.commits | type) != "array" then "type:commits"
   elif ($doc.commits | length) == 0 then "empty:commits"
   else empty end),

  # test_results.pass is boolean
  (if ($doc.test_results.pass | type) != "boolean" then "type:test_results.pass" else empty end)

' 2>/dev/null)"

if [ -n "$_validate_result" ]; then
  printf 'generate-reintegration: schema validation failed: %s\n' "$_validate_result" >&2
  exit 3
fi
```

### What It Validates
- **Required fields**: `schema_version, row_name, branch, base_sha, head_sha, generated_at, commits, files_changed, decisions, open_items, test_results`
- **Enum/const**: `schema_version == "1.0"`
- **Pattern validation**: `row_name` (kebab-case), `branch` (git branch pattern), `base_sha`/`head_sha` (hex 7–40 chars)
- **Type checks**: `commits` is non-empty array, `test_results.pass` is boolean
- **Error reporting**: Emits short tokens (`missing:field`, `pattern:field`, `type:field`, `invalid:field`)

### What It Misses (cf. schema)
- **No `evidence_path` enforcement**: The schema defines `test_results.evidence_path` as optional (lines 222–225 in schema); the jq block does NOT validate it at all. When the schema makes `evidence_path` required, the jq validator will skip it.
- **No nested validation**: Does not validate `test_results.skipped` array type, commit object shapes (sha/subject/conventional_type/install_artifact_risk), files_changed shapes, decision/open_item/merge_hint structures.
- **No additionalProperties check**: Does not reject unexpected fields at root or nested levels.
- **No date-time format**: Does not validate `generated_at` ISO-8601 format.
- **Minimal enum validation**: Only checks `schema_version`; does not validate `install_artifact_risk` enum, decision/open_item boolean types, etc.

### Write Destination
**File**: `.furrow/rows/{name}/reintegration.json` (line 410)
- Written atomically: `_tmp_json="${REINT_JSON}.tmp.$$"` → `jq --sort-keys '.'` → `mv` (line 405)
- Path structure: `.furrow/rows/{ROW_NAME}/reintegration.json`

---

## Section C — reintegration.schema.json Shape

**File**: `schemas/reintegration.schema.json` (lines 7–19, 213–239)

### Top-Level `required` Array (lines 7–19)
```json
"required": [
  "schema_version",
  "row_name",
  "branch",
  "base_sha",
  "head_sha",
  "generated_at",
  "commits",
  "files_changed",
  "decisions",
  "open_items",
  "test_results"
],
```

### `test_results` Properties (lines 213–239)
```json
"test_results": {
  "type": "object",
  "required": ["pass"],
  "additionalProperties": false,
  "properties": {
    "pass": {
      "type": "boolean",
      "description": "True iff all tests passed at the time of generation."
    },
    "evidence_path": {
      "type": "string",
      "description": "Relative path under .furrow/rows/<name>/ to the review/test log."
    },
    "skipped": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Test names or categories skipped."
    }
  },
  "description": "Summary of test results from the most recent review record.",
  "examples": [
    {
      "pass": true,
      "evidence_path": "reviews/2026-04-22T19-00.md"
    }
  ]
}
```

### Current State of `evidence_path`
- **Currently OPTIONAL**: Not listed in `test_results.required` (only `pass` is required)
- **Type**: `string`
- **Deliverable requirement**: Task asks to add `test_results.evidence_path` to the schema's required fields, making it mandatory

---

## Section D — Archived Reintegration JSON Inventory (Back-Compat)

**Command**: `find .furrow/rows -name 'reintegration*.json' -type f`

### Result
**No files found**. The `.furrow/rows/` directory tree contains:
- 5 rows: `harness-v2-status-eval`, `review-impl-scripts`, `ideation-and-review-ux`, `post-ship-reexamination`, `install-and-merge`
- None have a `reintegration.json` file yet

### Inference
The back-compat migration (updating archived reintegration JSON to include the new required field `evidence_path`) is a **no-op** — there are no existing disk files to migrate. The schema change (making `evidence_path` required) will only apply to newly generated files.

---

## Section E — Learnings.jsonl Schema Audit

### Actual Field Set in `.furrow/rows/*/learnings.jsonl`

#### Sample 1: `install-and-merge/learnings.jsonl` (line 1)
```json
{"ts":"2026-04-22T17:40:00Z","step":"ideate","kind":"pitfall","summary":"FURROW_ROOT resolves...","detail":"...","tags":["self-hosting","validation","FURROW_ROOT"]}
```
**Fields**: `ts, step, kind, summary, detail, tags`

#### Sample 2: `harness-v2-status-eval/learnings.jsonl` (line 1)
```json
{"id":"harness-v2-status-eval-001","timestamp":"2026-04-02T08:17:18Z","category":"pitfall","content":"CC plan mode...","context":"Agent used CC...","source_task":"harness-v2-status-eval","source_step":"plan","promoted":false}
```
**Fields**: `id, timestamp, category, content, context, source_task, source_step, promoted`

#### Summary
- **5 learnings.jsonl files found**: `harness-v2-status-eval`, `review-impl-scripts`, `ideation-and-review-ux`, `post-ship-reexamination`, `install-and-merge`
- **Schema inconsistency detected**: Two different field sets are in use:
  - **Old format** (harness, review, ideation, post-ship): `id, timestamp, category, content, context, source_task, source_step, promoted`
  - **New format** (install-and-merge only): `ts, step, kind, summary, detail, tags`
- **NOT uniform**: All 5 rows are NOT using the same schema

### promote-learnings.sh Reading Wrong Fields

**File**: `commands/lib/promote-learnings.sh` (lines 49–53)

```sh
category="$(echo "${line}" | jq -r '.category')"
content="$(echo "${line}" | jq -r '.content')"
context="$(echo "${line}" | jq -r '.context')"
source_step="$(echo "${line}" | jq -r '.source_step')"
already_promoted="$(echo "${line}" | jq -r '.promoted')"
```

**Expected fields** (from code): `category, content, context, source_step, promoted`
**Actual fields** (from install-and-merge): `ts, step, kind, summary, detail, tags` (+ no `promoted` field)

**Exact mismatch**:
- Script reads `.category` → but newer rows use `.kind`
- Script reads `.content` → but newer rows use `.summary`
- Script reads `.context` → not present in newer rows
- Script reads `.source_step` → but newer rows use `.step`
- Script reads `.promoted` → not present in newer rows

The script **will silently fail** on install-and-merge learnings — all `jq` reads return `null`, producing empty strings, and the script treats them as skipped/unchanged.

### Learnings-Protocol Definition

**File**: `skills/shared/learnings-protocol.md` (lines 22–33)

```markdown
## Schema (JSONL)

Append one JSON object per line to `.furrow/rows/{name}/learnings.jsonl`:

\`\`\`json
{"id":"{task}-{NNN}","timestamp":"ISO8601","category":"pattern|pitfall|preference|convention|dependency","content":"actionable insight","context":"what surfaced it","source_task":"{name}","source_step":"{step}","promoted":false}
\`\`\`

- `id`: `{source_task}-{NNN}` (zero-padded 3-digit sequence)
- `content`: one concise paragraph, actionable (min 10 chars)
- `context`: situation that surfaced the insight (min 10 chars)
- `promoted`: always `false` when writing; set to `true` during archive
```

**Canonical schema** (per protocol):
- `id, timestamp, category, content, context, source_task, source_step, promoted`

**The newer install-and-merge format uses completely different field names** and is NOT documented in this protocol.

### Existing Learning-Write Hook?

**Search**: `bin/frw.d/hooks/` for learnings validation

**Result**: **No hook found**. Files present:
- `auto-install.sh`, `correction-limit.sh`, `gate-check.sh`, `ownership-warn.sh`, `post-compact.sh`, `pre-commit-bakfiles.sh`, `pre-commit-typechange.sh`, `script-guard.sh`, `state-guard.sh`, `stop-ideation.sh`, `validate-definition.sh`, `validate-summary.sh`, `verdict-guard.sh`, `work-check.sh`

No learnings-specific hook exists. The deliverable calls for **"add validator invocation on every learnings write"**.

---

## Sources Consulted

- `/home/jonco/src/furrow-post-install-hygiene/bin/frw.d/scripts/validate-definition.sh` (lines 36–55)
- `/home/jonco/src/furrow-post-install-hygiene/bin/frw.d/scripts/generate-reintegration.sh` (lines 357–401, 410)
- `/home/jonco/src/furrow-post-install-hygiene/schemas/reintegration.schema.json` (full)
- `/home/jonco/src/furrow-post-install-hygiene/commands/lib/promote-learnings.sh` (lines 49–53)
- `/home/jonco/src/furrow-post-install-hygiene/skills/shared/learnings-protocol.md` (lines 22–33)
- `/home/jonco/src/furrow-post-install-hygiene/.furrow/rows/*/learnings.jsonl` (5 files sampled)
- `/home/jonco/src/furrow-post-install-hygiene/bin/frw.d/hooks/` (directory listing)

