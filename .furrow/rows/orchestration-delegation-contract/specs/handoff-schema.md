# D1 — Handoff Schema (Implementation Spec)

Deliverable: `handoff-schema` (W2). Specialist: `go-specialist`.
Source: `definition.yaml` D1 ACs; `research/handoff-shape.md` T1 prior art (forked-and-pruned per O1/O6).

<!-- spec:section:goals -->
## Goals

- Ship two **forked, additionalProperties:false** JSON Schemas — `DriverHandoff` (Furrow-aware, 7 fields) and `EngineHandoff` (Furrow-unaware, 6 fields) — at `schemas/handoff-driver.schema.json` and `schemas/handoff-engine.schema.json`.
- Ship two Go structs in `internal/cli/handoff/schema.go` (no shared base; struct tags drive both schema generation cross-checks and template rendering).
- Ship two Go text/templates that render handoffs to canonical markdown with stable section order.
- Ship `furrow handoff render` and `furrow handoff validate` subcommands that dispatch on `target:` prefix.
- Ship return-format identifier resolution — `return_format` is a string identifier that resolves to a JSON Schema in `templates/handoffs/return-formats/`.
- Schema-level enforcement that engines stay Furrow-unaware: any `.furrow/` substring or Furrow vocab token in `EngineHandoff` fails validation with a registered blocker code.
- Three blocker codes registered in `schemas/blocker-taxonomy.yaml`: `handoff_schema_invalid`, `handoff_required_field_missing`, `handoff_unknown_field`.

<!-- spec:section:non-goals -->
## Non-goals

