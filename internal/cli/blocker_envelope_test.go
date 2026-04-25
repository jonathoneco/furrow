package cli

import (
	"sort"
	"strings"
	"testing"
)

// backwardCompatCodes is the locked, immutable set of pre-D1 codes whose
// `code` strings, severities, and `message_template` placeholder sets are
// frozen. These predate the blocker-taxonomy-foundation row and any change
// to their identity breaks already-deployed validators (validate-definition,
// validate-ownership) and the only programmatic consumer (Pi adapter).
//
// See spec §4.3 (specs/canonical-blocker-taxonomy.md) for the lock rationale.
var backwardCompatCodes = []struct {
	code         string
	severity     string
	placeholders []string // sorted, unique placeholder set inside message_template
}{
	{"definition_yaml_invalid", "block", []string{"detail", "path"}},
	{"definition_objective_missing", "block", []string{"path"}},
	{"definition_gate_policy_missing", "block", []string{"path"}},
	{"definition_gate_policy_invalid", "block", []string{"path", "value"}},
	{"definition_mode_invalid", "block", []string{"path", "value"}},
	{"definition_deliverables_empty", "block", []string{"path"}},
	{"definition_deliverable_name_missing", "block", []string{"index", "path"}},
	{"definition_deliverable_name_invalid_pattern", "block", []string{"name", "path"}},
	{"definition_acceptance_criteria_placeholder", "block", []string{"name", "path", "value"}},
	{"definition_unknown_keys", "block", []string{"keys", "path"}},
	{"ownership_outside_scope", "warn", []string{"path", "row"}},
}

// expectedInitialCodes is the full set of codes the registry must resolve
// after D1. It is the union of the 11 backward-compat codes (frozen) and
// every additional code added by deliverable canonical-blocker-taxonomy.
//
// Every entry here MUST exist in schemas/blocker-taxonomy.yaml, and
// EmitBlocker must succeed for each one when supplied a placeholder map
// containing the union of placeholders across the registry.
var expectedInitialCodes = []string{
	// Pre-D1 backward-compat (locked):
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
	// Hook-emit codes (research/hook-audit.md §3):
	"state_json_direct_write",
	"verdict_direct_write",
	"correction_limit_reached",
	"script_guard_internal_invocation",
	"precommit_install_artifact_staged",
	"precommit_script_mode_invalid",
	"precommit_typechange_to_symlink",
	"ideation_incomplete_definition_fields",
	"summary_section_missing",
	"summary_section_empty",
	"state_validation_failed_warn",
	"summary_section_missing_warn",
	"summary_section_empty_warn",
	// Go-side enforcement codes (pi-step-ceremony Blocker baseline):
	"step_order_invalid",
	"decided_by_invalid_for_policy",
	"nonce_stale",
	"verdict_linkage_missing",
	"archived_row_mutation",
	"supervised_boundary_unconfirmed",
	// Existing emit-site codes (preserved per spec §6.4 reconciliation):
	"pending_user_actions",
	"seed_store_unavailable",
	"missing_seed_record",
	"closed_seed",
	"seed_status_mismatch",
	"supersedence_evidence_missing",
	"missing_required_artifact",
	"artifact_scaffold_incomplete",
	"artifact_validation_failed",
	"archive_requires_review_gate",
}

