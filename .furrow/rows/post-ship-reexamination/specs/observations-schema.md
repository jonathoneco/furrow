# Spec: observations-schema

## Interface Contract

**File**: `adapters/shared/schemas/observations.schema.yaml` — JSON Schema expressed in YAML, draft 2020-12, `additionalProperties: false`.

**Data file**: `.furrow/almanac/observations.yaml` — top-level array of observation objects. Initial content: `[]`.

**Consumer**: `alm validate` (extended in D2) reads the schema and validates the data file. `alm observe <verb>` (D2) reads/writes the data file; every write passes through the schema.

**Contract guarantees**:
- Schema enforces required fields per `kind` and per `triggered_by.type` via `allOf: [{if/then}]` pairs.
- Every `if` clause carries `required: [<discriminator>]` to prevent vacuous match.
- Unknown fields are rejected (`additionalProperties: false`).
- MVP rejects any `triggered_by.type` other than `row_archived`, `rows_since`, `manual`. `row_merged`, `after_date`, and other values MUST fail validation.

## Acceptance Criteria (Refined)

Shape the schema as a top-level `{$schema, title, description, type: array, items: {...}}`. The `items` schema must enforce:

**Common fields (required on every observation)**:
- `id` — string, pattern `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`.
- `kind` — enum `["watch", "decision-review"]`.
- `title` — string, minLength 1.
- `triggered_by` — object (discriminated union, see below).
- `lifecycle` — enum `["open", "resolved", "dismissed"]`.
- `created_at` — string, format `date-time`.
- `updated_at` — string, format `date-time`.

**Optional common fields**:
- `source_work_unit` — string. Matches the id pattern.
- `manual_activation_at` — string, format `date-time`. Only meaningful when `triggered_by.type == manual`; do NOT enforce conditional presence (implementation convention only).

**`kind: watch` additional required fields**:
- `signal` — string, minLength 1. What to observe.

**`kind: watch` additional optional fields**:
- `resolution` — object `{outcome: enum [pass, fail, inconclusive], resolved_at: date-time, note?: string}`, required when `lifecycle == resolved`, but the schema does NOT cross-enforce `lifecycle ↔ resolution` (D2 CLI enforces; schema tolerates pre-existing data).
- `dismissal` — object `{reason?: string, dismissed_at: date-time}`, populated when `lifecycle == dismissed` (same non-cross-enforcement convention).

**`kind: decision-review` additional required fields**:
- `question` — string, minLength 1.
- `options` — array (minItems 2) of objects `{id: string (id pattern), label: string (minLength 1)}`.
- `acceptance_criteria` — string, minLength 1 (prose description of how to decide).

**`kind: decision-review` additional optional fields**:
- `evidence_needed` — array of strings, each minLength 1.
- `resolution` — object `{option_id: string, rationale: string, resolved_at: date-time}`, populated when `lifecycle == resolved`.
- `dismissal` — same as watch.

**`triggered_by` discriminated union**:

```yaml
triggered_by:
  type: object
  additionalProperties: false
  required: [type]
  properties:
    type:
      type: string
      enum: [row_archived, rows_since, manual]
    row:
      type: string
      pattern: "^[a-z][a-z0-9]*(-[a-z0-9]+)*$"
    since_row:
      type: string
      pattern: "^[a-z][a-z0-9]*(-[a-z0-9]+)*$"
    count:
      type: integer
      minimum: 1
  allOf:
    - if: {properties: {type: {const: row_archived}}, required: [type]}
      then: {required: [type, row]}
    - if: {properties: {type: {const: rows_since}}, required: [type]}
      then: {required: [type, since_row, count]}
    - if: {properties: {type: {const: manual}}, required: [type]}
      then: {required: [type]}
```

**`kind` discriminated union** at observation level: same pattern — `allOf` of `if/then` pairs on `kind`, each branch adds its required fields.

