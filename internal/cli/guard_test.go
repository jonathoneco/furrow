package cli

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"

	yaml "gopkg.in/yaml.v3"
)

// TestGuardHandlerRegistryParity is the drift guard required by AC5.
// It enforces bidirectional parity:
//
//   - Every event_type in schemas/blocker-event.yaml must have a registered
//     Go handler in guardHandlers.
//   - Every Go handler in guardHandlers must appear as an event_type in
//     the YAML (no orphan handlers).
//
// Adding a YAML entry without a handler (or vice versa) breaks this test
// at the next CI run — registry drift is impossible to ship silently.
func TestGuardHandlerRegistryParity(t *testing.T) {
	yamlEvents := loadYAMLEventTypes(t)
	yamlSet := make(map[string]struct{}, len(yamlEvents))
	for _, name := range yamlEvents {
		yamlSet[name] = struct{}{}
	}

	registrySet := make(map[string]struct{}, len(guardHandlers))
	for name := range guardHandlers {
		registrySet[name] = struct{}{}
	}

	// YAML → registry: every catalog entry must have a handler.
	for name := range yamlSet {
		if _, ok := registrySet[name]; !ok {
			t.Errorf("event_type %q in schemas/blocker-event.yaml has no handler in guardHandlers", name)
		}
	}
	// Registry → YAML: every handler must be in the catalog.
	for name := range registrySet {
		if _, ok := yamlSet[name]; !ok {
			t.Errorf("handler %q in guardHandlers has no event_type entry in schemas/blocker-event.yaml", name)
		}
	}

	// Sanity: shared-contracts.md §C1 locks at 10 entries.
	if len(yamlEvents) != 10 {
		t.Errorf("schemas/blocker-event.yaml event_types[] count = %d, want 10 (specs/shared-contracts.md §C1)", len(yamlEvents))
	}
}

// TestGuardEventTypesMatchSharedContractsCatalog asserts the verbatim
// names from shared-contracts §C1. This double-checks a typo wouldn't
// silently rename an event type.
func TestGuardEventTypesMatchSharedContractsCatalog(t *testing.T) {
	want := []string{
		"pre_bash_internal_script",
		"pre_commit_bakfiles",
		"pre_commit_script_modes",
		"pre_commit_typechange",
		"pre_write_correction_limit",
		"pre_write_state_json",
		"pre_write_verdict",
		"stop_ideation_completeness",
		"stop_summary_validation",
		"stop_work_check",
	}
	got := loadYAMLEventTypes(t)
	sort.Strings(got)
	if !stringSlicesEqual(got, want) {
		t.Errorf("event_types[] mismatch:\n got  %v\n want %v", got, want)
	}
}

// loadYAMLEventTypes reads schemas/blocker-event.yaml and returns the
// event_types[].name values. The path is resolved via
// candidateTaxonomyPaths-style fallback so the test runs from `go test`
// without chdir gymnastics.
func loadYAMLEventTypes(t *testing.T) []string {
	t.Helper()
	path := findBlockerEventYAML(t)
	payload, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	var doc struct {
		EventTypes []struct {
			Name string `yaml:"name"`
		} `yaml:"event_types"`
	}
	if err := yaml.Unmarshal(payload, &doc); err != nil {
		t.Fatalf("parse %s: %v", path, err)
	}
	out := make([]string, 0, len(doc.EventTypes))
	for _, e := range doc.EventTypes {
		out = append(out, e.Name)
	}
	return out
}

// findBlockerEventYAML mirrors the candidateTaxonomyPaths fallback:
// FURROW_TAXONOMY_PATH is honored only when set to a known sibling root,
// otherwise walk up from the source root.
func findBlockerEventYAML(t *testing.T) string {
	t.Helper()
	if root, ok := moduleSourceRoot(); ok {
		path := filepath.Join(root, "schemas", "blocker-event.yaml")
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}
	if root, err := findFurrowRoot(); err == nil {
		path := filepath.Join(root, "schemas", "blocker-event.yaml")
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}
	t.Fatal("could not locate schemas/blocker-event.yaml")
	return ""
}

