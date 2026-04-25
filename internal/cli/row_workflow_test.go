package cli

import (
	"path/filepath"
	"testing"
)

// makeMinimalState returns a state map that satisfies the review+completed preconditions
// for rowBlockers (no pending actions, no seed issues by default).
func makeMinimalState(step, stepStatus string) map[string]any {
	return map[string]any{
		"archived_at":          nil,
		"step":                 step,
		"step_status":          stepStatus,
		"pending_user_actions": []any{},
		"gates":                []any{},
	}
}

// makeMissingRecordSeed returns a seed surface that is in "missing" state (no blocker generated
// by rowBlockers for the "missing" state — only "missing_record" triggers a blocker).
func makeOKSeed() map[string]any {
	return map[string]any{
		"state": "linked",
	}
}

// writeDefinitionYAML writes a definition.yaml for a row in the test furrow root.
func writeDefinitionYAML(t *testing.T, root, rowName, content string) {
	t.Helper()
	mustMkdirAll(t, filepath.Join(root, ".furrow", "rows", rowName))
	mustWrite(t, filepath.Join(root, ".furrow", "rows", rowName, "definition.yaml"), content)
}

// TestRowBlockers_Supersedence is a table-driven unit test covering scenarios A, B, C, E, F.
func TestRowBlockers_Supersedence(t *testing.T) {
	cases := []struct {
		name                  string // Scenario label
		definitionSupersedes  map[string]any
		supersedesConfirmed   string
		wantBlockerCode       string // non-empty → expect this blocker code
		wantNoBlockerCode     string // non-empty → expect this blocker code to be ABSENT
		wantMsgContains       []string
	}{
		{
			// Scenario A: supersedes block present, flag missing → blocker
			name: "A-missing-flag",
			definitionSupersedes: map[string]any{
				"commit": "e4adef5",
				"row":    "pi-step-ceremony-and-artifact-enforcement",
			},
			supersedesConfirmed: "",
			wantBlockerCode:     "supersedence_evidence_missing",
			wantMsgContains:     []string{"e4adef5", "pi-step-ceremony-and-artifact-enforcement"},
		},
		{
			// Scenario B: wrong commit → blocker naming expected vs actual
			name: "B-mismatched-commit",
			definitionSupersedes: map[string]any{
				"commit": "e4adef5",
				"row":    "pi-step-ceremony-and-artifact-enforcement",
			},
			supersedesConfirmed: "badc0de:pi-step-ceremony-and-artifact-enforcement",
			wantBlockerCode:     "supersedence_evidence_missing",
			wantMsgContains:     []string{"e4adef5", "badc0de"},
		},
		{
			// Scenario C: wrong row → blocker naming expected vs actual
			name: "C-mismatched-row",
			definitionSupersedes: map[string]any{
				"commit": "e4adef5",
				"row":    "pi-step-ceremony-and-artifact-enforcement",
			},
			supersedesConfirmed: "e4adef5:wrong-row-name",
			wantBlockerCode:     "supersedence_evidence_missing",
			wantMsgContains:     []string{"pi-step-ceremony-and-artifact-enforcement", "wrong-row-name"},
		},
		{
			// Scenario E: matching flag → no supersedence blocker
			name: "E-matching-flag",
			definitionSupersedes: map[string]any{
				"commit": "e4adef5",
				"row":    "pi-step-ceremony-and-artifact-enforcement",
			},
			supersedesConfirmed: "e4adef5:pi-step-ceremony-and-artifact-enforcement",
			wantNoBlockerCode:   "supersedence_evidence_missing",
		},
		{
			// Scenario F (AC-Guard): no supersedes block at all → blocker must NOT fire
			name:                 "F-no-supersedes-block",
			definitionSupersedes: nil,
			supersedesConfirmed:  "",
			wantNoBlockerCode:    "supersedence_evidence_missing",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			state := makeMinimalState("implement", "not_started")
			seed := makeOKSeed()
			opts := rowBlockersOpts{
				SupersedesConfirmed:  tc.supersedesConfirmed,
				DefinitionSupersedes: tc.definitionSupersedes,
			}
			blockers := rowBlockers(state, seed, nil, opts)

			if tc.wantBlockerCode != "" {
				found := false
				var foundMsg string
				for _, b := range blockers {
					if b["code"] == tc.wantBlockerCode {
						found = true
						foundMsg, _ = b["message"].(string)
						break
					}
				}
				if !found {
					t.Errorf("expected blocker %q not found; blockers=%v", tc.wantBlockerCode, blockers)
				} else {
					for _, substr := range tc.wantMsgContains {
						if !containsString(foundMsg, substr) {
							t.Errorf("blocker message %q missing expected substring %q", foundMsg, substr)
						}
					}
				}
			}

			if tc.wantNoBlockerCode != "" {
				for _, b := range blockers {
					if b["code"] == tc.wantNoBlockerCode {
						t.Errorf("unexpected blocker %q found; blockers=%v", tc.wantNoBlockerCode, blockers)
					}
				}
			}
		})
	}
}

// containsString is a simple substring helper for test assertions.
func containsString(s, substr string) bool {
	return len(substr) == 0 || (len(s) >= len(substr) && func() bool {
		for i := 0; i <= len(s)-len(substr); i++ {
			if s[i:i+len(substr)] == substr {
				return true
			}
		}
		return false
	}())
}
