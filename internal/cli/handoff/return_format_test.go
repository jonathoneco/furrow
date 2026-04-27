package handoff

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ---------------------------------------------------------------------------
// R3 — ResolveReturnFormat
// ---------------------------------------------------------------------------

func TestResolveReturnFormatKnown(t *testing.T) {
	tests := []struct {
		id string
	}{
		{"phase-eos-report"},
		{"engine-eos-report"},
	}
	for _, tc := range tests {
		t.Run(tc.id, func(t *testing.T) {
			if err := ResolveReturnFormat(tc.id); err != nil {
				t.Errorf("ResolveReturnFormat(%q) = %v; want nil", tc.id, err)
			}
		})
	}
}

func TestResolveReturnFormatUnknown(t *testing.T) {
	tests := []string{
		"nonexistent",
		"totally-made-up-schema",
		"",
		"PHASE-EOS-REPORT", // case-sensitive
	}
	for _, id := range tests {
		t.Run(id, func(t *testing.T) {
			err := ResolveReturnFormat(id)
			if err == nil {
				t.Errorf("ResolveReturnFormat(%q) = nil; want error wrapping ErrUnknownReturnFormat", id)
				return
			}
			if !errors.Is(err, ErrUnknownReturnFormat) {
				t.Errorf("ResolveReturnFormat(%q) error %v does not wrap ErrUnknownReturnFormat", id, err)
			}
		})
	}
}

// TestValidateDriverJSONUnknownReturnFormat: ValidateDriverJSON should reject
// a return_format that doesn't resolve to a known schema (R3).
func TestValidateDriverJSONUnknownReturnFormat(t *testing.T) {
	raw := map[string]any{
		"target":        "driver:research",
		"step":          "research",
		"row":           "my-row",
		"objective":     "obj",
		"grounding":     "bundle.json",
		"constraints":   []string{},
		"return_format": "nonexistent",
	}
	data, _ := json.Marshal(raw)
	env, err := ValidateDriverJSON(data, "test")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if env == nil {
		t.Fatal("expected envelope for unknown return_format, got nil")
	}
	if env.Code != CodeHandoffSchemaInvalid {
		t.Errorf("got code %q, want %q", env.Code, CodeHandoffSchemaInvalid)
	}
}

// TestValidateEngineJSONUnknownReturnFormat: ValidateEngineJSON should reject
// a return_format that doesn't resolve to a known schema (R3).
func TestValidateEngineJSONUnknownReturnFormat(t *testing.T) {
	h := EngineHandoff{
		Target:    "engine:go-specialist",
		Objective: "Write a function",
		Deliverables: []EngineDeliverable{
			{Name: "fn", AcceptanceCriteria: []string{"works"}, FileOwnership: []string{}},
		},
		Constraints:  []string{},
		Grounding:    []EngineGroundingItem{},
		ReturnFormat: "nonexistent",
	}
	data, _ := json.Marshal(h)
	env, err := ValidateEngineJSON(data, "test")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if env == nil {
		t.Fatal("expected envelope for unknown return_format, got nil")
	}
	if env.Code != CodeHandoffSchemaInvalid {
		t.Errorf("got code %q, want %q", env.Code, CodeHandoffSchemaInvalid)
	}
}

// TestRenderDriverUnknownReturnFormat: RenderDriver should return an error for
// an unknown return_format (R3 — wired into render path).
func TestRenderDriverUnknownReturnFormat(t *testing.T) {
	h := DriverHandoff{
		Target:       "driver:research",
		Step:         "research",
		Row:          "my-row",
		Objective:    "Investigate something",
		Grounding:    "bundle.json",
		Constraints:  []string{},
		ReturnFormat: "nonexistent",
	}
	_, err := RenderDriver(h)
	if err == nil {
		t.Fatal("expected error for unknown return_format, got nil")
	}
	if !strings.Contains(err.Error(), "nonexistent") {
		t.Errorf("error %q should mention the unknown return_format ID", err.Error())
	}
}

// TestRenderEngineUnknownReturnFormat: RenderEngine should return an error for
// an unknown return_format (R3 — wired into render path).
func TestRenderEngineUnknownReturnFormat(t *testing.T) {
	h := EngineHandoff{
		Target:    "engine:go-specialist",
		Objective: "Write something",
		Deliverables: []EngineDeliverable{
			{Name: "fn", AcceptanceCriteria: []string{"works"}, FileOwnership: []string{}},
		},
		Constraints:  []string{},
		Grounding:    []EngineGroundingItem{},
		ReturnFormat: "nonexistent",
	}
	_, err := RenderEngine(h)
	if err == nil {
		t.Fatal("expected error for unknown return_format, got nil")
	}
	if !strings.Contains(err.Error(), "nonexistent") {
		t.Errorf("error %q should mention the unknown return_format ID", err.Error())
	}
}

