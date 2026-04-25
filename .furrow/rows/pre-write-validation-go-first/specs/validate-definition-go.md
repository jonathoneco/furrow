# Spec: validate-definition-go (D1, wave 2)

## Interface Contract

### CLI

```
furrow validate definition --path <file> [--json]
```

Exit codes:
- `0` — definition.yaml is valid
- `3` — validation failure (one or more errors); errors emitted as JSON envelope on stdout when `--json`, human-readable on stderr otherwise
- `1` — usage error (missing --path, file not found, etc.)

### JSON output (with `--json`)

On success:
```json
{ "ok": true, "verdict": "valid" }
```

On validation failure:
```json
{
  "ok": false,
  "verdict": "invalid",
  "errors": [
    {
      "code": "definition_objective_missing",
      "category": "definition",
      "severity": "block",
      "message": "/path/to/definition.yaml: missing required field 'objective'",
      "remediation_hint": "...",
      "confirmation_path": "block"
    }
  ]
}
```

Each `errors[]` entry conforms to `BlockerEnvelope` from D3.

### Files

- `internal/cli/validate_definition.go` — implementation of the validator + CLI handler.
- `internal/cli/validate_definition_test.go` — table-driven unit tests.
- `internal/cli/app.go` — registers the `validate` command group and the `definition` subcommand.
- `bin/frw.d/scripts/validate-definition.sh` — rewritten as a thin shim that exec-delegates to `furrow validate definition`.
- `tests/integration/test-validate-definition-shim.sh` — integration test proving the shim continues to satisfy existing callers.

## Acceptance Criteria (Refined)

1. Running `furrow validate definition --path .furrow/rows/<some-row>/definition.yaml --json` exits 0 and emits `{"ok":true,"verdict":"valid"}` on a known-good file.
2. Running on a known-bad file (e.g., missing objective) exits 3 and emits a JSON envelope with `errors[]` containing exactly the expected codes.
3. Validator detects and emits codes for: missing objective; gate_policy missing; gate_policy not in `[supervised, delegated, autonomous]`; mode set but not in `[code, research]`; deliverables array missing or empty; deliverable name missing; deliverable name not matching kebab-case pattern; placeholder text in any acceptance_criterion (case-insensitive `"todo"`, `"tbd"`, `"placeholder"`, `"xxx"`); schema-invalid YAML (parse error → `definition_yaml_invalid`); unknown top-level keys (additionalProperties:false from schemas/definition.schema.json → `definition_unknown_keys`).
4. Every error code emitted matches an entry in `schemas/blocker-taxonomy.yaml`. Unit test confirms via direct iteration.
5. `internal/cli/app.go` registers the `validate` command group exactly once (subsequent registrations from D2 add subcommands, do not re-register the group).
6. `bin/frw.d/scripts/validate-definition.sh` after rewrite contains zero validation logic; it executes `exec furrow validate definition --path "$1"` (or equivalent) and propagates the exit code.
7. `tests/integration/test-validate-definition-shim.sh` exercises (a) `frw validate-definition <valid.yaml>` exits 0 and (b) `frw validate-definition <invalid.yaml>` exits non-zero. The test runs as part of `frw run-integration-tests` and passes.
8. `go test ./...` passes including new unit tests.

## Test Scenarios

### Scenario: happy-path-valid-definition
- **Verifies**: AC #1, #4
- **WHEN**: invoke `furrow validate definition --path testdata/valid_definition.yaml --json`
- **THEN**: stdout matches `{"ok":true,"verdict":"valid"}`; exit code 0
- **Verification**: `go test ./internal/cli/ -run TestValidateDefinitionHappyPath -v`

### Scenario: missing-objective
- **Verifies**: AC #2, #3
- **WHEN**: invoke against fixture with missing `objective` field
- **THEN**: exit 3; JSON envelope errors[0].code == `"definition_objective_missing"`
- **Verification**: `go test ./internal/cli/ -run TestValidateDefinitionMissingObjective -v`

### Scenario: invalid-gate-policy-enum
- **Verifies**: AC #3
- **WHEN**: fixture with `gate_policy: foo`
- **THEN**: exit 3; errors[].code == `"definition_gate_policy_invalid"`; message includes `"foo"` and the valid enum values
- **Verification**: `go test ./internal/cli/ -run TestValidateDefinitionInvalidGatePolicy -v`

### Scenario: bad-deliverable-name-pattern
- **Verifies**: AC #3
- **WHEN**: fixture with deliverable name `"Bad_Name"` (mixed case + underscore)
- **THEN**: exit 3; errors[].code == `"definition_deliverable_name_invalid_pattern"`
- **Verification**: `go test ./internal/cli/ -run TestValidateDefinitionBadNamePattern -v`

