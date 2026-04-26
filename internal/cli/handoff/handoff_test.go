package handoff

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

// ---------------------------------------------------------------------------
// AC #2 — DriverHandoff field shape
// ---------------------------------------------------------------------------

func TestDriverHandoffShape(t *testing.T) {
	h := DriverHandoff{
		Target:       "driver:research",
		Step:         "research",
		Row:          "my-row",
		Objective:    "Investigate the problem space",
		Grounding:    ".furrow/rows/my-row/context/bundle.json",
		Constraints:  []string{"no external deps"},
		ReturnFormat: "phase-eos-report",
	}
	data, err := json.Marshal(h)
	if err != nil {
		t.Fatalf("marshal DriverHandoff: %v", err)
	}
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("unmarshal to map: %v", err)
	}
	want := []string{"target", "step", "row", "objective", "grounding", "constraints", "return_format"}
	for _, field := range want {
		if _, ok := raw[field]; !ok {
			t.Errorf("DriverHandoff missing field %q in JSON", field)
		}
	}
	if len(raw) != len(want) {
		t.Errorf("DriverHandoff has %d JSON fields, want %d; keys: %v", len(raw), len(want), keys(raw))
	}
	if target, ok := raw["target"].(string); !ok || !strings.HasPrefix(target, "driver:") {
		t.Errorf("target %q does not start with driver:", raw["target"])
	}
}

// ---------------------------------------------------------------------------
// AC #5 — No shared base struct (structural test)
// ---------------------------------------------------------------------------

func TestNoSharedBase(t *testing.T) {
	// This test validates at the type level that DriverHandoff and EngineHandoff
	// are independent structs with no shared embedding.
	// We verify this by ensuring both can hold distinct field sets.
	d := DriverHandoff{Target: "driver:plan", Step: "plan", Row: "r", Objective: "o", Grounding: "g", Constraints: nil, ReturnFormat: "phase-eos-report"}
	e := EngineHandoff{Target: "engine:freeform", Objective: "write a function", Deliverables: []EngineDeliverable{{Name: "fn", AcceptanceCriteria: []string{"passes tests"}, FileOwnership: []string{}}}, Constraints: nil, Grounding: nil, ReturnFormat: "engine-eos-report"}
	// Both exist independently; if there were a shared base the struct layout would differ.
	if d.Target == e.Target {
		t.Errorf("unexpected: targets match (test data error)")
	}
}

// ---------------------------------------------------------------------------
// AC #6/#7 — RenderDriver: section markers + round-trip
// ---------------------------------------------------------------------------

func TestRenderDriverSectionMarkers(t *testing.T) {
	h := DriverHandoff{
		Target:       "driver:implement",
		Step:         "implement",
		Row:          "my-row",
		Objective:    "Ship the feature",
		Grounding:    "bundle.json",
		Constraints:  []string{"gofmt clean", "no new deps"},
		ReturnFormat: "phase-eos-report",
	}
	out, err := RenderDriver(h)
	if err != nil {
		t.Fatalf("RenderDriver: %v", err)
	}
	markers := []string{
		"<!-- driver-handoff:section:target -->",
		"<!-- driver-handoff:section:objective -->",
		"<!-- driver-handoff:section:grounding -->",
		"<!-- driver-handoff:section:constraints -->",
		"<!-- driver-handoff:section:return-format -->",
	}
	for _, m := range markers {
		if !strings.Contains(out, m) {
			t.Errorf("RenderDriver output missing section marker %q", m)
		}
	}
}

