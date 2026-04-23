# Spec: reintegration-schema-consolidation

**Wave**: 2
**Specialist**: harness-engineer
**Depends on**: test-isolation-guard

## Interface Contract

### New shared helper: `bin/frw.d/lib/validate-json.sh`
Exposes a single function used by any script needing Draft 2020-12 JSON
Schema validation:

```sh
# validate_json <schema_path> <doc_path>
# Returns 0 on valid, non-zero on invalid. Validation errors printed to
# stderr in the form:
#   Schema error at <path>: <message>
# If jsonschema>=4.0 is not installed, prints
#   SKIP: jsonschema not installed (need >=4.0)
# to stderr and returns 0 (matches existing behavior in
# validate-definition.sh).
validate_json() { ... }
```

**Source pattern**: Extract from
`bin/frw.d/scripts/validate-definition.sh:36-55` (per research
`schema-validators.md` Section A — NOT from
`get-reintegration-json.sh`, which does not yet contain this pattern).
The extraction is verbatim: `python3 -c '<script>'` invoking
`Draft202012Validator.iter_errors`, with errors sorted by path and
printed to stderr.

**Callers** after this deliverable lands:
- `bin/frw.d/scripts/validate-definition.sh` (switches from inline
  heredoc to `. validate-json.sh; validate_json "$SCHEMA_FILE" "$json_tmp"`).
- `bin/frw.d/scripts/generate-reintegration.sh` (replaces the inline
  `jq` block at lines ~357-396).
- `bin/frw.d/scripts/get-reintegration-json.sh` (already validates;
  switches to the shared helper for consistency).

### `generate-reintegration.sh` rewrite
Replace the inline jq block (lines 357-396 per research Section B) with
a single call to `validate_json`:

```sh
. "$FURROW_ROOT/bin/frw.d/lib/validate-json.sh"
if ! validate_json "$FURROW_ROOT/schemas/reintegration.schema.json" "$_tmp_json"; then
  printf 'generate-reintegration: schema validation failed\n' >&2
  exit 3
fi
```

The preserved contract: non-zero exit (code 3) on invalid output, with
validator errors on stderr. Atomic-write pattern (temp file → `jq
--sort-keys '.'` → `mv`) at line 405 is unchanged.

### `schemas/reintegration.schema.json` additive change
Extend `test_results.required` from `["pass"]` to
`["pass", "evidence_path"]`. All other schema fields, types, and
`additionalProperties` rules stay identical (research Section C quotes
the current shape — only the required array grows).

### Migration script:
`bin/frw.d/scripts/migrate-reintegration-evidence-path.sh`
Forward-looking per AD-6. Contract:
- **Usage**: `migrate-reintegration-evidence-path.sh <reintegration.json>`
- **Behavior**: Reads the JSON; if `test_results.evidence_path` is
  absent, sets it to the conventional default
  `reviews/pre-migration-unknown.md`; validates the result against the
  updated schema; writes atomically (temp + mv).
- **Idempotent**: Running twice on the same file is a no-op (second run
  detects the field already present).
- **Exit codes**: 0 on success (including no-op); 1 on schema failure
  after migration; 2 on I/O error.

Research `schema-validators.md` Section D confirmed
`find .furrow/rows -name 'reintegration*.json'` returns empty today, so
the live migration is a no-op. The script is authored and tested for
insurance against in-flight rows landing pre-migration JSON.

## Acceptance Criteria (Refined)

1. **Shared helper exists and is sourced** — File
   `bin/frw.d/lib/validate-json.sh` defines `validate_json` with the
   signature documented above. `grep -n "validate_json " bin/frw.d/scripts/generate-reintegration.sh`
   returns a non-empty match.
2. **Inline jq validator removed from generate-reintegration.sh** —
   Lines 357-396 in the post-commit file no longer contain the
   `check_required`, `check_pattern`, or `test_results.pass | type`
   jq expressions. Diff shows the block replaced by a single
   `validate_json` invocation.
3. **Schema requires `evidence_path`** — `jq
   '.properties.test_results.required' schemas/reintegration.schema.json`
   returns `["pass", "evidence_path"]` (order-insensitive). Current schema
   shape (verified at spec time) is:
   ```json
   "test_results": { "type": "object", "required": ["pass"], ... }
   ```
   Under `.properties` (not `.items` or `.$defs`); the jq path above is
   unambiguous. The edit appends `"evidence_path"` to the `required` array.
4. **Invalid generator output fails loudly** — Feeding
   `generate-reintegration.sh` a git state that would produce JSON
   missing a required field causes it to exit non-zero with the
   validator's `Schema error at <path>: <message>` on stderr.
5. **Valid round-trip preserved** — A clean generator run produces
   JSON that validates against the schema AND is accepted unchanged by
   `get-reintegration-json.sh`.
6. **Migration script is idempotent and tested** — Running the
   migration against a synthetic pre-migration archived file (no
   `evidence_path`) produces a schema-valid output on first run and a
   no-op on second. Running against a malformed (unfixable) file exits
   1 with the validator error.
7. **Regression test
   `tests/integration/test-reintegration-schema.sh`** — Covers AC-4 and
   AC-5. Uses `setup_sandbox`.