// testInterpKeys returns a placeholder map with every {key} the registry
// references, mapped to a fixture-safe scalar string. Used by
// TestBlockerEnvelopeAllInitialCodesResolve to drive every code through
// EmitBlocker without unresolved-placeholder panics.
func testInterpKeys() map[string]string {
	return map[string]string{
		"path":             "/tmp/foo.yaml",
		"name":             "deliverable",
		"value":            "fixture",
		"keys":             "extra",
		"index":            "0",
		"row":              "fixture-row",
		"detail":           "fixture detail",
		"limit":            "3",
		"deliverable":      "fixture-deliverable",
		"command":          "fixture-cmd",
		"mode":             "100644",
		"missing":          "objective, gate_policy",
		"section":          "Open Questions",
		"actual_count":     "0",
		"required_count":   "1",
		"current_step":     "plan",
		"target_step":      "implement",
		"decided_by":       "human",
		"policy":           "supervised",
		"nonce":            "abc",
		"expected_nonce":   "def",
		"boundary":         "implement->review",
		"seed_id":          "S-123",
		"actual_status":    "open",
		"expected_status":  "in_progress",
		"required_commit":  "abc1234",
		"required_row":     "predecessor-row",
		"confirmed_commit": "abc1234",
		"confirmed_row":    "predecessor-row",
		"artifact_id":      "definition",
		"count":            "1",
	}
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

	interp := testInterpKeys()
	for _, code := range expectedInitialCodes {
		t.Run(code, func(t *testing.T) {
			env := tx.EmitBlocker(code, interp)
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

// TestBlockerTaxonomyBackwardCompat11 enforces the locked backward-compat
// invariant for the 11 pre-D1 codes (definition_* + ownership_outside_scope).
// Their code strings, severities, and message_template placeholder sets are
// frozen — drift here breaks already-deployed validators and Pi consumers.
func TestBlockerTaxonomyBackwardCompat11(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	tx, err := LoadTaxonomy()
	if err != nil {
		t.Fatalf("LoadTaxonomy: %v", err)
	}

	for _, want := range backwardCompatCodes {
		t.Run(want.code, func(t *testing.T) {
			b, ok := tx.Lookup(want.code)
			if !ok {
				t.Fatalf("backward-compat code %q is missing from registry", want.code)
			}
			if b.Severity != want.severity {
				t.Errorf("severity drift for %q: got %q, want %q (locked)", want.code, b.Severity, want.severity)
			}
			placeholders := uniqueSortedPlaceholders(b.MessageTemplate)
			if !stringSlicesEqual(placeholders, want.placeholders) {
				t.Errorf("placeholder drift for %q: got %v, want %v (locked)", want.code, placeholders, want.placeholders)
			}
		})
	}
}

// TestBlockerApplicableStepsFilter exercises Taxonomy.Applies to confirm
// step-scoping works as specified.
func TestBlockerApplicableStepsFilter(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	tx, err := LoadTaxonomy()
	if err != nil {
		t.Fatalf("LoadTaxonomy: %v", err)
	}

	cases := []struct {
		name string
		code string
		step string
		want bool
	}{
		// ideation_incomplete_definition_fields has applicable_steps=["ideate"].
		{"ideate-only-on-ideate", "ideation_incomplete_definition_fields", "ideate", true},
		{"ideate-only-on-research", "ideation_incomplete_definition_fields", "research", false},
		{"ideate-only-on-implement", "ideation_incomplete_definition_fields", "implement", false},
		// archive_requires_review_gate has applicable_steps=["review"].
		{"review-only-on-review", "archive_requires_review_gate", "review", true},
		{"review-only-on-implement", "archive_requires_review_gate", "implement", false},
		// Code without applicable_steps applies to every step.
		{"unrestricted-on-ideate", "definition_yaml_invalid", "ideate", true},
		{"unrestricted-on-implement", "definition_yaml_invalid", "implement", true},
		{"unrestricted-on-review", "definition_yaml_invalid", "review", true},
		// summary_section_missing applies to all non-ideate steps.
		{"summary-on-ideate", "summary_section_missing", "ideate", false},
		{"summary-on-research", "summary_section_missing", "research", true},
		{"summary-on-review", "summary_section_missing", "review", true},
		// Unknown code never applies.
		{"unknown-code", "no_such_code_xyz", "implement", false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := tx.Applies(tc.code, tc.step); got != tc.want {
				t.Errorf("Applies(%q, %q) = %v, want %v", tc.code, tc.step, got, tc.want)
			}
		})
	}
}

// uniqueSortedPlaceholders extracts the unique sorted set of {placeholder}
// tokens in template, using the same scanner as unresolvedPlaceholders.
// Used by TestBlockerTaxonomyBackwardCompat11 to lock placeholder sets.
func uniqueSortedPlaceholders(template string) []string {
	seen := make(map[string]struct{})
	for i := 0; i < len(template); i++ {
		if template[i] != '{' {
			continue
		}
		end := strings.IndexByte(template[i+1:], '}')
		if end < 0 {
			break
		}
		key := template[i+1 : i+1+end]
		if isPlaceholderIdent(key) {
			seen[key] = struct{}{}
		}
		i += end
	}
	out := make([]string, 0, len(seen))
	for k := range seen {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func stringSlicesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
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

func TestBlockerEnvelopeMissingInterpolationKeyPanics(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	tx, err := LoadTaxonomy()
	if err != nil {
		t.Fatalf("LoadTaxonomy: %v", err)
	}

	defer func() {
		r := recover()
		if r == nil {
			t.Fatal("expected panic for unresolved interpolation key, got none")
		}
		msg, ok := r.(string)
		if !ok {
			t.Fatalf("panic value is %T, want string", r)
		}
		if !strings.Contains(msg, "path") {
			t.Fatalf("panic message should name the missing key: %q", msg)
		}
	}()

	// Intentionally omit `path` so the {path} placeholder triggers a clear error.
	_ = tx.EmitBlocker("definition_objective_missing", map[string]string{})
}