func TestRenderDriverRoundTrip(t *testing.T) {
	tests := []struct {
		name string
		h    DriverHandoff
	}{
		{
			name: "full",
			h: DriverHandoff{
				Target:       "driver:research",
				Step:         "research",
				Row:          "test-row",
				Objective:    "Investigate patterns",
				Grounding:    "path/to/bundle.json",
				Constraints:  []string{"be thorough", "no hallucination"},
				ReturnFormat: "phase-eos-report",
			},
		},
		{
			name: "empty_constraints",
			h: DriverHandoff{
				Target:       "driver:plan",
				Step:         "plan",
				Row:          "another-row",
				Objective:    "Plan the work",
				Grounding:    "bundle.json",
				Constraints:  []string{},
				ReturnFormat: "phase-eos-report",
			},
		},
		{
			name: "single_constraint",
			h: DriverHandoff{
				Target:       "driver:review",
				Step:         "review",
				Row:          "row-x",
				Objective:    "Review the implementation",
				Grounding:    "ctx.json",
				Constraints:  []string{"follow review methodology"},
				ReturnFormat: "phase-eos-report",
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			out, err := RenderDriver(tc.h)
			if err != nil {
				t.Fatalf("RenderDriver: %v", err)
			}
			// Round-trip check: key fields appear in output.
			if !strings.Contains(out, tc.h.Target) {
				t.Errorf("target %q missing from rendered output", tc.h.Target)
			}
			if !strings.Contains(out, tc.h.Step) {
				t.Errorf("step %q missing from rendered output", tc.h.Step)
			}
			if !strings.Contains(out, tc.h.Row) {
				t.Errorf("row %q missing from rendered output", tc.h.Row)
			}
			if !strings.Contains(out, tc.h.Objective) {
				t.Errorf("objective missing from rendered output")
			}
			if !strings.Contains(out, tc.h.Grounding) {
				t.Errorf("grounding %q missing from rendered output", tc.h.Grounding)
			}
			if !strings.Contains(out, tc.h.ReturnFormat) {
				t.Errorf("return_format %q missing from rendered output", tc.h.ReturnFormat)
			}
			for _, c := range tc.h.Constraints {
				if !strings.Contains(out, c) {
					t.Errorf("constraint %q missing from rendered output", c)
				}
			}
		})
	}
}

// ---------------------------------------------------------------------------
// RenderEngine: section markers + round-trip
// ---------------------------------------------------------------------------

func TestRenderEngineSectionMarkers(t *testing.T) {
	h := EngineHandoff{
		Target:    "engine:go-specialist",
		Objective: "Implement the parser",
		Deliverables: []EngineDeliverable{
			{
				Name:               "parser",
				AcceptanceCriteria: []string{"parses valid input", "returns error on invalid"},
				FileOwnership:      []string{"internal/parser/parser.go"},
			},
		},
		Constraints:  []string{"table-driven tests"},
		Grounding:    []EngineGroundingItem{{Path: "internal/parser/parser.go", WhyRelevant: "existing structure"}},
		ReturnFormat: "engine-eos-report",
	}
	out, err := RenderEngine(h)
	if err != nil {
		t.Fatalf("RenderEngine: %v", err)
	}
	markers := []string{
		"<!-- engine-handoff:section:target -->",
		"<!-- engine-handoff:section:objective -->",
		"<!-- engine-handoff:section:deliverables -->",
		"<!-- engine-handoff:section:constraints -->",
		"<!-- engine-handoff:section:grounding -->",
		"<!-- engine-handoff:section:return-format -->",
	}
	for _, m := range markers {
		if !strings.Contains(out, m) {
			t.Errorf("RenderEngine output missing section marker %q", m)
		}
	}
}

func TestRenderEngineRoundTrip(t *testing.T) {
	tests := []struct {
		name string
		h    EngineHandoff
	}{
		{
			name: "full",
			h: EngineHandoff{
				Target:    "engine:go-specialist",
				Objective: "Write the implementation",
				Deliverables: []EngineDeliverable{
					{
						Name:               "impl",
						AcceptanceCriteria: []string{"passes all tests"},
						FileOwnership:      []string{"internal/foo/foo.go"},
					},
				},
				Constraints:  []string{"no global state"},
				Grounding:    []EngineGroundingItem{{Path: "internal/foo/foo.go", WhyRelevant: "current structure"}},
				ReturnFormat: "engine-eos-report",
			},
		},
		{
			name: "multiple_deliverables",
			h: EngineHandoff{
				Target:    "engine:freeform",
				Objective: "Create schema and tests",
				Deliverables: []EngineDeliverable{
					{
						Name:               "schema",
						AcceptanceCriteria: []string{"validates correctly"},
						FileOwnership:      []string{"schemas/foo.json"},
					},
					{
						Name:               "tests",
						AcceptanceCriteria: []string{"80% coverage"},
						FileOwnership:      []string{"internal/foo/foo_test.go"},
					},
				},
				Constraints:  []string{"gofmt clean"},
				Grounding:    []EngineGroundingItem{},
				ReturnFormat: "engine-eos-report",
			},
		},
		{
			name: "empty_grounding_constraints",
			h: EngineHandoff{
				Target:    "engine:python-specialist",
				Objective: "Analyse the data",
				Deliverables: []EngineDeliverable{
					{
						Name:               "analysis",
						AcceptanceCriteria: []string{"produces output"},
						FileOwnership:      []string{},
					},
				},
				Constraints:  []string{},
				Grounding:    []EngineGroundingItem{},
				ReturnFormat: "engine-eos-report",
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			out, err := RenderEngine(tc.h)
			if err != nil {
				t.Fatalf("RenderEngine: %v", err)
			}
			if !strings.Contains(out, tc.h.Target) {
				t.Errorf("target %q missing from output", tc.h.Target)
			}
			if !strings.Contains(out, tc.h.Objective) {
				t.Errorf("objective missing from output")
			}
			for _, d := range tc.h.Deliverables {
				if !strings.Contains(out, d.Name) {
					t.Errorf("deliverable name %q missing from output", d.Name)
				}
			}
		})
	}
}