8. **Regression test
   `tests/integration/test-reintegration-backcompat.sh`** — Constructs
   a synthetic pre-migration file in a sandbox fixture, runs the
   migration, asserts schema validity and idempotence. Uses
   `setup_sandbox`.

## Test Scenarios

### Scenario: invalid generator output exits non-zero with validator message
- **Verifies**: AC-4, AC-7
- **WHEN**: `setup_sandbox` creates a fixture row with an empty
  `commits` array forced via mocked `git log`, then
  `generate-reintegration.sh` runs.
- **THEN**: Script exits 3; stderr contains
  `Schema error at commits: [] is too short` (or equivalent
  Draft2020-12 message); no output file is written atomically
  committed.
- **Verification**:
  ```sh
  setup_sandbox
  # mock git log to return empty commit set for the fixture range
  ! generate-reintegration.sh fixture-row 2>err.txt
  grep -q "Schema error at" err.txt
  test ! -f ".furrow/rows/fixture-row/reintegration.json"
  ```

### Scenario: valid output round-trips through get-reintegration-json
- **Verifies**: AC-5, AC-7
- **WHEN**: A well-formed fixture row generates its reintegration.json
  and then `get-reintegration-json.sh` is invoked on the same row.
- **THEN**: First call exits 0; second call exits 0 and stdout is
  byte-identical to the written file (after jq `--sort-keys`
  normalization).
- **Verification**:
  ```sh
  setup_sandbox
  generate-reintegration.sh fixture-row
  diff -q <(jq -S '.' .furrow/rows/fixture-row/reintegration.json) \
          <(get-reintegration-json.sh fixture-row | jq -S '.')
  ```

### Scenario: migration script makes pre-migration file schema-valid
- **Verifies**: AC-6, AC-8
- **WHEN**: A synthetic archived file is constructed under the sandbox
  with all required fields EXCEPT `evidence_path`, then
  `migrate-reintegration-evidence-path.sh <file>` is run twice.
- **THEN**: First run exits 0, file now contains
  `test_results.evidence_path`, file validates against the updated
  schema. Second run exits 0 with stderr noting "already migrated" and
  no file change (idempotent).
- **Verification**:
  ```sh
  setup_sandbox
  # synthesize file missing evidence_path
  jq 'del(.test_results.evidence_path)' fixtures/valid-reintegration.json \
    > "$TMP/fixture/reintegration.json"
  migrate-reintegration-evidence-path.sh "$TMP/fixture/reintegration.json"
  validate_json schemas/reintegration.schema.json "$TMP/fixture/reintegration.json"
  before=$(sha256sum "$TMP/fixture/reintegration.json")
  migrate-reintegration-evidence-path.sh "$TMP/fixture/reintegration.json"
  after=$(sha256sum "$TMP/fixture/reintegration.json")
  test "$before" = "$after"
  ```

## Implementation Notes

- **Source pattern correction**: The research artifact clarifies the
  Python subprocess pattern lives in `validate-definition.sh:36-55`
  (research Section A), not `get-reintegration-json.sh`. The extraction
  MUST cite `validate-definition.sh` as the source to avoid confusion
  with the originally-stated location in the row's decompose notes.
- **Error format**: Preserve the `Schema error at <path>: <message>`
  format verbatim (research Section A). Downstream log parsers may
  depend on this shape; changing it is out of scope.
- **Missing coverage in old jq block**: the inline jq validator did
  NOT enforce `evidence_path`, `commits[]` shapes, enum values, or
  `additionalProperties` (research Section B). Moving to the Python
  validator picks these up for free — this is intended and blessed by
  constraint #6 ("Schemas are authoritative; inline jq subsets are
  forbidden").
- **`jsonschema>=4.0` gracefully missing**: the extracted helper keeps
  the `SKIP: jsonschema not installed` path. This preserves CI
  tolerance on systems lacking the library (documented in
  `validate-definition.sh`).
- **Migration script pattern**: follow AD-6 — script exists and is
  tested, but today's `find .furrow/rows -name 'reintegration*.json'`
  returns empty so no live rows are touched. The test constructs a
  synthetic pre-migration file in the sandbox.
- **Atomic write**: preserve the temp → `jq --sort-keys '.'` → `mv`
  pattern from `generate-reintegration.sh:405`. Do not introduce a new
  atomic-write helper.
- **Sandbox**: every new test uses `setup_sandbox` from
  test-isolation-guard (constraint #4).

## Dependencies

- **Wave-1 prereq**: `test-isolation-guard` — `setup_sandbox`.
- **Existing validator source**: `bin/frw.d/scripts/validate-definition.sh`
  lines 36-55 — extracted, not mutated (the extracted function is
  sourced back in).
- **Existing consumer**:
  `bin/frw.d/scripts/get-reintegration-json.sh` — switched to the new
  helper for consistency.
- **Existing schema**: `schemas/reintegration.schema.json` — additively
  extended (required array only).
- **Python `jsonschema>=4.0`**: same runtime dep already assumed by
  `validate-definition.sh`; no new dependency.
- **No coupling to other wave-2 deliverables**: file ownership is
  disjoint from `script-modes-fix`, `xdg-config-consumer-wiring`,
  `promote-learnings-schema-fix`, `specialist-symlink-unification`,
  and `ac-10-e2e-fixture` per the plan's ownership analysis.
