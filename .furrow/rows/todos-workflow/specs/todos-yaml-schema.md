# Spec: todos-yaml-schema

Deliverable from `.work/todos-workflow/definition.yaml`.

## Component

Structured TODO tracking via a `todos.yaml` file at the project root. Two artifacts:

1. A JSON Schema (Draft 2020-12, expressed in YAML) that defines the shape of `todos.yaml`.
2. A POSIX shell validation script that checks a `todos.yaml` file against the schema and cross-field rules.

## Files

| File | Purpose |
|------|---------|
| `adapters/shared/schemas/todos.schema.yaml` | JSON Schema for `todos.yaml` |
| `scripts/validate-todos.sh` | Validation script (schema + cross-field checks) |

## Schema Definition

**File:** `adapters/shared/schemas/todos.schema.yaml`

JSON Schema Draft 2020-12 expressed in YAML, following the pattern established by `definition.schema.yaml`.

```yaml
$schema: "https://json-schema.org/draft/2020-12/schema"
title: "TODO Entries"
description: "Schema for todos.yaml — structured TODO tracking"
type: array
items:
  type: object
  required:
    - id
    - title
    - context
    - work_needed
    - created_at
    - updated_at
  additionalProperties: false
  properties:
    id:
      type: string
      pattern: "^[a-z][a-z0-9]*(-[a-z0-9]+)*$"
      description: "Slug-style kebab-case identifier, unique across all entries"
    title:
      type: string
      minLength: 1
      description: "One-line summary of the TODO"
    context:
      type: string
      minLength: 1
      description: "Why this matters (multi-line prose)"
    work_needed:
      type: string
      minLength: 1
      description: "Concrete steps to resolve this (multi-line prose)"
    risks:
      type: string
      description: "What could fail or go wrong (optional, multi-line prose)"
    references:
      type: array
      items:
        type: string
        minLength: 1
      description: "File paths providing relevant context"
    source_work_unit:
      type: string
      description: "Name of the work unit that surfaced this TODO (optional)"
    source_type:
      type: string
      enum:
        - open-question
        - unpromoted-learning
        - review-finding
        - manual
      description: "How this TODO was extracted (optional)"
    created_at:
      type: string
      format: date-time
      description: "ISO 8601 timestamp with timezone"
    updated_at:
      type: string
      format: date-time
      description: "ISO 8601 timestamp with timezone"
```

### Schema design decisions

- **Top-level array** (not an object wrapping an array) keeps the file flat and easy to append to. Matches how `yq` handles list manipulation naturally.
- **`additionalProperties: false`** catches typos and enforces forward-compatibility through explicit schema evolution.
- **`id` pattern** reuses the same kebab-case regex as `definition.schema.yaml` deliverable names (`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`).
- **`source_type` enum** covers the three extraction sources (open-question, unpromoted-learning, review-finding) plus a manual entry path.
- **`risks` is a string, not an array** — free-form prose is more natural for risk descriptions and matches the `context` / `work_needed` fields.
- **`references` items require `minLength: 1`** to prevent empty-string entries.

## Validation Script Behavior

**File:** `scripts/validate-todos.sh`

Follows the pattern from `scripts/validate-definition.sh`: POSIX shell, graceful degradation, all-errors-before-exit.

### Interface

```
Usage: validate-todos.sh [path-to-todos.yaml]
  Default path: ./todos.yaml
  Exit 0: valid
  Exit 1: one or more errors (all reported to stderr)
```

### Validation pipeline

#### Step 1: Prerequisites check

- Verify the target file exists.
- Locate the schema file relative to the script (`$SCRIPT_DIR/../adapters/shared/schemas/todos.schema.yaml`). Since `validate-definition.sh` uses `$SCRIPT_DIR/../schemas/definition.schema.json`, and the new schema lives in `adapters/shared/schemas/`, resolve the path as: `$SCRIPT_DIR/../adapters/shared/schemas/todos.schema.yaml`.
- Warn and skip gracefully if `yq` or `python3` is not available.

#### Step 2: YAML syntax check

- Run `yq -o=json '.' "$TODOS_FILE"` and capture output to a temp file.
- If `yq` fails, record "Invalid YAML syntax" error and skip subsequent steps.

#### Step 3: JSON Schema validation