// TestReturnFormatEmbedParity: the embedded return-format schemas in
// internal/cli/handoff/return-formats/ must stay in sync with the
// canonical schemas in templates/handoffs/return-formats/.
// If a schema is added to templates/handoffs/return-formats/ but not copied
// here, this test will catch the drift.
func TestReturnFormatEmbedParity(t *testing.T) {
	// Path from package root to the canonical templates directory.
	// We use a relative path from the test binary's working directory.
	// go test sets the cwd to the package directory.
	canonicalDir := "../../../templates/handoffs/return-formats"
	entries, err := os.ReadDir(canonicalDir)
	if err != nil {
		t.Skipf("cannot read canonical return-formats dir %s: %v (run from repo root)", canonicalDir, err)
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		id := strings.TrimSuffix(e.Name(), ".json")
		if resolveErr := ResolveReturnFormat(id); resolveErr != nil {
			t.Errorf("canonical schema %q exists in templates/handoffs/return-formats/ but is NOT embedded in the package (copy it to internal/cli/handoff/return-formats/)", e.Name())
		}
	}

	// Also verify every embedded schema matches its canonical counterpart byte-for-byte.
	embeddedEntries, err := returnFormatFS.ReadDir(returnFormatDir)
	if err != nil {
		t.Fatalf("read embedded return-formats: %v", err)
	}
	for _, e := range embeddedEntries {
		canonicalPath := filepath.Join(canonicalDir, e.Name())
		canonicalBytes, cerr := os.ReadFile(canonicalPath)
		if cerr != nil {
			t.Errorf("embedded schema %q has no counterpart in templates/handoffs/return-formats/: %v", e.Name(), cerr)
			continue
		}
		embeddedBytes, eerr := returnFormatFS.ReadFile(filepath.Join(returnFormatDir, e.Name()))
		if eerr != nil {
			t.Fatalf("read embedded %q: %v", e.Name(), eerr)
		}
		if string(embeddedBytes) != string(canonicalBytes) {
			t.Errorf("embedded %q differs from canonical templates/handoffs/return-formats/%s — re-copy to sync", e.Name(), e.Name())
		}
	}
}

// ---------------------------------------------------------------------------
// R2 — ParseDriverMarkdown / ParseEngineMarkdown + validateDriverMarkdown strictness
// ---------------------------------------------------------------------------

// TestParseDriverMarkdownRoundTrip: render a driver handoff then parse it back.
func TestParseDriverMarkdownRoundTrip(t *testing.T) {
	tests := []DriverHandoff{
		{
			Target:       "driver:research",
			Step:         "research",
			Row:          "my-row",
			Objective:    "Investigate the problem space",
			Grounding:    "bundle.json",
			Constraints:  []string{"be thorough", "no hallucination"},
			ReturnFormat: "phase-eos-report",
		},
		{
			Target:       "driver:implement",
			Step:         "implement",
			Row:          "another-row",
			Objective:    "Ship the feature",
			Grounding:    ".furrow/rows/another-row/context/bundle.json",
			Constraints:  []string{},
			ReturnFormat: "phase-eos-report",
		},
	}
	for _, orig := range tests {
		t.Run(orig.Step, func(t *testing.T) {
			rendered, err := RenderDriver(orig)
			if err != nil {
				t.Fatalf("RenderDriver: %v", err)
			}
			parsed, perr := ParseDriverMarkdown(rendered)
			if perr != nil {
				t.Fatalf("ParseDriverMarkdown: %v", perr)
			}
			if parsed.Target != orig.Target {
				t.Errorf("target: got %q, want %q", parsed.Target, orig.Target)
			}
			if parsed.Step != orig.Step {
				t.Errorf("step: got %q, want %q", parsed.Step, orig.Step)
			}
			if parsed.Row != orig.Row {
				t.Errorf("row: got %q, want %q", parsed.Row, orig.Row)
			}
			if parsed.Objective != orig.Objective {
				t.Errorf("objective: got %q, want %q", parsed.Objective, orig.Objective)
			}
			if parsed.Grounding != orig.Grounding {
				t.Errorf("grounding: got %q, want %q", parsed.Grounding, orig.Grounding)
			}
			if parsed.ReturnFormat != orig.ReturnFormat {
				t.Errorf("return_format: got %q, want %q", parsed.ReturnFormat, orig.ReturnFormat)
			}
			if len(parsed.Constraints) != len(orig.Constraints) {
				t.Errorf("constraints len: got %d, want %d", len(parsed.Constraints), len(orig.Constraints))
			} else {
				for i := range orig.Constraints {
					if parsed.Constraints[i] != orig.Constraints[i] {
						t.Errorf("constraints[%d]: got %q, want %q", i, parsed.Constraints[i], orig.Constraints[i])
					}
				}
			}
		})
	}
}

