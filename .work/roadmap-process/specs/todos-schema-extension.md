# Spec: todos-schema-extension

## Interface Contract
- **Input**: Existing `adapters/shared/schemas/todos.schema.yaml`
- **Output**: Extended schema with 7 new optional properties
- **Validation**: `scripts/validate-todos.sh` passes on current `todos.yaml` unchanged

## Changes

Add these properties inside the `items.properties` object (after `source_type`):

```yaml
depends_on:
  type: array
  items:
    type: string
    pattern: "^[a-z][a-z0-9]*(-[a-z0-9]+)*$"
  description: "IDs of TODOs this depends on (populated by /work-roadmap triage)"

files_touched:
  type: array
  items:
    type: string
    minLength: 1
  description: "File glob patterns this TODO would modify (for conflict detection)"

urgency:
  type: string
  enum:
    - critical
    - high
    - medium
    - low
  description: "How time-sensitive (populated by /work-roadmap triage)"

impact:
  type: string
  enum:
    - high
    - medium
    - low
  description: "How many other items this unblocks (populated by /work-roadmap triage)"

effort:
  type: string
  enum:
    - small
    - medium
    - large
  description: "Estimated implementation effort (populated by /work-roadmap triage)"

phase:
  type: integer
  minimum: 0
  description: "Phase number assigned by /work-roadmap (0-indexed)"

status:
  type: string
  enum:
    - active
    - done
    - blocked
    - deferred
  description: "Current status (lightweight, replaced by task tracker long-term)"
```

## Acceptance Criteria
1. All 7 fields added as optional properties in the schema
2. `depends_on` items use kebab-case ID pattern matching existing `id` field pattern
3. Running `scripts/validate-todos.sh` on current `todos.yaml` exits 0 (no breakage)
4. Running `scripts/validate-todos.sh` on a todos.yaml with the new fields populated also exits 0

## Implementation Notes
- Single file change: `adapters/shared/schemas/todos.schema.yaml`
- No JSON schema copy exists for todos (unlike definition) — only YAML source
- `additionalProperties: false` is set, so fields MUST be in properties or validation rejects
