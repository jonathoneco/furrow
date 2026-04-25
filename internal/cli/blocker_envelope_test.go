package cli

import (
	"strings"
	"testing"
)

// expectedInitialCodes is the closed list of codes the spec locks for D3's
// initial population. Every code emitted by D1 (validate-definition-go) and
// D2 (validate-ownership-go) must appear here, and the taxonomy YAML must
// resolve every entry.
var expectedInitialCodes = []string{
	"definition_yaml_invalid",
	"definition_objective_missing",
	"definition_gate_policy_missing",
	"definition_gate_policy_invalid",
	"definition_mode_invalid",
	"definition_deliverables_empty",
	"definition_deliverable_name_missing",
	"definition_deliverable_name_invalid_pattern",
	"definition_acceptance_criteria_placeholder",
	"definition_unknown_keys",
	"ownership_outside_scope",
}

func TestBlockerTaxonomyLoadsAndValidates(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	tx, err := LoadTaxonomy()
	if err != nil {
		t.Fatalf("LoadTaxonomy: unexpected error: %v", err)
	}
	if tx == nil {
		t.Fatal("LoadTaxonomy: returned nil taxonomy")
	}
	if tx.Version == "" {
		t.Fatal("taxonomy version is empty")
	}
	if len(tx.Blockers) == 0 {
		t.Fatal("taxonomy blockers[] is empty")
	}
}

func TestBlockerEnvelopeAllInitialCodesResolve(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	tx, err := LoadTaxonomy()
	if err != nil {
		t.Fatalf("LoadTaxonomy: %v", err)
	}

	for _, code := range expectedInitialCodes {
		t.Run(code, func(t *testing.T) {
			env := tx.EmitBlocker(code, map[string]string{
				"path":   "/tmp/foo.yaml",
				"name":   "deliverable",
				"value":  "fixture",
				"keys":   "extra",
				"index":  "0",
				"row":    "fixture-row",
				"detail": "fixture detail",
			})
			if env.Code != code {
				t.Fatalf("EmitBlocker(%q): code mismatch: got %q", code, env.Code)
			}
			if env.Message == "" {
				t.Fatalf("EmitBlocker(%q): message is empty", code)
			}
			if env.Severity == "" {
				t.Fatalf("EmitBlocker(%q): severity is empty", code)
			}
			if env.ConfirmationPath == "" {
				t.Fatalf("EmitBlocker(%q): confirmation_path is empty", code)
			}
			if env.RemediationHint == "" {
				t.Fatalf("EmitBlocker(%q): remediation_hint is empty", code)
			}
		})
	}
}

func TestBlockerEnvelopeUnknownCodePanics(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	tx, err := LoadTaxonomy()
	if err != nil {
		t.Fatalf("LoadTaxonomy: %v", err)
	}

	defer func() {
		r := recover()
		if r == nil {
			t.Fatal("expected panic for unregistered code, got none")
		}
		msg, ok := r.(string)
		if !ok {
			t.Fatalf("panic value is %T, want string", r)
		}
		if !strings.Contains(msg, "nonexistent_code") {
			t.Fatalf("panic message does not name the unregistered code: %q", msg)
		}
	}()

	_ = tx.EmitBlocker("nonexistent_code", nil)
}

func TestBlockerEnvelopeInterpolation(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	tx, err := LoadTaxonomy()
	if err != nil {
		t.Fatalf("LoadTaxonomy: %v", err)
	}

	env := tx.EmitBlocker("definition_objective_missing", map[string]string{
		"path": "/tmp/example/definition.yaml",
	})
	want := "/tmp/example/definition.yaml: missing required field 'objective'"
	if env.Message != want {
		t.Fatalf("interpolation:\n  got  %q\n  want %q", env.Message, want)
	}
}

func TestBlockerEnvelopeMissingInterpolationKeyVisible(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	tx, err := LoadTaxonomy()
	if err != nil {
		t.Fatalf("LoadTaxonomy: %v", err)
	}

	// Intentionally omit `path` so the placeholder remains in the output.
	env := tx.EmitBlocker("definition_objective_missing", map[string]string{})
	if !strings.Contains(env.Message, "{path}") {
		t.Fatalf("missing interpolation key should leave {path} placeholder visible: got %q", env.Message)
	}
}