// TestParseEngineMarkdownRoundTrip: render an engine handoff then parse it back.
func TestParseEngineMarkdownRoundTrip(t *testing.T) {
	orig := EngineHandoff{
		Target:    "engine:go-specialist",
		Objective: "Write the parser implementation",
		Deliverables: []EngineDeliverable{
			{
				Name:               "parser",
				AcceptanceCriteria: []string{"parses valid input", "returns error on invalid"},
				FileOwnership:      []string{"internal/parser/parser.go"},
			},
		},
		Constraints:  []string{"table-driven tests", "no global state"},
		Grounding:    []EngineGroundingItem{{Path: "internal/parser/parser.go", WhyRelevant: "existing structure"}},
		ReturnFormat: "engine-eos-report",
	}
	rendered, err := RenderEngine(orig)
	if err != nil {
		t.Fatalf("RenderEngine: %v", err)
	}
	parsed, perr := ParseEngineMarkdown(rendered)
	if perr != nil {
		t.Fatalf("ParseEngineMarkdown: %v", perr)
	}
	if parsed.Target != orig.Target {
		t.Errorf("target: got %q, want %q", parsed.Target, orig.Target)
	}
	if parsed.Objective != orig.Objective {
		t.Errorf("objective: got %q, want %q", parsed.Objective, orig.Objective)
	}
	if parsed.ReturnFormat != orig.ReturnFormat {
		t.Errorf("return_format: got %q, want %q", parsed.ReturnFormat, orig.ReturnFormat)
	}
	if len(parsed.Deliverables) != 1 {
		t.Fatalf("deliverables len: got %d, want 1", len(parsed.Deliverables))
	}
	if parsed.Deliverables[0].Name != "parser" {
		t.Errorf("deliverable name: got %q, want %q", parsed.Deliverables[0].Name, "parser")
	}
}

// TestValidateDriverMarkdownInvalidStep: a rendered driver handoff with an invalid
// step (NOT_A_REAL_STEP) must return verdict=invalid after the R2 fix.
// Before R2, validateDriverMarkdown only checked section markers and would return nil.
func TestValidateDriverMarkdownInvalidStep(t *testing.T) {
	// Build a markdown string that has all section markers but an invalid step.
	content := `<!-- driver-handoff:section:target -->
# Driver Handoff: driver:research
Step: NOT_A_REAL_STEP    Row: bad!row

<!-- driver-handoff:section:objective -->
## Objective
Investigate something

<!-- driver-handoff:section:grounding -->
## Grounding
Bundle: bundle.json

<!-- driver-handoff:section:constraints -->
## Constraints

<!-- driver-handoff:section:return-format -->
## Return Format
` + "`phase-eos-report`" + ` (resolves to templates/handoffs/return-formats/phase-eos-report.json)
`
	tmp, err := createTempFile(t, content)
	if err != nil {
		t.Fatalf("create temp: %v", err)
	}
	env, verr := ValidateFile(tmp)
	if verr != nil {
		t.Fatalf("unexpected error: %v", verr)
	}
	if env == nil {
		t.Fatal("expected validation failure for invalid step in driver markdown, got nil (R2 regression)")
	}
	// Should fail with schema-invalid due to invalid step enum.
	if env.Code != CodeHandoffSchemaInvalid && env.Code != CodeHandoffRequiredFieldMissing {
		t.Errorf("got code %q, want %q or %q", env.Code, CodeHandoffSchemaInvalid, CodeHandoffRequiredFieldMissing)
	}
}

