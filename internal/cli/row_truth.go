package cli

import (
	"strings"
)

func rowTruthGatesRequired(state map[string]any) bool {
	if numericInt(state["truth_gates_version"]) > 0 {
		return true
	}
	if required, ok := state["truth_gates_required"].(bool); ok && required {
		return true
	}
	if audit, ok := state["retrospective_audit"].(bool); ok && audit {
		return true
	}
	return false
}

func truthGateArtifactsForRow(root, rowName string, state map[string]any) []map[string]any {
	rowDir := rowDirFor(root, rowName)
	specs := []rowArtifactSpec{
		artifactSpec(rowDir, "ask-analysis", "ask-analysis.md", true, true),
		artifactSpec(rowDir, "test-plan", "test-plan.md", true, true),
		artifactSpec(rowDir, "completion-check", "completion-check.md", true, true),
	}
	return materializeRowArtifacts(state, specs)
}

func validateAskAnalysisArtifact(content string) []artifactValidationFinding {
	return validateMarkdownSections(content, map[string]string{
		"Literal Ask":                        "literal ask",
		"Real Ask":                           "real ask",
		"Implied Obligations":                "implied obligations",
		"Non-Deferrable Work":                "non-deferrable work",
		"Deferrable Work":                    "deferrable work",
		"Runtime Surfaces Affected":          "runtime surfaces affected",
		"Spirit-Of-Law Completion Statement": "spirit-of-law completion statement",
	})
}

func validateTestPlanArtifact(content string) []artifactValidationFinding {
	findings := validateMarkdownSections(content, map[string]string{
		"Claims Under Test":                          "claims under test",
		"Unit Tests":                                 "unit tests",
		"Integration Tests":                          "integration tests",
		"Runtime-Loaded Entrypoint Tests":            "runtime-loaded entrypoint tests",
		"Negative Tests":                             "negative tests",
		"Parity Tests":                               "parity tests",
		"Skips And Why They Do Not Weaken The Claim": "skips and rationale",
		"Manual Dogfood Path":                        "manual dogfood path",
	})
	sections := markdownSections(content)
	lowerContent := strings.ToLower(content)
	runtimeClaim := strings.Contains(lowerContent, "runtime") || strings.Contains(lowerContent, "entrypoint") || strings.Contains(lowerContent, "cli") || strings.Contains(lowerContent, "adapter")
	runtimeTests := strings.ToLower(sections["Runtime-Loaded Entrypoint Tests"])
	if runtimeClaim && !sectionHasSubstantiveContent(runtimeTests) && !strings.Contains(lowerContent, "downgrad") {
		findings = append(findings, artifactValidationFinding{
			Code:     "test_plan_runtime_entrypoint_missing",
			Severity: "error",
			Message:  "runtime behavior claims require a runtime-loaded entrypoint test or an explicit downgraded runtime claim",
		})
	}
	findings = append(findings, validateClaimSurfaceParity(sections["Parity Tests"])...)
	return findings
}

func validateClaimSurfaceParity(body string) []artifactValidationFinding {
	lower := strings.ToLower(body)
	if strings.Contains(lower, "skip") && strings.Contains(lower, "pass") {
		return []artifactValidationFinding{{
			Code:     "claim_surface_parity_skip_as_pass",
			Severity: "error",
			Message:  "claim-surface parity cannot treat skipped claimed behavior as a pass",
		}}
	}
	if (strings.Contains(lower, "same behavior") || strings.Contains(lower, "equivalent")) && (strings.Contains(lower, "missing") || strings.Contains(lower, "not loaded")) {
		return []artifactValidationFinding{{
			Code:     "claim_surface_parity_missing_surface",
			Severity: "error",
			Message:  "claim-surface parity cannot pass when an equivalent claimed surface is missing or not runtime-loaded",
		}}
	}
	return nil
}

func validateCompletionCheckArtifact(content string) []artifactValidationFinding {
	findings := validateMarkdownSections(content, map[string]string{
		"Original Real Ask":                     "original real ask",
		"What Is Now True":                      "what is now true",
		"What Is Only Structurally Present":     "what is only structurally present",
		"Deferred Work":                         "deferred work",
		"Does Any Deferral Block The Real Ask?": "deferral truth impact",
		"Adapter/Backend Boundary Check":        "adapter/backend boundary check",
		"Help/Docs/Reference Truth Check":       "help/docs/reference truth check",
		"Final Verdict":                         "final verdict",
	})
	verdict := completionVerdict(content)
	switch verdict {
	case "complete":
	case "incomplete":
		findings = append(findings, artifactValidationFinding{Code: "completion_verdict_incomplete", Severity: "error", Message: "completion-check.md final verdict is incomplete"})
	case "complete-with-downgraded-claim":
		if !strings.Contains(strings.ToLower(content), "downgrad") {
			findings = append(findings, artifactValidationFinding{Code: "completion_downgrade_evidence_missing", Severity: "error", Message: "complete-with-downgraded-claim requires explicit downgrade evidence in the completion check"})
		}
	default:
		findings = append(findings, artifactValidationFinding{Code: "completion_verdict_invalid", Severity: "error", Message: "completion-check.md final verdict must be complete, incomplete, or complete-with-downgraded-claim"})
	}
	return findings
}

func completionVerdict(content string) string {
	body := strings.ToLower(markdownSections(content)["Final Verdict"])
	for _, allowed := range []string{"complete-with-downgraded-claim", "incomplete", "complete"} {
		if strings.Contains(body, allowed) {
			return allowed
		}
	}
	return ""
}

func findArtifactByID(artifacts []map[string]any, id string) map[string]any {
	for _, artifact := range artifacts {
		if getStringDefault(artifact, "id", "") == id {
			return artifact
		}
	}
	return nil
}