// TestGuard_PerCategoryCoverage exercises at least one code per blocker
// category that is reachable through guardHandlers. AC4: covers
// state-mutation, gate, scaffold, summary, ideation.
func TestGuard_PerCategoryCoverage(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	cases := []struct {
		name      string
		eventType string
		evt       NormalizedEvent
		wantCodes []string
	}{
		{
			name:      "state-mutation/state_json_direct_write",
			eventType: "pre_write_state_json",
			evt: NormalizedEvent{
				TargetPath: ".furrow/rows/foo/state.json",
				Payload: map[string]any{
					"target_path": ".furrow/rows/foo/state.json",
				},
			},
			wantCodes: []string{"state_json_direct_write"},
		},
		{
			name:      "gate/verdict_direct_write",
			eventType: "pre_write_verdict",
			evt: NormalizedEvent{
				Payload: map[string]any{
					"target_path": ".furrow/rows/foo/gate-verdicts/plan-to-spec.json",
				},
			},
			wantCodes: []string{"verdict_direct_write"},
		},
		{
			name:      "scaffold/script_guard_internal_invocation",
			eventType: "pre_bash_internal_script",
			evt: NormalizedEvent{
				Payload: map[string]any{
					"command": "bash bin/frw.d/scripts/update-state.sh",
				},
			},
			wantCodes: []string{"script_guard_internal_invocation"},
		},
		{
			name:      "scaffold/script_guard_NOT_triggered_by_sh_n",
			eventType: "pre_bash_internal_script",
			evt: NormalizedEvent{
				Payload: map[string]any{
					"command": "sh -n bin/frw.d/scripts/update-state.sh",
				},
			},
			wantCodes: nil,
		},
		{
			name:      "scaffold/script_guard_NOT_triggered_in_quoted_string",
			eventType: "pre_bash_internal_script",
			evt: NormalizedEvent{
				Payload: map[string]any{
					"command": "git commit -m 'do not run bin/frw.d/scripts/foo.sh directly'",
				},
			},
			wantCodes: nil,
		},
		{
			name:      "scaffold/precommit_install_artifact_staged",
			eventType: "pre_commit_bakfiles",
			evt: NormalizedEvent{
				Payload: map[string]any{
					"staged_paths": []any{"bin/frw.bak", "README.md", ".claude/rules/state-guard.bak"},
				},
			},
			wantCodes: []string{"precommit_install_artifact_staged", "precommit_install_artifact_staged"},
		},
		{
			name:      "scaffold/precommit_typechange_to_symlink",
			eventType: "pre_commit_typechange",
			evt: NormalizedEvent{
				Payload: map[string]any{
					"typechange_entries": []any{
						map[string]any{"path": "bin/alm", "new_mode": "120000", "status": "T"},
						map[string]any{"path": "README.md", "new_mode": "120000", "status": "T"},
					},
				},
			},
			wantCodes: []string{"precommit_typechange_to_symlink"},
		},
		{
			name:      "scaffold/precommit_script_mode_invalid",
			eventType: "pre_commit_script_modes",
			evt: NormalizedEvent{
				Payload: map[string]any{
					"script_modes": []any{
						map[string]any{"path": "bin/frw.d/scripts/update-state.sh", "mode": "100644"},
						map[string]any{"path": "bin/frw.d/scripts/other.sh", "mode": "100755"},
					},
				},
			},
			wantCodes: []string{"precommit_script_mode_invalid"},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			envelopes, err := Guard(tc.eventType, tc.evt)
			if err != nil {
				t.Fatalf("Guard(%q): unexpected error: %v", tc.eventType, err)
			}
			gotCodes := make([]string, 0, len(envelopes))
			for _, env := range envelopes {
				gotCodes = append(gotCodes, env.Code)
			}
			if !stringSlicesEqual(gotCodes, tc.wantCodes) {
				t.Errorf("Guard(%q) codes = %v, want %v", tc.eventType, gotCodes, tc.wantCodes)
			}
		})
	}
}