**Validation tests**:
- Empty list `[]` validates.
- Minimal watch (`id`, `kind: watch`, `title`, `signal`, `triggered_by: {type: manual}`, `lifecycle: open`, timestamps) validates.
- Minimal decision-review (same common + `question`, `options`, `acceptance_criteria`) validates.
- `triggered_by.type: row_merged` FAILS validation.
- `triggered_by.type: rows_since` missing `count` FAILS validation.
- `kind: watch` missing `signal` FAILS validation.
- `kind: decision-review` missing `question` FAILS validation.
- Unknown top-level field (e.g., `priority: high`) FAILS validation.

## Test Scenarios

### Scenario: empty-file-valid
- **Verifies**: initial `[]` content of observations.yaml validates
- **WHEN**: `.furrow/almanac/observations.yaml` contains literally `[]`
- **THEN**: `alm validate` (after D2 extension) exits 0
- **Verification**: `printf '[]\n' > .furrow/almanac/observations.yaml && alm validate`

### Scenario: watch-minimal-valid
- **Verifies**: common + watch-specific required fields
- **WHEN**: observations.yaml contains one watch with `id`, `kind: watch`, `title`, `signal`, `triggered_by: {type: manual}`, `lifecycle: open`, timestamps
- **THEN**: validates clean
- **Verification**: `alm validate` exits 0

### Scenario: decision-review-minimal-valid
- **Verifies**: common + decision-review-specific required fields
- **WHEN**: observations.yaml contains one decision-review with `id`, `kind: decision-review`, `title`, `question`, `options` (≥2 entries), `acceptance_criteria`, `triggered_by: {type: rows_since, since_row: X, count: 3}`, `lifecycle: open`, timestamps
- **THEN**: validates clean
- **Verification**: `alm validate` exits 0

### Scenario: reject-row-merged-trigger
- **Verifies**: MVP trigger enum exclusion
- **WHEN**: an entry has `triggered_by: {type: row_merged, row: X}`
- **THEN**: validation FAILS with an enum error on `triggered_by.type`
- **Verification**: `alm validate` exits non-zero; stderr mentions `row_merged` or enum values

### Scenario: reject-rows-since-missing-count
- **Verifies**: discriminated-union required fields
- **WHEN**: an entry has `triggered_by: {type: rows_since, since_row: X}` (no count)
- **THEN**: validation FAILS pointing at missing `count`
- **Verification**: `alm validate` exits non-zero; stderr mentions `count`

### Scenario: reject-watch-missing-signal
- **Verifies**: kind-discriminated required fields
- **WHEN**: an entry has `kind: watch` but no `signal`
- **THEN**: validation FAILS pointing at missing `signal`
- **Verification**: `alm validate` exits non-zero; stderr mentions `signal`

### Scenario: reject-unknown-field
- **Verifies**: additionalProperties: false at root level
- **WHEN**: an entry has a field like `priority: high`
- **THEN**: validation FAILS
- **Verification**: `alm validate` exits non-zero; stderr mentions `priority` or "Additional properties"

## Implementation Notes

**Reference AD-1** (team-plan.md). Copy the `$schema`, top-level `title`/`description`, and YAML-JSON-Schema style from `adapters/shared/schemas/todos.schema.yaml`. Key gotcha: **every `if` clause must include `required: [<discriminator>]`** — omitting it causes vacuous match and wrong-branch firing (primary-source verified via JSON Schema draft 2020-12 docs; see `research/discriminator-idiom.md`).

Do NOT cross-enforce `lifecycle ↔ resolution` / `lifecycle ↔ dismissal` in the schema. The CLI (D2) enforces these at write-time; the schema must tolerate arbitrary pre-existing files (e.g., observations with `lifecycle: resolved` but no `resolution` field should still validate — the invariant is a D2 concern, not a schema concern). Rationale: keeps schema simple and avoids shifting the validation contract if D2 evolves.

## Dependencies

- None outbound (D1 is the root of the dependency graph).
- Inbound: D2 depends on this schema being in place before extending `alm validate`.