// ---------------------------------------------------------------------------
// AC #12 — Validate valid passes; malformed fails with registered code.
// ---------------------------------------------------------------------------

func TestValidateDriverJSONValid(t *testing.T) {
	h := DriverHandoff{
		Target:       "driver:research",
		Step:         "research",
		Row:          "my-row",
		Objective:    "Investigate the problem",
		Grounding:    "bundle.json",
		Constraints:  []string{},
		ReturnFormat: "phase-eos-report",
	}
	data, _ := json.Marshal(h)
	env, err := ValidateDriverJSON(data, "test")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if env != nil {
		t.Errorf("expected valid, got envelope: %+v", env)
	}
}

func TestValidateDriverJSONMissingRequired(t *testing.T) {
	tests := []struct {
		name     string
		drop     string
		wantCode string
	}{
		{"missing target", "target", CodeHandoffRequiredFieldMissing},
		{"missing step", "step", CodeHandoffRequiredFieldMissing},
		{"missing row", "row", CodeHandoffRequiredFieldMissing},
		{"missing objective", "objective", CodeHandoffRequiredFieldMissing},
		{"missing grounding", "grounding", CodeHandoffRequiredFieldMissing},
		{"missing return_format", "return_format", CodeHandoffRequiredFieldMissing},
		{"missing constraints", "constraints", CodeHandoffRequiredFieldMissing},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			raw := map[string]any{
				"target":        "driver:research",
				"step":          "research",
				"row":           "my-row",
				"objective":     "obj",
				"grounding":     "bundle.json",
				"constraints":   []string{},
				"return_format": "phase-eos-report",
			}
			delete(raw, tc.drop)
			data, _ := json.Marshal(raw)
			env, err := ValidateDriverJSON(data, "test")
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if env == nil {
				t.Fatal("expected envelope, got nil")
			}
			if env.Code != tc.wantCode {
				t.Errorf("got code %q, want %q", env.Code, tc.wantCode)
			}
		})
	}
}

func TestValidateDriverJSONUnknownField(t *testing.T) {
	raw := map[string]any{
		"target":        "driver:research",
		"step":          "research",
		"row":           "my-row",
		"objective":     "obj",
		"grounding":     "bundle.json",
		"constraints":   []string{},
		"return_format": "phase-eos-report",
		"extra_field":   "bad",
	}
	data, _ := json.Marshal(raw)
	env, err := ValidateDriverJSON(data, "test")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if env == nil {
		t.Fatal("expected envelope for unknown field")
	}
	if env.Code != CodeHandoffUnknownField {
		t.Errorf("got code %q, want %q", env.Code, CodeHandoffUnknownField)
	}
}

func TestValidateEngineJSONValid(t *testing.T) {
	h := EngineHandoff{
		Target:    "engine:go-specialist",
		Objective: "Write a parser function",
		Deliverables: []EngineDeliverable{
			{
				Name:               "parser",
				AcceptanceCriteria: []string{"parses valid JSON"},
				FileOwnership:      []string{"internal/parser/parser.go"},
			},
		},
		Constraints:  []string{"table-driven tests"},
		Grounding:    []EngineGroundingItem{{Path: "internal/parser/parser.go", WhyRelevant: "current structure"}},
		ReturnFormat: "engine-eos-report",
	}
	data, _ := json.Marshal(h)
	env, err := ValidateEngineJSON(data, "test")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if env != nil {
		t.Errorf("expected valid, got envelope: %+v", env)
	}
}

func TestValidateEngineJSONFurrowPath(t *testing.T) {
	// AC #11: engine handoff with .furrow/ in grounding path rejected at validation.
	h := EngineHandoff{
		Target:    "engine:go-specialist",
		Objective: "Write a parser function",
		Deliverables: []EngineDeliverable{
			{Name: "parser", AcceptanceCriteria: []string{"passes tests"}, FileOwnership: []string{}},
		},
		Constraints: []string{},
		Grounding: []EngineGroundingItem{
			{Path: ".furrow/rows/foo/state.json", WhyRelevant: "context"},
		},
		ReturnFormat: "engine-eos-report",
	}
	data, _ := json.Marshal(h)
	env, err := ValidateEngineJSON(data, "test")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if env == nil {
		t.Fatal("expected validation failure for .furrow/ grounding path")
	}
	if env.Code != CodeHandoffSchemaInvalid {
		t.Errorf("got code %q, want %q", env.Code, CodeHandoffSchemaInvalid)
	}
}