// TestGuard_NoTrigger_ReturnsEmpty asserts the clean-pass path emits
// nil/empty (which marshals to []) and not an error.
func TestGuard_NoTrigger_ReturnsEmpty(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	envelopes, err := Guard("pre_write_state_json", NormalizedEvent{
		Payload: map[string]any{"target_path": "README.md"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(envelopes) != 0 {
		t.Errorf("expected empty envelopes for non-state.json path, got %v", envelopes)
	}
}

// TestGuard_UnknownEventType_ReturnsError asserts AC3 invocation-error
// path and ErrUnknownEventType wrapping.
func TestGuard_UnknownEventType_ReturnsError(t *testing.T) {
	envelopes, err := Guard("not_a_real_type", NormalizedEvent{})
	if err == nil {
		t.Fatal("expected error for unknown event type, got nil")
	}
	if !errors.Is(err, ErrUnknownEventType) {
		t.Errorf("expected ErrUnknownEventType, got %v", err)
	}
	if envelopes != nil {
		t.Errorf("expected nil envelopes on error, got %v", envelopes)
	}
}

// TestGuard_PreBashInternalScript_MissingPayload_ReturnsError asserts
// that handlers signal invocation errors when required keys are absent.
func TestGuard_PreBashInternalScript_MissingPayload_ReturnsError(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	envelopes, err := Guard("pre_bash_internal_script", NormalizedEvent{
		Payload: map[string]any{},
	})
	if err == nil {
		t.Fatal("expected error for missing required key, got nil")
	}
	if !strings.Contains(err.Error(), "command") {
		t.Errorf("error should name the missing key 'command', got: %v", err)
	}
	if envelopes != nil {
		t.Errorf("expected nil envelopes on error, got %v", envelopes)
	}
}

// TestGuard_StopIdeationCompleteness_MissingFields_Emits asserts
// AC4 (ideation category) and verifies placeholder interpolation.
func TestGuard_StopIdeationCompleteness_MissingFields_Emits(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	dir := t.TempDir()
	defPath := filepath.Join(dir, "definition.yaml")
	mustWrite(t, defPath, "objective: \"\"\ngate_policy: supervised\n")

	envelopes, err := Guard("stop_ideation_completeness", NormalizedEvent{
		Payload: map[string]any{
			"row":             "fixture",
			"definition_path": defPath,
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(envelopes) != 1 {
		t.Fatalf("expected 1 envelope, got %d (%v)", len(envelopes), envelopes)
	}
	if envelopes[0].Code != "ideation_incomplete_definition_fields" {
		t.Errorf("expected ideation_incomplete_definition_fields, got %q", envelopes[0].Code)
	}
	if !strings.Contains(envelopes[0].Message, "objective") {
		t.Errorf("message should name the missing 'objective' field, got %q", envelopes[0].Message)
	}
	// No unfilled placeholders should leak.
	if strings.Contains(envelopes[0].Message, "{") {
		t.Errorf("message contains an unfilled placeholder: %q", envelopes[0].Message)
	}
}

// TestGuard_StopIdeationCompleteness_AutonomousSkips asserts the skip
// rule when gate_policy is autonomous.
func TestGuard_StopIdeationCompleteness_AutonomousSkips(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	envelopes, err := Guard("stop_ideation_completeness", NormalizedEvent{
		Payload: map[string]any{
			"row":         "fixture",
			"gate_policy": "autonomous",
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(envelopes) != 0 {
		t.Errorf("autonomous policy should skip, got %v", envelopes)
	}
}

// TestGuard_StopSummaryValidation_MultiEmit covers the summary category
// and verifies the multi-emit path (one envelope per missing section).
func TestGuard_StopSummaryValidation_MultiEmit(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	dir := t.TempDir()
	summaryPath := filepath.Join(dir, "summary.md")
	// Only Task and Current State present; the other 5 sections are
	// missing → 5 missing envelopes plus 0 empty (sections not present
	// don't produce empty envelopes).
	mustWrite(t, summaryPath, "## Task\n\nA task.\n\n## Current State\n\nIn progress.\n")

	envelopes, err := Guard("stop_summary_validation", NormalizedEvent{
		Payload: map[string]any{
			"row":          "fixture",
			"summary_path": summaryPath,
			"step":         "implement",
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(envelopes) != 5 {
		t.Fatalf("expected 5 missing-section envelopes, got %d (%v)", len(envelopes), envelopes)
	}
	for _, env := range envelopes {
		if env.Code != "summary_section_missing" {
			t.Errorf("expected summary_section_missing, got %q", env.Code)
		}
	}
}

// TestGuard_StopSummaryValidation_PrecheckedSkips asserts the skip rule
// when the upstream gate decided_by == "prechecked".
func TestGuard_StopSummaryValidation_PrecheckedSkips(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	envelopes, err := Guard("stop_summary_validation", NormalizedEvent{
		Payload: map[string]any{
			"row":             "fixture",
			"last_decided_by": "prechecked",
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(envelopes) != 0 {
		t.Errorf("prechecked should skip, got %v", envelopes)
	}
}

// TestGuard_StopWorkCheck_StateValidationFailed covers the warn-severity
// state-mutation category.
func TestGuard_StopWorkCheck_StateValidationFailed(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	envelopes, err := Guard("stop_work_check", NormalizedEvent{
		Payload: map[string]any{
			"row":                 "fixture",
			"state_validation_ok": false,
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(envelopes) == 0 {
		t.Fatal("expected at least one envelope")
	}
	if envelopes[0].Code != "state_validation_failed_warn" {
		t.Errorf("expected state_validation_failed_warn first, got %q", envelopes[0].Code)
	}
	if envelopes[0].Severity != "warn" {
		t.Errorf("expected warn severity, got %q", envelopes[0].Severity)
	}
}

// TestRunGuard_StdoutAlwaysArray runs the App-level CLI wrapper end-to-end
// to confirm:
//   - Stdout is a JSON array, never a bare object.
//   - Empty result is `[]`.
//   - Single-emit is a single-element array.
//   - Exit codes are 0 for clean-run / 1 for invocation-error.
func TestRunGuard_StdoutAlwaysArray(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	cases := []struct {
		name     string
		args     []string
		stdin    string
		wantExit int
		wantLen  int // -1 means stdout is not parsed as an array
	}{
		{
			name:     "no_trigger_empty_array",
			args:     []string{"guard", "pre_write_state_json"},
			stdin:    `{"event_type":"pre_write_state_json","payload":{"target_path":"README.md"}}`,
			wantExit: 0,
			wantLen:  0,
		},
		{
			name:     "single_emit_one_element_array",
			args:     []string{"guard", "pre_write_state_json"},
			stdin:    `{"event_type":"pre_write_state_json","payload":{"target_path":".furrow/rows/x/state.json"}}`,
			wantExit: 0,
			wantLen:  1,
		},
		{
			name:     "unknown_event_type_exit_1",
			args:     []string{"guard", "definitely_not_a_type"},
			stdin:    `{}`,
			wantExit: 1,
			wantLen:  -1,
		},
		{
			name:     "event_type_arg_mismatch_exit_1",
			args:     []string{"guard", "pre_write_state_json"},
			stdin:    `{"event_type":"pre_write_verdict","payload":{}}`,
			wantExit: 1,
			wantLen:  -1,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			app := NewWithStdin(&stdout, &stderr, strings.NewReader(tc.stdin))
			exit := app.Run(tc.args)
			if exit != tc.wantExit {
				t.Errorf("exit = %d, want %d (stderr=%q)", exit, tc.wantExit, stderr.String())
			}
			// Per shared-contracts §C2: NEVER exit 2.
			if exit == 2 {
				t.Errorf("furrow guard must NEVER exit 2 (specs/shared-contracts.md §C2)")
			}
			if tc.wantLen < 0 {
				return
			}
			var arr []BlockerEnvelope
			if err := json.Unmarshal(stdout.Bytes(), &arr); err != nil {
				t.Fatalf("stdout is not a JSON array: %v\nstdout=%q", err, stdout.String())
			}
			if len(arr) != tc.wantLen {
				t.Errorf("envelope count = %d, want %d (stdout=%q)", len(arr), tc.wantLen, stdout.String())
			}
		})
	}
}

// TestShellStripDataRegions covers the awk-port behavior on the shapes
// most likely to appear in real bash commands. Drift here would silently
// break script-guard parity with the shell hook.
func TestShellStripDataRegions(t *testing.T) {
	cases := []struct {
		name string
		in   string
		// We assert structural properties (does the result still contain
		// the data substring?) rather than exact byte equality, because
		// the awk port replaces stripped regions with spaces and exact
		// whitespace is not load-bearing.
		mustContainFrwd  bool
		mustNotContainSh string
	}{
		{
			name:            "single_quoted_strips",
			in:              "echo 'bin/frw.d/scripts/foo.sh'",
			mustContainFrwd: false,
		},
		{
			name:            "double_quoted_strips",
			in:              `echo "bin/frw.d/scripts/foo.sh"`,
			mustContainFrwd: false,
		},
		{
			name:            "comment_strips",
			in:              "echo hi # bin/frw.d/scripts/foo.sh",
			mustContainFrwd: false,
		},
		{
			name:            "naked_invocation_preserved",
			in:              "bin/frw.d/scripts/foo.sh arg",
			mustContainFrwd: true,
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := shellStripDataRegions(tc.in)
			has := strings.Contains(got, "frw.d/")
			if has != tc.mustContainFrwd {
				t.Errorf("shellStripDataRegions(%q) = %q\n contains frw.d/? got=%v want=%v",
					tc.in, got, has, tc.mustContainFrwd)
			}
		})
	}
}

// Ensure runJSONCommand / mustWrite stay referenced from this test file
// when other tests are skipped — both are defined in app_test.go and
// reused above.
var _ = runJSONCommand
