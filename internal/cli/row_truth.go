package cli

import (
	"fmt"
	"strings"

	yaml "gopkg.in/yaml.v3"
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
		artifactSpec(rowDir, "claim-surfaces", "claim-surfaces.yaml", true, true),
		artifactSpec(rowDir, "completion-check", "completion-check.md", true, true),
		artifactSpec(rowDir, "follow-ups", "follow-ups.yaml", false, true),
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

func validateClaimSurfacesArtifact(content string) []artifactValidationFinding {
	var doc map[string]any
	if err := yaml.Unmarshal([]byte(content), &doc); err != nil {
		return []artifactValidationFinding{{Code: "claim_surfaces_yaml_invalid", Severity: "error", Message: "claim-surfaces.yaml is not valid YAML"}}
	}
	rawClaims, ok := asSlice(doc["claim_surfaces"])
	if !ok {
		rawClaims, ok = asSlice(doc["claim-surfaces"])
	}
	if !ok || len(rawClaims) == 0 {
		return []artifactValidationFinding{{Code: "claim_surfaces_missing", Severity: "error", Message: "claim-surfaces.yaml must list at least one claim surface entry"}}
	}

	findings := make([]artifactValidationFinding, 0)
	for i, rawClaim := range rawClaims {
		claim, ok := rawClaim.(map[string]any)
		if !ok {
			findings = append(findings, artifactValidationFinding{Code: "claim_surface_invalid", Severity: "error", Message: fmt.Sprintf("claim surface %d is not an object", i+1)})
			continue
		}
		name := strings.TrimSpace(getStringDefault(claim, "name", ""))
		statement := strings.TrimSpace(getStringDefault(claim, "claim", ""))
		if !isSubstantiveText(name) {
			findings = append(findings, artifactValidationFinding{Code: "claim_surface_name_missing", Severity: "error", Message: fmt.Sprintf("claim surface %d must have a substantive name", i+1)})
		}
		if !isSubstantiveText(statement) {
			findings = append(findings, artifactValidationFinding{Code: "claim_surface_claim_missing", Severity: "error", Message: fmt.Sprintf("claim surface %q must have a substantive claim", nameOrFallback(name, i))})
		}
		rawSurfaces, ok := asSlice(claim["surfaces"])
		if !ok || len(rawSurfaces) == 0 {
			findings = append(findings, artifactValidationFinding{Code: "claim_surface_surfaces_missing", Severity: "error", Message: fmt.Sprintf("claim surface %q must list concrete surfaces", nameOrFallback(name, i))})
			continue
		}
		passingEquivalentSurfaces := 0
		for j, rawSurface := range rawSurfaces {
			surface, ok := rawSurface.(map[string]any)
			if !ok {
				findings = append(findings, artifactValidationFinding{Code: "claim_surface_entry_invalid", Severity: "error", Message: fmt.Sprintf("surface %d for claim %q is not an object", j+1, nameOrFallback(name, i))})
				continue
			}
			surfaceName := strings.TrimSpace(getStringDefault(surface, "name", ""))
			status := strings.TrimSpace(getStringDefault(surface, "status", ""))
			evidencePath := strings.TrimSpace(getStringDefault(surface, "evidence_path", ""))
			evidenceType := strings.TrimSpace(getStringDefault(surface, "evidence_type", ""))
			if !isSubstantiveText(surfaceName) || !isSubstantiveText(evidencePath) || !isSubstantiveText(evidenceType) || status == "" {
				findings = append(findings, artifactValidationFinding{Code: "claim_surface_evidence_incomplete", Severity: "error", Message: fmt.Sprintf("surface %d for claim %q must include name, status, evidence_type, and evidence_path", j+1, nameOrFallback(name, i))})
				continue
			}
			switch status {
			case "passed", "downgraded", "not_claimed":
			case "skipped", "missing", "mocked_only", "structural_only":
				findings = append(findings, artifactValidationFinding{Code: "claim_surface_not_evidence", Severity: "error", Message: fmt.Sprintf("surface %q for claim %q cannot count %s as completion evidence", surfaceName, nameOrFallback(name, i), status)})
			default:
				findings = append(findings, artifactValidationFinding{Code: "claim_surface_status_invalid", Severity: "error", Message: fmt.Sprintf("surface %q for claim %q has invalid status %q", surfaceName, nameOrFallback(name, i), status)})
			}
			if status == "passed" {
				passingEquivalentSurfaces++
			}
		}
		parityClaim := boolOrStringTrue(claim["equivalence_claim"])
		if parityClaim && passingEquivalentSurfaces < len(rawSurfaces) {
			if !strings.Contains(strings.ToLower(statement), "downgrad") {
				findings = append(findings, artifactValidationFinding{Code: "claim_surface_equivalence_not_proven", Severity: "error", Message: fmt.Sprintf("equivalence claim %q must pass every claimed surface or explicitly downgrade the claim", nameOrFallback(name, i))})
			}
		}
	}
	return findings
}

func boolOrStringTrue(value any) bool {
	switch typed := value.(type) {
	case bool:
		return typed
	case string:
		return strings.EqualFold(strings.TrimSpace(typed), "true")
	default:
		return false
	}
}

func validateFollowUpsArtifact(content string) []artifactValidationFinding {
	var doc map[string]any
	if err := yaml.Unmarshal([]byte(content), &doc); err != nil {
		return []artifactValidationFinding{{Code: "follow_ups_yaml_invalid", Severity: "error", Message: "follow-ups.yaml is not valid YAML"}}
	}
	rawItems, ok := asSlice(doc["follow_ups"])
	if !ok {
		rawItems, ok = asSlice(doc["follow-ups"])
	}
	if !ok {
		return []artifactValidationFinding{{Code: "follow_ups_missing", Severity: "error", Message: "follow-ups.yaml must contain a follow_ups list"}}
	}
	for i, raw := range rawItems {
		item, ok := raw.(map[string]any)
		if !ok {
			return []artifactValidationFinding{{Code: "follow_up_invalid", Severity: "error", Message: fmt.Sprintf("follow-up %d is not an object", i+1)}}
		}
		if strings.TrimSpace(getStringDefault(item, "claim_affected", "")) == "" ||
			strings.TrimSpace(getStringDefault(item, "deferral_class", "")) == "" ||
			strings.TrimSpace(getStringDefault(item, "truth_impact", "")) == "" ||
			strings.TrimSpace(getStringDefault(item, "defer_reason", "")) == "" ||
			strings.TrimSpace(getStringDefault(item, "graduation_trigger", "")) == "" {
			return []artifactValidationFinding{{Code: "follow_up_classification_incomplete", Severity: "error", Message: fmt.Sprintf("follow-up %d must include claim_affected, deferral_class, truth_impact, defer_reason, and graduation_trigger", i+1)}}
		}
	}
	return nil
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