- No `schema_version` field — handoffs are ephemeral; no re-validation after delegation (AC #1).
- No `persona_ref` field — `target` encodes persona by convention.
- No shared base struct, no embedded `HandoffCommon` — divergence is intentional architectural signal (AC #5, constraint #5).
- No round-trippability for *every* field — only the round-trippable subset (objective, constraints, deliverables structure, plain-text grounding entries). Markdown formatting niceties may be lossy.
- No drivers.json / persistent driver registry surface (out of D1 scope; constraint #6).
- No tool-call-as-handoff transport — markdown render is the only renderer this row.

<!-- spec:section:approach -->
## Approach

Two parallel families. `internal/cli/handoff/` owns:

- `schema.go` — Go structs (no shared base), exported field-validation helpers.
- `render.go` — `RenderDriver(DriverHandoff) (string, error)`, `RenderEngine(EngineHandoff) (string, error)`. Loads templates via `embed.FS`.
- `validate.go` — `ValidateFile(path string) (*Envelope, error)` sniffs `target:` prefix from front-matter, picks `handoff-driver.schema.json` vs `handoff-engine.schema.json`, runs the JSON-Schema validator, emits a taxonomy-conformant blocker envelope on failure.
- `cmd.go` — argv dispatch for `furrow handoff render|validate`.
- `handoff_test.go` — table-driven coverage per AC #12.

Schemas live as canonical JSON Schema files; the Go structs are hand-maintained against them with a parity test (`TestSchemaStructParity`) that walks struct fields and asserts each appears in the matching schema. No code-gen dependency (per constraint #14).

The Furrow-vocab corpus lives in `internal/cli/handoff/vocab.go` as a single regex constant referenced by both `EngineHandoff.validate()` and the JSON Schema `pattern` property.

<!-- spec:section:schemas -->
## Schemas

### `schemas/handoff-driver.schema.json` (DriverHandoff — 7 fields)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://furrow.dev/schemas/handoff-driver.schema.json",
  "title": "DriverHandoff",
  "type": "object",
  "additionalProperties": false,
  "required": ["target", "step", "row", "objective", "grounding", "constraints", "return_format"],
  "properties": {
    "target": {
      "type": "string",
      "pattern": "^driver:(ideate|research|plan|spec|decompose|implement|review)$"
    },
    "step": {
      "type": "string",
      "enum": ["ideate", "research", "plan", "spec", "decompose", "implement", "review"]
    },
    "row": { "type": "string", "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$" },
    "objective": { "type": "string", "minLength": 1, "maxLength": 4000 },
    "grounding": { "type": "string", "minLength": 1, "maxLength": 1024,
                    "description": "Path to D4 bundle artifact; single string per AC #4(b)" },
    "constraints": { "type": "array", "items": { "type": "string", "minLength": 1 }, "minItems": 0 },
    "return_format": { "type": "string", "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$",
                       "description": "Resolves to templates/handoffs/return-formats/{id}.json" }
  }
}
```

### `schemas/handoff-engine.schema.json` (EngineHandoff — 6 fields)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://furrow.dev/schemas/handoff-engine.schema.json",
  "title": "EngineHandoff",
  "type": "object",
  "additionalProperties": false,
  "required": ["target", "objective", "deliverables", "constraints", "grounding", "return_format"],
  "properties": {
    "target": {
      "type": "string",
      "pattern": "^engine:([a-z0-9]+(-[a-z0-9]+)*|freeform)$"
    },
    "objective": {
      "type": "string", "minLength": 1, "maxLength": 4000,
      "not": { "pattern": "(?i)\\b(row|step|gate_policy|deliverable|blocker|almanac|\\.furrow/)\\b" }
    },
    "deliverables": {
      "type": "array", "minItems": 1,
      "items": {
        "type": "object", "additionalProperties": false,
        "required": ["name", "acceptance_criteria", "file_ownership"],
        "properties": {
          "name": { "type": "string", "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$" },
          "acceptance_criteria": { "type": "array", "minItems": 1, "items": { "type": "string", "minLength": 1 } },
          "file_ownership": { "type": "array", "minItems": 0,
                              "items": { "type": "string", "not": { "pattern": "\\.furrow/" } } }
        }
      }
    },
    "constraints": {
      "type": "array",
      "items": {
        "type": "string", "minLength": 1,
        "not": { "pattern": "(?i)\\b(row|step|gate_policy|deliverable|blocker|almanac)\\b|\\.furrow/" }
      }
    },
    "grounding": {
      "type": "array", "minItems": 0,
      "items": {
        "type": "object", "additionalProperties": false,
        "required": ["path", "why_relevant"],
        "properties": {
          "path": { "type": "string", "not": { "pattern": "\\.furrow/" } },
          "why_relevant": { "type": "string", "minLength": 1, "maxLength": 500 }
        }
      }
    },
    "return_format": { "type": "string", "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$" }
  }
}
```

### Furrow-vocab rejection regex (canonical)

```
(?i)\b(gate_policy|deliverable|blocker|almanac|rationale\.yaml)\b|\.furrow/|\bfurrow (row|context|handoff|hook|validate|gate)\b|\b(rws|alm|sds)\s
```

This regex is the single source of truth — embedded in:
- `EngineHandoff.objective.not.pattern` (engine objective is task-scoped).
- Each item of `EngineHandoff.constraints[].not.pattern`.
- Each `EngineHandoff.grounding[].path.not.pattern` (path-only flavor `\.furrow/`).
- Each item of `EngineHandoff.deliverables[].file_ownership[].not.pattern` (path flavor).
- `internal/cli/handoff/vocab.go` `FurrowVocabPattern` constant for fast pre-validation.

**Tightening from initial proposal**: bare `\bstep\b` and `\brow\b` matchers DROPPED — they false-positive on benign English ("step through the function", "row of items"). Tokens kept are either compound (`gate_policy`), unambiguously Furrow (`almanac`, `blocker`), command-prefixed (`furrow row`, `rws `), or path-anchored (`\.furrow/`, `rationale\.yaml`). The 50-string corpus test in `vocab_test.go` (25 must-pass benign + 25 must-fail Furrow-laden) verifies the tightened pattern before validation enforcement turns on.

<!-- spec:section:go-structs -->
## Go structs (`internal/cli/handoff/schema.go`)

```go
// Package handoff defines forked DriverHandoff and EngineHandoff schemas.
// NO shared base struct: divergence is intentional. DriverHandoff is
// Furrow-aware (knows row/step). EngineHandoff is Furrow-unaware
// (drivers curate context per the architecture contract).
package handoff

// DriverHandoff is the priming payload from operator -> driver. 7 fields.
type DriverHandoff struct {
    Target       string   `json:"target"`        // ^driver:{step}$
    Step         string   `json:"step"`          // 7-step enum
    Row          string   `json:"row"`           // kebab-case row name
    Objective    string   `json:"objective"`     // step-scoped
    Grounding    string   `json:"grounding"`     // single path -> D4 bundle
    Constraints  []string `json:"constraints"`   // row-level
    ReturnFormat string   `json:"return_format"` // ID -> return-formats/{id}.json
}

// EngineHandoff is the dispatch payload from driver -> engine. 6 fields.
// FURROW-UNAWARE BY CONSTRUCTION: schema validation rejects any
// .furrow/ path or Furrow vocab token in objective, constraints, or grounding.
type EngineHandoff struct {
    Target       string                `json:"target"`        // ^engine:{specialist}|engine:freeform$
    Objective    string                `json:"objective"`     // task-scoped, no Furrow framing
    Deliverables []EngineDeliverable   `json:"deliverables"`  // {name, ac, file_ownership}
    Constraints  []string              `json:"constraints"`   // engine-scoped
    Grounding    []EngineGroundingItem `json:"grounding"`     // curated source-file refs
    ReturnFormat string                `json:"return_format"`
}

type EngineDeliverable struct {
    Name                string   `json:"name"`
    AcceptanceCriteria  []string `json:"acceptance_criteria"`
    FileOwnership       []string `json:"file_ownership"`
}

type EngineGroundingItem struct {
    Path        string `json:"path"`
    WhyRelevant string `json:"why_relevant"`
}
```

**Why no shared base** (AC #1, AC #5; constraint #8): the two layers MUST diverge. A `HandoffCommon` embedding would invite drift back toward a single schema with optionals — exactly the structure T1 recommended *against* (Q3 in research, supersession by O1 forked-schemas). Keeping them as sibling types makes any new shared field a deliberate, reviewed parallel addition.

<!-- spec:section:render-templates -->
## Render templates

### `templates/handoff-driver.md.tmpl`

```text
<!-- driver-handoff:section:target -->
# Driver Handoff: {{ .Target }}
Step: {{ .Step }}    Row: {{ .Row }}

<!-- driver-handoff:section:objective -->
## Objective
{{ .Objective }}

<!-- driver-handoff:section:grounding -->
## Grounding
Bundle: {{ .Grounding }}

<!-- driver-handoff:section:constraints -->
## Constraints
{{- range .Constraints }}
- {{ . }}
{{- end }}

<!-- driver-handoff:section:return-format -->
## Return Format
`{{ .ReturnFormat }}` (resolves to templates/handoffs/return-formats/{{ .ReturnFormat }}.json)
```

### `templates/handoff-engine.md.tmpl`

```text
<!-- engine-handoff:section:target -->
# Engine Handoff: {{ .Target }}

<!-- engine-handoff:section:objective -->
## Objective
{{ .Objective }}

<!-- engine-handoff:section:deliverables -->
## Deliverables
{{- range .Deliverables }}
### {{ .Name }}
**Acceptance criteria:**
{{- range .AcceptanceCriteria }}
- {{ . }}
{{- end }}
**File ownership:**
{{- range .FileOwnership }}
- `{{ . }}`
{{- end }}
{{ end }}

<!-- engine-handoff:section:constraints -->
## Constraints
{{- range .Constraints }}
- {{ . }}
{{- end }}

<!-- engine-handoff:section:grounding -->
## Grounding
{{- range .Grounding }}
- `{{ .Path }}` — {{ .WhyRelevant }}
{{- end }}

<!-- engine-handoff:section:return-format -->
## Return Format
`{{ .ReturnFormat }}`
```

Both templates use stable section order. Markers follow the D6 presentation-protocol convention (`<!-- {phase}:section:{name} -->`). Templates are embedded into the binary via `//go:embed`.

<!-- spec:section:return-format-resolution -->
## Return-format resolution

`return_format` is a string identifier (kebab-case). Resolution algorithm (in `internal/cli/handoff/return_format.go`):

1. Compute `path := filepath.Join("templates/handoffs/return-formats", id+".json")`.
2. Stat path; if missing, fail with `handoff_schema_invalid` blocker code, message `unknown return_format identifier: %s`.
3. The schema file itself is a JSON Schema (draft 2020-12) describing the shape the engine/driver must return. Resolution is read-only at render-time; engines are expected to receive the resolved schema in their grounding bundle (D4 stitches it in).

### Initial return-format schemas shipped this row

- `templates/handoffs/return-formats/phase-eos-report.json` — driver phase-result shape (sections: `key-findings`, `artifacts-written`, `gate-recommendation`, `next-step`). Used by `DriverHandoff.return_format = "phase-eos-report"`.
- `templates/handoffs/return-formats/engine-eos-report.json` — engine task-result shape (sections: `summary`, `artifacts-written`, `tests-run`, `blockers`, `recommendations`). Used by `EngineHandoff.return_format = "engine-eos-report"`.

Both schemas are JSON Schema 2020-12, additionalProperties:false. Future return-formats land here without touching the handoff schemas — extensibility by directory.

<!-- spec:section:cli-surface -->
## CLI surface

### `furrow handoff render`

```
furrow handoff render \
  --target driver:{step}|engine:{specialist-id}|engine:freeform \
  --row <row> \
  --step <step> \
  [--objective <stdin|-|"text">] \
  [--write] \
  [--json]
```

- `driver:{step}` target: builds `DriverHandoff` from `--row`, `--step`, the focused-row state, definition.yaml constraints, and the D4 bundle reference; emits markdown by default, JSON with `--json`.
- `engine:{id}` target: reads `EngineHandoff` JSON from stdin (the driver supplies the curated value); validates against `handoff-engine.schema.json` BEFORE rendering. `--objective` and `--row` flags ignored for engine targets (with a usage warning).
- `--write` writes the rendered markdown to `.furrow/rows/{row}/handoffs/{step}-to-{target-slug}.md` where `target-slug` = `target` with `:` -> `-`. Idempotent: same inputs -> same output bytes.
- Exit codes: 0 = success, 1 = usage error, 2 = schema validation failure (with blocker envelope).

### `furrow handoff validate`

```
furrow handoff validate <path> [--json]
```

- Reads file, sniffs first non-blank line for `# Driver Handoff:` or `# Engine Handoff:` to choose schema.
- Parses front-matter + sections back into the appropriate struct, marshals to JSON, validates against schema.
- On failure emits a `BlockerEnvelope` (existing pattern from `internal/cli/blocker_envelope.go`) with code from `{handoff_schema_invalid, handoff_required_field_missing, handoff_unknown_field}`.
- Exit 0 on pass, 2 on validation failure, 1 on usage error.

### Top-level registration (`internal/cli/app.go`)

Add `case "handoff": return a.runHandoff(args[1:])` in the root switch (line ~76 in current `app.go`). `runHandoff` dispatches to `render` and `validate` subcommands, mirroring `runRow`'s shape per AC #13.

<!-- spec:section:acceptance -->
## Acceptance scenarios

**AC #1 — schemas exist, no shared base, no schema_version, no persona_ref.**
- WHEN `ls schemas/handoff-*.schema.json` runs
- THEN both files exist; each is `additionalProperties:false` at all object levels; neither contains `schema_version` or `persona_ref` properties.
- Verify: `jq '.properties | keys' schemas/handoff-driver.schema.json` returns exactly the 7 fields; same for engine returning 6.

**AC #2 — DriverHandoff field set.**
- WHEN a `DriverHandoff` value is marshaled
- THEN required keys are exactly `{target, step, row, objective, grounding, constraints, return_format}` and `target` matches `^driver:(ideate|...|review)$`.
- Verify: `go test ./internal/cli/handoff -run TestDriverHandoffShape`.

**AC #3 — EngineHandoff field set + Furrow-stripping.**
- WHEN an `EngineHandoff` is validated with `objective: "update the row's deliverable"`
- THEN validation fails with code `handoff_schema_invalid` (regex match on `row` and `deliverable`).
- Verify: `furrow handoff validate fixtures/engine-furrow-leakage.md --json` exits 2.

**AC #4 — Field-shape decisions frozen.**
- WHEN parsing `DriverHandoff.grounding`
- THEN it is a single string (path), not array; `EngineHandoff.grounding` is array of `{path, why_relevant}`; `return_format` is a string identifier resolving to a schema.
- Verify: schema parity test + render output snapshot.

**AC #5 — Two Go structs, no shared base.**
- WHEN `grep -n "type.*Handoff.*struct" internal/cli/handoff/schema.go` runs
- THEN exactly two struct definitions appear; no `HandoffCommon` type exists; no struct embeds another.

**AC #6 — Two render templates.**
- WHEN `RenderDriver` is called with a fully populated value
- THEN output contains all 7 section markers `<!-- driver-handoff:section:* -->` in stable order.

**AC #7 — Render functions + round-trip.**
- WHEN `value -> RenderDriver -> parseDriver` runs on the round-trippable subset
- THEN parsed struct equals original.
- Verify: `TestRenderDriverRoundTrip` table-driven.

**AC #8 — `furrow handoff render` dispatch.**
- WHEN `--target driver:research --row foo --step research` runs against a fixture row
- THEN markdown lands on stdout; with `--write` it lands at `.furrow/rows/foo/handoffs/research-to-driver-research.md`.
- WHEN `--target engine:go-specialist` with stdin JSON
- THEN schema validation runs first, then render.

**AC #9 — Idempotent write.**
- WHEN `furrow handoff render --target driver:research --row foo --step research --write` runs twice
- THEN both writes produce byte-identical files (`diff` returns 0).

**AC #10 — `furrow handoff validate` dispatch + blocker envelope.**
- WHEN a malformed driver handoff is validated
- THEN exit 2, JSON envelope with `code: handoff_required_field_missing` (or `_unknown_field`/`_schema_invalid`) and `severity: error`.

**AC #11 — Engine handoff content discipline.**
- WHEN engine handoff contains `grounding[0].path = ".furrow/rows/foo/state.json"`
- THEN validation fails with `handoff_schema_invalid`.
- WHEN engine handoff contains `constraints: ["respect the gate_policy"]`
- THEN validation fails (vocab match).

**AC #12 — Test coverage.**
- All 7 cases from AC #12 enumerated as table entries in `handoff_test.go`. `go test -run TestHandoff -v` shows all pass.

**AC #13 — `app.go` registration follows pre-write-validation-go-first pattern.**
- `app.go` switch gains `case "handoff":` line; `runHandoff` mirrors `runRow` argv shape; help text added to `printRootHelp`.

**AC #14 — `go test ./...` passes.**

<!-- spec:section:open-questions -->
## Open questions

1. **Front-matter for sniffing in `validate`** — the rendered markdown does NOT have YAML front-matter; sniffing relies on the first H1 (`# Driver Handoff:` / `# Engine Handoff:`). Robust enough? Alternative: prepend a 1-line HTML comment header `<!-- handoff-kind: driver -->`. **Recommendation:** ship the H1 sniff for v1 (keeps the rendered file clean); add the HTML-comment header only if the parser proves brittle in D4 integration.
2. **Vocab false-positives** — `\b(step)\b` could match a benign engine task ("step through the function"). Word boundaries help; `\.furrow/` is unambiguous. Mitigation: regex tested against a 50-string corpus (25 must-pass benign + 25 must-fail Furrow-laden) in `vocab_test.go`. Promote to constraint #8 enforcement only after the corpus is green.