// TestValidateDriverMarkdownInvalidReturnFormat: a rendered driver handoff with an
// unknown return_format must return verdict=invalid (R2 + R3 combined).
func TestValidateDriverMarkdownInvalidReturnFormat(t *testing.T) {
	content := `<!-- driver-handoff:section:target -->
# Driver Handoff: driver:research
Step: research    Row: my-row

<!-- driver-handoff:section:objective -->
## Objective
Investigate something

<!-- driver-handoff:section:grounding -->
## Grounding
Bundle: bundle.json

<!-- driver-handoff:section:constraints -->
## Constraints

<!-- driver-handoff:section:return-format -->
## Return Format
` + "`nonexistent-format`" + ` (resolves to templates/handoffs/return-formats/nonexistent-format.json)
`
	tmp, err := createTempFile(t, content)
	if err != nil {
		t.Fatalf("create temp: %v", err)
	}
	env, verr := ValidateFile(tmp)
	if verr != nil {
		t.Fatalf("unexpected error: %v", verr)
	}
	if env == nil {
		t.Fatal("expected validation failure for unknown return_format in driver markdown, got nil")
	}
	if env.Code != CodeHandoffSchemaInvalid {
		t.Errorf("got code %q, want %q", env.Code, CodeHandoffSchemaInvalid)
	}
}

// ---------------------------------------------------------------------------
// R4 — Schema parity: structural drift test
//
// Design choice: Instead of refactoring ValidateDriverJSON/ValidateEngineJSON
// to dynamically parse the JSON Schema files at runtime (which would require
// implementing a subset of JSON Schema Draft 2020-12 in hand-written Go with
// no external deps), we use a structural drift test that asserts every required
// field in schemas/*.schema.json is covered by the corresponding Go validator.
//
// This catches drift between schema and code at test time without adding
// complexity to the hot path. The tradeoff: new schema fields require manual
// Go updates + this test will fail loudly until they're added.
// ---------------------------------------------------------------------------

// TestSchemaRequiredFieldsDriverParity: every field in the JSON Schema's
// "required" array must be checked by ValidateDriverJSON.
func TestSchemaRequiredFieldsDriverParity(t *testing.T) {
	schemaPath := "../../../schemas/handoff-driver.schema.json"
	data, err := os.ReadFile(schemaPath)
	if err != nil {
		t.Skipf("cannot read %s: %v", schemaPath, err)
	}

	var schema struct {
		Required []string `json:"required"`
	}
	if err := json.Unmarshal(data, &schema); err != nil {
		t.Fatalf("parse schema: %v", err)
	}

	// For each required field, dropping it from a valid payload must produce a
	// non-nil envelope from ValidateDriverJSON.
	basePayload := map[string]any{
		"target":        "driver:research",
		"step":          "research",
		"row":           "my-row",
		"objective":     "obj",
		"grounding":     "bundle.json",
		"constraints":   []string{},
		"return_format": "phase-eos-report",
	}

	for _, field := range schema.Required {
		t.Run("required_"+field, func(t *testing.T) {
			payload := copyMap(basePayload)
			delete(payload, field)
			b, _ := json.Marshal(payload)
			env, ferr := ValidateDriverJSON(b, "drift-test")
			if ferr != nil {
				t.Fatalf("unexpected error: %v", ferr)
			}
			if env == nil {
				t.Errorf("field %q is required in handoff-driver.schema.json but ValidateDriverJSON did not reject its absence — schema/code drift", field)
			}
		})
	}
}

// TestSchemaRequiredFieldsEngineParity: every field in the engine JSON Schema's
// "required" array must be checked by ValidateEngineJSON.
func TestSchemaRequiredFieldsEngineParity(t *testing.T) {
	schemaPath := "../../../schemas/handoff-engine.schema.json"
	data, err := os.ReadFile(schemaPath)
	if err != nil {
		t.Skipf("cannot read %s: %v", schemaPath, err)
	}

	var schema struct {
		Required []string `json:"required"`
	}
	if err := json.Unmarshal(data, &schema); err != nil {
		t.Fatalf("parse schema: %v", err)
	}

	basePayload := map[string]any{
		"target":    "engine:go-specialist",
		"objective": "Write a function",
		"deliverables": []map[string]any{
			{"name": "fn", "acceptance_criteria": []string{"works"}, "file_ownership": []string{}},
		},
		"constraints":   []string{},
		"grounding":     []map[string]any{},
		"return_format": "engine-eos-report",
	}

	for _, field := range schema.Required {
		t.Run("required_"+field, func(t *testing.T) {
			payload := copyMap(basePayload)
			delete(payload, field)
			b, _ := json.Marshal(payload)
			env, ferr := ValidateEngineJSON(b, "drift-test")
			if ferr != nil {
				t.Fatalf("unexpected error: %v", ferr)
			}
			if env == nil {
				t.Errorf("field %q is required in handoff-engine.schema.json but ValidateEngineJSON did not reject its absence — schema/code drift", field)
			}
		})
	}
}

// copyMap makes a shallow copy of a map[string]any.
func copyMap(m map[string]any) map[string]any {
	out := make(map[string]any, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}