- Use `python3 -c` with the `jsonschema` module.
- Load the schema by converting from YAML (via `yq -o=json`) or by reading the YAML schema file with PyYAML. Preferred approach: convert schema YAML to JSON via `yq` into a second temp file, then pass both JSON files to the Python validator.
- Use `Draft202012Validator` (matching the schema's `$schema` declaration). Fall back to `Draft7Validator` if Draft202012 is not available in the installed jsonschema version.
- Iterate all errors and report each with its JSON path.
- If `jsonschema` is not installed, print a warning and skip (do not fail).

#### Step 4: Cross-field checks (via `yq`)

**Unique `id` check:**
- Extract all `.[].id` values via `yq`.
- Pipe through `sort | uniq -d` to find duplicates.
- Report each duplicate as an error.

No other cross-field checks are needed for this schema (unlike `definition.schema.yaml`, there are no dependency graphs or inter-field references).

#### Step 5: Report

- If any errors accumulated, print them all to stderr and exit 1.
- If clean, print `"todos.yaml is valid"` to stdout and exit 0.

### Error message format

Follow the existing convention from `validate-definition.sh`:

```
Schema error at [0].id: 'BAD_ID' does not match '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'
Duplicate TODO id: review-impl-edge-cases
```

### Temp file cleanup

Use `trap 'rm -f "$json_tmp" "$schema_tmp"' EXIT` to ensure cleanup on all exit paths.

## Acceptance Criteria

From `definition.yaml`:

1. **YAML schema for todos.yaml defined in `adapters/shared/schemas/`** -- the `todos.schema.yaml` file exists and is valid JSON Schema Draft 2020-12 expressed in YAML.
2. **Schema supports: id (slug), title, context, work_needed, risks, references (list of paths), source_work_unit (optional), created_at, updated_at** -- all fields present with correct types and constraints; required fields enforced; optional fields permitted but not required.
3. **Validation script exists and passes on current TODOS content migrated to YAML** -- `scripts/validate-todos.sh` exits 0 when run against a well-formed `todos.yaml` produced by the `migrate-existing-todos` deliverable.

### Verification commands

```sh
# Schema file exists and is valid YAML
yq '.' adapters/shared/schemas/todos.schema.yaml > /dev/null

# Validation script is executable
test -x scripts/validate-todos.sh

# Script passes on a valid todos.yaml
scripts/validate-todos.sh todos.yaml

# Script catches a bad file (should exit 1)
echo '- id: BAD ID' | scripts/validate-todos.sh /dev/stdin
```

## Edge Cases

### Empty file
- An empty `todos.yaml` (or one containing only `[]`) is a valid empty array. The script should accept it.

### Missing optional fields
- Entries without `risks`, `references`, `source_work_unit`, or `source_type` must validate successfully. Only the six required fields (`id`, `title`, `context`, `work_needed`, `created_at`, `updated_at`) are mandatory.

### Duplicate IDs
- The JSON Schema `uniqueItems` keyword compares entire objects, not individual fields. ID uniqueness must be enforced by the cross-field check in the shell script, not by the schema alone.

### Multiline strings
- `context`, `work_needed`, and `risks` are expected to contain multiline YAML (block scalars via `|` or `>`). The schema validates them as strings with no format constraint -- YAML block scalars are strings to JSON Schema.

### Missing tooling
- If `yq` is not installed: warn and exit 0 (cannot validate without it).
- If `python3` is not installed: warn, skip schema validation, still run cross-field checks via `yq`.
- If `jsonschema` Python module is not installed: warn, skip schema validation, still run cross-field checks.

### Schema file resolution
- The script resolves the schema path relative to its own location (`$SCRIPT_DIR`), not the working directory. This ensures it works when invoked from any directory.

### Extra properties
- `additionalProperties: false` in the schema means any unrecognized field in a TODO entry is a validation error. This is intentional -- schema evolution should be explicit. If a future deliverable needs new fields, the schema is updated first.

### Date-time format
- The `format: date-time` keyword in JSON Schema is an annotation by default. The `jsonschema` library does not enforce format unless `format_checker` is passed. The validation script should enable format checking if available (via `jsonschema.FormatChecker()`), but treat format check failures as warnings rather than hard errors to avoid a hard dependency on the `rfc3339-validator` or `strict-rfc3339` packages.