### Scenario: placeholder-acceptance-criterion
- **Verifies**: AC #3
- **WHEN**: fixture with `acceptance_criteria: ["TODO: write me"]`
- **THEN**: exit 3; errors[].code == `"definition_acceptance_criteria_placeholder"`
- **Verification**: `go test ./internal/cli/ -run TestValidateDefinitionPlaceholderAC -v`

### Scenario: unknown-top-level-key
- **Verifies**: AC #3
- **WHEN**: fixture with extra top-level key `extra_field: foo`
- **THEN**: exit 3; errors[].code == `"definition_unknown_keys"`; message names `extra_field`
- **Verification**: `go test ./internal/cli/ -run TestValidateDefinitionUnknownKey -v`

### Scenario: shim-continuity-happy-path
- **Verifies**: AC #6, #7
- **WHEN**: `frw validate-definition path/to/valid.yaml` invoked through the existing dispatch
- **THEN**: exit 0; stderr empty (or just the existing shim banner)
- **Verification**: `tests/integration/test-validate-definition-shim.sh` runs the command and asserts exit code

### Scenario: shim-continuity-invalid
- **Verifies**: AC #6, #7
- **WHEN**: `frw validate-definition path/to/invalid.yaml`
- **THEN**: exit code non-zero matching prior shell-based behavior (3 for validation failure)
- **Verification**: same test, asserts non-zero exit and presence of error codes in output

## Coverage scope (amended at review step)

The original AC said "full validation against schemas/definition.schema.json including additionalProperties:false enforcement." After 7 cross-model review rounds, the validator now covers:

- All top-level required fields + types
- All deliverable-item nested rules (name pattern, AC required+minItems+placeholder+type, gate enum, file_ownership/depends_on type-of-strings, additionalProperties:false)
- All context_pointers nested rules (path/note required, symbols type-of-strings, additionalProperties:false)
- constraints (required + array-of-strings)
- source_todos (optional array-of-strings, minItems:1, slugPattern, uniqueItems)
- supersedes (optional, required commit + row, row slug pattern, additionalProperties:false)
- Malformed YAML detection
- Top-level additionalProperties:false

**Known limitation**: hand-coded JSON Schema validation cannot prove parity with the schema declaration; each validator branch is manually authored. The reviewer surfaced 2-4 new nested rules per round across 7 rounds. Pursuing 100% schema parity hit diminishing returns: the empirical pain (validate-definition timing, ownership-warn timing) was closed in the first ~100 lines; rounds 2-7 covered edge cases no agent realistically violates (gate=0 rows usage, supersedes=1 row, etc.).

**Scope this AC to**: the rules that empirically prevent agent error categories observed in research §8 — objective/gate_policy/mode/deliverables/AC-placeholder/unknown-keys + their nested type/pattern/array equivalents. Full schema parity is deferred to the `sweeping-schema-audit-and-shrink` follow-up todo, which addresses the root cause (schema breadth) rather than chasing individual rules.

## Implementation Notes

- Reuse `gopkg.in/yaml.v3` for parsing; reuse `internal/cli/util.go` helpers if any exist for schema validation.
- For schema validation: go.mod confirms only `gopkg.in/yaml.v3` is vendored (no JSON Schema library). Per the no-new-deps constraint, validation is hand-coded — D1 reads `schemas/definition.schema.json` and walks its own `properties`/`required`/`additionalProperties` fields to drive validation. Specifically: parse the schema as `map[string]any`, extract the top-level required[] array and the properties{} keys; reject input top-level keys not in properties (emits `definition_unknown_keys` since `additionalProperties: false` is set in the schema); reject missing keys from required[]. Same pattern recurses for `deliverables[]` items.
- Each validation function returns `[]string` of error codes; the CLI handler aggregates and emits via D3's `taxonomy.EmitBlocker(code, interp)`.
- Schema validation runs first; if YAML parse fails, emit `definition_yaml_invalid` and skip semantic validation.
- Unknown-key detection: if the validator sees keys not in the schema's `properties`, emit `definition_unknown_keys` with the key list interpolated.

## Dependencies

- D3 (blocker-taxonomy-schema): D1 imports `Taxonomy` and `EmitBlocker` from `internal/cli/blocker_envelope.go`. Hard dependency; D1 cannot ship before D3.
- `schemas/definition.schema.json` (existing): primary structural source.
- `bin/frw.d/scripts/validate-definition.sh` (existing): shell semantics that D1 ports to Go (then rewrites the shell as a shim).
