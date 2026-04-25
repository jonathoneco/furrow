# Spec: blocker-taxonomy-schema (D3, wave 1)

## Interface Contract

### YAML schema file: `schemas/blocker-taxonomy.yaml`

Top-level structure:
```yaml
version: "1"
blockers:
  - code: "definition_yaml_invalid"
    category: "definition"
    severity: "block"
    message_template: "{path}: definition.yaml failed schema validation: {detail}"
    remediation_hint: "Run frw validate-definition <path> for the full validation error list"
    confirmation_path: "block"
    applicable_steps: []   # empty array = all steps
  # ...
```

Required fields per blocker entry: `code`, `category`, `severity`, `message_template`, `remediation_hint`, `confirmation_path`. Optional: `applicable_steps` (defaults to all steps when omitted; explicit `[]` is equivalent).

### JSON Schema file: `schemas/blocker-taxonomy.schema.json`

JSON Schema draft 2020-12 mirroring the YAML structure with `additionalProperties: false` at all levels. `severity` enum: `["block", "warn", "info"]`. `confirmation_path` enum: `["block", "warn-with-confirm", "silent"]`. `code` pattern: `^[a-z][a-z0-9_]*$`. `blockers[].code` uniqueness enforced via `uniqueItems` semantics (validated separately if JSON Schema doesn't directly support cross-item uniqueness).

### Go module: `internal/cli/blocker_envelope.go`

```go
package cli

type Blocker struct {
    Code             string   `yaml:"code" json:"code"`
    Category         string   `yaml:"category" json:"category"`
    Severity         string   `yaml:"severity" json:"severity"`           // "block" | "warn" | "info"
    MessageTemplate  string   `yaml:"message_template" json:"message_template"`
    RemediationHint  string   `yaml:"remediation_hint" json:"remediation_hint"`
    ConfirmationPath string   `yaml:"confirmation_path" json:"confirmation_path"`
    ApplicableSteps  []string `yaml:"applicable_steps,omitempty" json:"applicable_steps,omitempty"`
}

type Taxonomy struct {
    Version  string    `yaml:"version" json:"version"`
    Blockers []Blocker `yaml:"blockers" json:"blockers"`
}

// LoadTaxonomy reads and parses schemas/blocker-taxonomy.yaml relative to the project root.
func LoadTaxonomy() (*Taxonomy, error)

// EmitBlocker resolves the code in the loaded taxonomy, interpolates {placeholders} from interp,
// and returns the JSON envelope. Panics in test mode (testing.Testing()) if the code is unregistered.
func (t *Taxonomy) EmitBlocker(code string, interp map[string]string) BlockerEnvelope

type BlockerEnvelope struct {
    Code             string `json:"code"`
    Category         string `json:"category"`
    Severity         string `json:"severity"`
    Message          string `json:"message"`
    RemediationHint  string `json:"remediation_hint"`
    ConfirmationPath string `json:"confirmation_path"`
}
```

## Acceptance Criteria (Refined)

1. `schemas/blocker-taxonomy.yaml` exists, version: "1", with exactly the 11 initial codes listed below (10 from D1 + 1 from D2).
2. `schemas/blocker-taxonomy.schema.json` documents the YAML structure as canonical contract for external tooling. Per repo constraint (no new external Go deps; go.mod has only `gopkg.in/yaml.v3`), Go-side validation is hand-coded inside `LoadTaxonomy()`: the loader checks every blocker entry has all required fields with valid enum values for severity and confirmation_path, and that codes are unique across the array. The JSON Schema file is the externally-readable spec, not a runtime dependency.
3. `internal/cli/blocker_envelope.go` provides `Taxonomy` struct, `LoadTaxonomy()`, `EmitBlocker(code, interp)` per the contract above.
4. `internal/cli/blocker_envelope_test.go` proves: every D1+D2 emitted code resolves to a registered entry; unknown code panics in test mode (recovered via `defer recover()`); message template interpolation substitutes `{placeholder}` correctly; missing interpolation key produces a clear error.
5. Schema YAML file header comment annotates: "Initial population covers validation-at-write-time codes only; future rows extend with state-mutation, gate, archive, scaffold, summary, ideation codes per shared-blocker-taxonomy-spec."
6. `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md` cites `schemas/blocker-taxonomy.yaml` (single line, in the Blocker baseline section).
7. `go test ./...` passes for the new test file.
8. Bounded scope respected: NO modifications to `internal/cli/row_workflow.go` (the real existing emitter), `internal/cli/row_semantics.go` (helper template), or any other existing blocker emission site.

### Initial 11 codes

| code | category | severity | confirmation_path |
|---|---|---|---|
| `definition_yaml_invalid` | definition | block | block |
| `definition_objective_missing` | definition | block | block |
| `definition_gate_policy_missing` | definition | block | block |
| `definition_gate_policy_invalid` | definition | block | block |
| `definition_mode_invalid` | definition | block | block |
| `definition_deliverables_empty` | definition | block | block |
| `definition_deliverable_name_missing` | definition | block | block |
| `definition_deliverable_name_invalid_pattern` | definition | block | block |
| `definition_acceptance_criteria_placeholder` | definition | block | block |
| `definition_unknown_keys` | definition | block | block |
| `ownership_outside_scope` | ownership | warn | warn-with-confirm |

(11 entries — definition codes are 10 because the placeholder one is one entry that fires for any AC field; tally aligns with research §Q4. Final exact code list locked in this spec.)

## Test Scenarios

### Scenario: every-D1-D2-code-registered
- **Verifies**: AC #4
- **WHEN**: blocker_envelope_test.go iterates over a hardcoded list of codes D1 and D2 emit and calls `taxonomy.EmitBlocker(code, ...)` for each
- **THEN**: no test fails; all calls return a non-empty envelope
- **Verification**: `go test ./internal/cli/ -run TestBlockerEnvelopeAllD1D2CodesResolve -v`

### Scenario: unknown-code-panics-in-test-mode
- **Verifies**: AC #4
- **WHEN**: test calls `taxonomy.EmitBlocker("nonexistent_code", nil)` inside a `defer recover()` block
- **THEN**: recovery yields a non-nil panic value; the panic message names the unregistered code
- **Verification**: `go test ./internal/cli/ -run TestBlockerEnvelopeUnknownCodePanics -v`

### Scenario: interpolation-substitutes-placeholders
- **Verifies**: AC #4
- **WHEN**: `EmitBlocker("definition_yaml_invalid", map[string]string{"path": "/tmp/foo.yaml", "detail": "missing field 'objective'"})`
- **THEN**: the returned envelope's `message` is `/tmp/foo.yaml: definition.yaml failed schema validation: missing field 'objective'`
- **Verification**: `go test ./internal/cli/ -run TestBlockerEnvelopeInterpolation -v`

### Scenario: yaml-passes-hand-coded-validation
- **Verifies**: AC #2
- **WHEN**: `LoadTaxonomy()` reads `schemas/blocker-taxonomy.yaml` and runs its hand-coded validation (required-field presence, severity enum, confirmation_path enum, code uniqueness)
- **THEN**: returns a non-nil `*Taxonomy` and a nil error
- **Verification**: `go test ./internal/cli/ -run TestBlockerTaxonomyLoadsAndValidates -v`

### Scenario: docs-architecture-cites-schema
- **Verifies**: AC #6
- **WHEN**: grep `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md` for `schemas/blocker-taxonomy.yaml`
- **THEN**: at least one line matches
- **Verification**: `grep -q 'schemas/blocker-taxonomy.yaml' docs/architecture/pi-step-ceremony-and-artifact-enforcement.md && echo OK`

## Implementation Notes

- Reuse the YAML parser already vendored (likely `gopkg.in/yaml.v3` per go.mod).
- `EmitBlocker` interpolation: simple `{key}` → value substitution; no full template engine. Use `strings.Replace` per key. Missing keys leave `{key}` in the output and surface as a test failure (or wrap with a sentinel error).
- Test mode detection: `testing.Testing()` (Go 1.21+) or check `flag.Lookup("test.v")` for older Go. Project uses Go 1.21+ per go.mod.
- The schema file contents will be embedded via `//go:embed schemas/blocker-taxonomy.yaml` if reading at runtime is awkward — but for now LoadTaxonomy() reads from disk relative to project root (matches existing pattern in internal/cli for schema reads).

## Dependencies

- None. D3 is wave 1; nothing precedes it.
- Downstream: D1 and D2 in waves 2 and 3 consume `Taxonomy.EmitBlocker()` to format their error envelopes.