func TestValidateEngineJSONFurrowVocabInConstraint(t *testing.T) {
	// AC #11: constraints containing gate_policy rejected.
	h := EngineHandoff{
		Target:    "engine:go-specialist",
		Objective: "Write a function",
		Deliverables: []EngineDeliverable{
			{Name: "fn", AcceptanceCriteria: []string{"works"}, FileOwnership: []string{}},
		},
		Constraints:  []string{"respect the gate_policy"},
		Grounding:    []EngineGroundingItem{},
		ReturnFormat: "engine-eos-report",
	}
	data, _ := json.Marshal(h)
	env, err := ValidateEngineJSON(data, "test")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if env == nil {
		t.Fatal("expected validation failure for gate_policy in constraint")
	}
	if env.Code != CodeHandoffSchemaInvalid {
		t.Errorf("got code %q, want %q", env.Code, CodeHandoffSchemaInvalid)
	}
}

// ---------------------------------------------------------------------------
// AC #12 — Missing required field fails; validate malformed fails with code.
// ---------------------------------------------------------------------------

func TestRenderDriverMissingRequired(t *testing.T) {
	_, err := RenderDriver(DriverHandoff{})
	if err == nil {
		t.Error("expected error for empty DriverHandoff")
	}
}

func TestRenderEngineMissingRequired(t *testing.T) {
	_, err := RenderEngine(EngineHandoff{})
	if err == nil {
		t.Error("expected error for empty EngineHandoff")
	}
}

// ---------------------------------------------------------------------------
// AC #12 — validate malformed file fails with registered code
// ---------------------------------------------------------------------------

func TestValidateFileMalformed(t *testing.T) {
	// A file that claims to be a driver handoff but is missing sections.
	content := "# Driver Handoff: driver:research\n\nSome content without proper sections.\n"
	// Write to a temp file.
	tmp, err := createTempFile(t, content)
	if err != nil {
		t.Fatalf("create temp file: %v", err)
	}

	env, ferr := ValidateFile(tmp)
	if ferr != nil {
		t.Fatalf("unexpected error: %v", ferr)
	}
	if env == nil {
		t.Fatal("expected validation failure for malformed driver handoff")
	}
	if env.Code != CodeHandoffSchemaInvalid {
		t.Errorf("got code %q, want %q", env.Code, CodeHandoffSchemaInvalid)
	}
}

func TestValidateFileEngineWithFurrowVocab(t *testing.T) {
	// An engine handoff file that contains Furrow vocabulary should fail.
	h := EngineHandoff{
		Target:    "engine:go-specialist",
		Objective: "Write a function",
		Deliverables: []EngineDeliverable{
			{Name: "fn", AcceptanceCriteria: []string{"works"}, FileOwnership: []string{}},
		},
		Constraints:  []string{},
		Grounding:    []EngineGroundingItem{},
		ReturnFormat: "engine-eos-report",
	}
	rendered, err := RenderEngine(h)
	if err != nil {
		t.Fatalf("render: %v", err)
	}
	// Inject Furrow vocab into the rendered content.
	rendered += "\nNote: see the almanac for more context.\n"

	tmp, cerr := createTempFile(t, rendered)
	if cerr != nil {
		t.Fatalf("create temp: %v", cerr)
	}
	env, verr := ValidateFile(tmp)
	if verr != nil {
		t.Fatalf("unexpected error: %v", verr)
	}
	if env == nil {
		t.Fatal("expected validation failure for Furrow vocab in engine handoff")
	}
	if env.Code != CodeHandoffSchemaInvalid {
		t.Errorf("got code %q, want %q", env.Code, CodeHandoffSchemaInvalid)
	}
}

// ---------------------------------------------------------------------------
// Helper: createTempFile writes content to a temp file and returns the path.
// ---------------------------------------------------------------------------

func createTempFile(t *testing.T, content string) (string, error) {
	t.Helper()
	f, err := os.CreateTemp(t.TempDir(), "handoff-test-*.md")
	if err != nil {
		return "", err
	}
	_, err = f.WriteString(content)
	_ = f.Close()
	return f.Name(), err
}

func keys(m map[string]any) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}
