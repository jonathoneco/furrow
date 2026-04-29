package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	yaml "gopkg.in/yaml.v3"
)

type artifactValidationFinding struct {
	Code     string `json:"code"`
	Severity string `json:"severity"`
	Message  string `json:"message"`
}

func artifactValidationMap(status, summary string, findings []artifactValidationFinding) map[string]any {
	findingMaps := make([]map[string]any, 0, len(findings))
	blocking := 0
	warning := 0
	for _, finding := range findings {
		if finding.Severity == "error" {
			blocking++
		}
		if finding.Severity == "warning" {
			warning++
		}
		findingMaps = append(findingMaps, map[string]any{
			"code":     finding.Code,
			"severity": finding.Severity,
			"message":  finding.Message,
		})
	}
	return map[string]any{
		"status":         status,
		"summary":        summary,
		"finding_count":  len(findings),
		"blocking_count": blocking,
		"warning_count":  warning,
		"findings":       findingMaps,
	}
}

// blocker resolves code against the loaded taxonomy and returns a map shaped
// as the canonical six-field BlockerEnvelope plus an optional sibling
// "details" map for non-interpolated context. The taxonomy is the single
// source of truth for severity, remediation_hint, and confirmation_path —
// callers no longer pass severity/category/prose; those are sourced from
// schemas/blocker-taxonomy.yaml via tx.EmitBlocker.
//
// Migration discipline (expand-contract single-point migration target per
// research/status-callers-and-pi-shim.md §A and spec §1.3): every emit-site
// in rowBlockers passes its placeholder values via interp and any additional
// adapter-side detail context via details. Detail keys are NOT merged into
// the envelope — they live on a sibling "details" field so the canonical
// envelope stays at exactly six fields.
//
// If tx is nil (taxonomy failed to load) or code is unregistered, we fall
// through to tx.EmitBlocker's unregistered-code fallback (production) or
// panic (test mode) so callers see the misuse immediately.
func blocker(tx *Taxonomy, code string, interp map[string]string, details map[string]any) map[string]any {
	env := tx.EmitBlocker(code, interp)
	entry := map[string]any{
		"code":              env.Code,
		"category":          env.Category,
		"severity":          env.Severity,
		"message":           env.Message,
		"remediation_hint":  env.RemediationHint,
		"confirmation_path": env.ConfirmationPath,
	}
	if len(details) > 0 {
		entry["details"] = details
	}
	return entry
}

func validateArtifact(state map[string]any, artifact map[string]any) map[string]any {
	exists, _ := artifact["exists"].(bool)
	if !exists {
		return artifactValidationMap("missing", "artifact is missing", nil)
	}

	path, _ := artifact["path"].(string)
	label, _ := artifact["label"].(string)
	payload, err := os.ReadFile(path)
	if err != nil {
		return artifactValidationMap("fail", "artifact could not be read", []artifactValidationFinding{{
			Code:     "artifact_unreadable",
			Severity: "error",
			Message:  fmt.Sprintf("could not read %s", label),
		}})
	}

	findings := make([]artifactValidationFinding, 0)
	content := string(payload)
	if strings.Contains(content, scaffoldMarker) {
		findings = append(findings, artifactValidationFinding{
			Code:     "artifact_scaffold_incomplete",
			Severity: "error",
			Message:  fmt.Sprintf("%s still contains the incomplete scaffold marker", label),
		})
	}
	findings = append(findings, artifactSpecificFindings(state, artifact, content)...)

	status := "pass"
	summary := "validation passed"
	for _, finding := range findings {
		if finding.Severity == "error" {
			status = "fail"
			summary = "validation failed"
			break
		}
		if finding.Severity == "warning" {
			status = "warn"
			summary = "validation has warnings"
		}
	}
	return artifactValidationMap(status, summary, findings)
}

func artifactSpecificFindings(state map[string]any, artifact map[string]any, content string) []artifactValidationFinding {
	id, _ := artifact["id"].(string)
	switch id {
	case "definition":
		return validateDefinitionArtifact(content)
	case "research":
		return validateMarkdownSections(content, map[string]string{
			"Questions":         "research questions",
			"Findings":          "research findings",
			"Sources Consulted": "sources consulted",
		})
	case "implementation-plan":
		return validateMarkdownSections(content, map[string]string{
			"Objective":    "plan objective",
			"Planned work": "planned work",
		})
	case "spec":
		return validateMarkdownSections(content, map[string]string{
			"Scope":               "spec scope",
			"Acceptance Criteria": "spec acceptance criteria",
			"Verification":        "spec verification",
		})
	case "plan":
		return validatePlanJSONArtifact(content)
	case "ask-analysis":
		return validateAskAnalysisArtifact(content)
	case "test-plan":
		return validateTestPlanArtifact(content)
	case "claim-surfaces":
		return validateClaimSurfacesArtifact(content)
	case "completion-check":
		return validateCompletionCheckArtifact(content)
	case "follow-ups":
		return validateFollowUpsArtifact(content)
	default:
		if strings.HasPrefix(id, "review:") {
			return validateReviewArtifact(state, content, strings.TrimPrefix(id, "review:"))
		}
		return nil
	}
}

func validateDefinitionArtifact(content string) []artifactValidationFinding {
	var doc map[string]any
	if err := yaml.Unmarshal([]byte(content), &doc); err != nil {
		return []artifactValidationFinding{{Code: "definition_yaml_invalid", Severity: "error", Message: "definition.yaml is not valid YAML"}}
	}

	findings := make([]artifactValidationFinding, 0)
	objective, _ := doc["objective"].(string)
	if !isSubstantiveText(objective) {
		findings = append(findings, artifactValidationFinding{Code: "definition_objective_missing", Severity: "error", Message: "definition.yaml must contain a substantive objective"})
	}

	deliverables, ok := doc["deliverables"].([]any)
	if !ok || len(deliverables) == 0 {
		findings = append(findings, artifactValidationFinding{Code: "definition_deliverables_missing", Severity: "error", Message: "definition.yaml must list at least one deliverable"})
		return findings
	}

	for i, raw := range deliverables {
		deliverable, ok := raw.(map[string]any)
		if !ok {
			findings = append(findings, artifactValidationFinding{Code: "definition_deliverable_invalid", Severity: "error", Message: fmt.Sprintf("deliverable %d is not an object", i+1)})
			continue
		}
		name, _ := deliverable["name"].(string)
		if !isSubstantiveText(name) {
			findings = append(findings, artifactValidationFinding{Code: "definition_deliverable_name_missing", Severity: "error", Message: fmt.Sprintf("deliverable %d must have a substantive name", i+1)})
		}
		criteria, ok := deliverable["acceptance_criteria"].([]any)
		if !ok || len(criteria) == 0 {
			findings = append(findings, artifactValidationFinding{Code: "definition_acceptance_criteria_missing", Severity: "error", Message: fmt.Sprintf("deliverable %q must have acceptance criteria", nameOrFallback(name, i))})
			continue
		}
		substantive := 0
		for _, rawCriterion := range criteria {
			criterion, _ := rawCriterion.(string)
			if isSubstantiveText(criterion) {
				substantive++
			}
		}
		if substantive == 0 {
			findings = append(findings, artifactValidationFinding{Code: "definition_acceptance_criteria_placeholder", Severity: "error", Message: fmt.Sprintf("deliverable %q acceptance criteria are still placeholders", nameOrFallback(name, i))})
		}
	}

	if gatePolicy, _ := doc["gate_policy"].(string); gatePolicy != "" && !isValidGatePolicy(gatePolicy) {
		findings = append(findings, artifactValidationFinding{Code: "definition_gate_policy_invalid", Severity: "error", Message: fmt.Sprintf("definition.yaml gate_policy %q is invalid", gatePolicy)})
	}

	return findings
}

func validatePlanJSONArtifact(content string) []artifactValidationFinding {
	var doc map[string]any
	if err := json.Unmarshal([]byte(content), &doc); err != nil {
		return []artifactValidationFinding{{Code: "plan_json_invalid", Severity: "error", Message: "plan.json is not valid JSON"}}
	}

	findings := make([]artifactValidationFinding, 0)
	if marker, _ := doc["_furrow_scaffold"].(string); strings.TrimSpace(marker) != "" {
		findings = append(findings, artifactValidationFinding{Code: "artifact_scaffold_incomplete", Severity: "error", Message: "plan.json still contains the scaffold marker"})
	}
	waves, wavesOK := doc["waves"].([]any)
	assignments, assignmentsOK := doc["assignments"].(map[string]any)
	if (!wavesOK || len(waves) == 0) && (!assignmentsOK || len(assignments) == 0) {
		findings = append(findings, artifactValidationFinding{Code: "plan_structure_too_thin", Severity: "error", Message: "plan.json must describe at least one wave or assignment"})
	}
	return findings
}

func validateReviewArtifact(state map[string]any, content string, expectedDeliverable string) []artifactValidationFinding {
	details, err := reviewArtifactDetailsFromContent(content, expectedDeliverable)
	if err != nil {
		return []artifactValidationFinding{{Code: "review_json_invalid", Severity: "error", Message: "review artifact is not valid JSON"}}
	}

	findings := make([]artifactValidationFinding, 0)
	expectedDeliverable = strings.TrimSpace(expectedDeliverable)
	deliverable, _ := details["deliverable"].(string)
	if expectedDeliverable != "" && expectedDeliverable != "all-deliverables" {
		deliverable = strings.TrimSpace(deliverable)
		switch {
		case deliverable == "":
			findings = append(findings, artifactValidationFinding{Code: "review_deliverable_missing", Severity: "warning", Message: fmt.Sprintf("review artifact does not record its deliverable name; expected %q", expectedDeliverable)})
		case deliverable != expectedDeliverable:
			findings = append(findings, artifactValidationFinding{Code: "review_deliverable_mismatch", Severity: "error", Message: fmt.Sprintf("review artifact deliverable %q does not match expected %q", deliverable, expectedDeliverable)})
		}
	}

	phaseA, _ := details["phase_a"].(map[string]any)
	if available, _ := phaseA["available"].(bool); !available {
		findings = append(findings, artifactValidationFinding{Code: "review_phase_a_missing", Severity: "error", Message: "review artifact does not include recognizable Phase A evidence"})
	}
	phaseAVerdict, _ := phaseA["verdict"].(string)
	if phaseAVerdict == "" {
		findings = append(findings, artifactValidationFinding{Code: "review_phase_a_verdict_missing", Severity: "error", Message: "review artifact does not expose a recognizable Phase A verdict"})
	}
	if criteria, _ := phaseA["acceptance_criteria"].(map[string]any); criteria != nil {
		if unmet := numericInt(criteria["unmet"]); unmet > 0 {
			findings = append(findings, artifactValidationFinding{Code: "review_phase_a_unmet_criteria", Severity: "error", Message: fmt.Sprintf("review artifact records %d unmet Phase A acceptance criteria", unmet)})
		}
		if missingEvidence := numericInt(criteria["missing_evidence"]); missingEvidence > 0 {
			findings = append(findings, artifactValidationFinding{Code: "review_phase_a_evidence_thin", Severity: "warning", Message: fmt.Sprintf("review artifact has %d Phase A criteria without substantive evidence", missingEvidence)})
		}
	}

	phaseB, _ := details["phase_b"].(map[string]any)
	if available, _ := phaseB["available"].(bool); !available {
		findings = append(findings, artifactValidationFinding{Code: "review_phase_b_missing", Severity: "error", Message: "review artifact does not include recognizable Phase B evidence"})
	}
	phaseBVerdict, _ := phaseB["verdict"].(string)
	if phaseBVerdict == "" {
		findings = append(findings, artifactValidationFinding{Code: "review_phase_b_verdict_missing", Severity: "error", Message: "review artifact does not expose a recognizable Phase B verdict"})
	}
	if dimensions, _ := phaseB["dimensions"].(map[string]any); dimensions != nil {
		if failCount := numericInt(dimensions["fail"]); failCount > 0 && phaseBVerdict == "pass" {
			findings = append(findings, artifactValidationFinding{Code: "review_phase_b_verdict_inconsistent", Severity: "error", Message: fmt.Sprintf("review artifact reports %d failing Phase B dimensions but a passing Phase B verdict", failCount)})
		}
		if conditionalCount := numericInt(dimensions["conditional"]); conditionalCount > 0 && phaseBVerdict == "pass" {
			findings = append(findings, artifactValidationFinding{Code: "review_phase_b_verdict_inconsistent", Severity: "error", Message: fmt.Sprintf("review artifact reports %d conditional Phase B dimensions but a passing Phase B verdict", conditionalCount)})
		}
		if missingEvidence := numericInt(dimensions["missing_evidence"]); missingEvidence > 0 {
			findings = append(findings, artifactValidationFinding{Code: "review_phase_b_evidence_thin", Severity: "warning", Message: fmt.Sprintf("review artifact has %d Phase B dimensions without substantive evidence", missingEvidence)})
		}
	}

	overall, _ := details["overall"].(string)
	synthesized, _ := details["synthesized"].(map[string]any)
	override, _ := synthesized["override"].(bool)
	reasonPresent, _ := synthesized["reason_present"].(bool)
	if overall == "" {
		findings = append(findings, artifactValidationFinding{Code: "review_overall_missing", Severity: "error", Message: "review artifact does not expose an overall verdict"})
	} else if overall != "pass" {
		findings = append(findings, artifactValidationFinding{Code: "review_verdict_not_passing", Severity: "error", Message: fmt.Sprintf("review artifact verdict is %q, not pass", overall)})
	} else {
		if phaseAVerdict != "pass" {
			findings = append(findings, artifactValidationFinding{Code: "review_overall_inconsistent", Severity: "error", Message: fmt.Sprintf("review artifact overall verdict is pass even though Phase A verdict is %q", phaseAVerdict)})
		}
		if phaseBVerdict != "pass" && !(override && reasonPresent) {
			findings = append(findings, artifactValidationFinding{Code: "review_overall_inconsistent", Severity: "error", Message: fmt.Sprintf("review artifact overall verdict is pass even though Phase B verdict is %q without a synthesized justification", phaseBVerdict)})
		}
	}
	if override && !reasonPresent {
		findings = append(findings, artifactValidationFinding{Code: "review_synthesized_reason_missing", Severity: "error", Message: "review artifact overrides the derived overall verdict without a substantive synthesized_reason"})
	}
	if totalFailed := numericInt(details["total_failed"]); totalFailed > 0 && overall == "pass" && !(override && reasonPresent) {
		findings = append(findings, artifactValidationFinding{Code: "review_totals_inconsistent", Severity: "error", Message: fmt.Sprintf("review artifact records total_failed=%d but overall verdict is pass without a synthesized justification", totalFailed)})
	}
	if timestamp, _ := details["timestamp"].(string); strings.TrimSpace(timestamp) == "" {
		findings = append(findings, artifactValidationFinding{Code: "review_timestamp_missing", Severity: "warning", Message: "review artifact does not record a timestamp"})
	}
	if rowTruthGatesRequired(state) && !reviewHasHarnessProcessRisks(content) {
		findings = append(findings, artifactValidationFinding{
			Code:     "review_harness_process_risks_missing",
			Severity: "error",
			Message:  "review artifact must include Harness Process Risks covering modularization, duplication, optionality spread, runtime-loaded entrypoint mismatch, and specialist-as-skill dispatch",
		})
	}
	return findings
}

func reviewHasHarnessProcessRisks(content string) bool {
	lower := strings.ToLower(content)
	if strings.Contains(lower, "harness process risks") {
		return true
	}
	var doc map[string]any
	if err := json.Unmarshal([]byte(content), &doc); err != nil {
		return false
	}
	for _, key := range []string{"harness_process_risks", "process_risks"} {
		if raw, ok := doc[key]; ok {
			switch typed := raw.(type) {
			case []any:
				return len(typed) > 0
			case map[string]any:
				return len(typed) > 0
			case string:
				return isSubstantiveText(typed)
			}
		}
	}
	return false
}

func hasReviewTimestamp(doc map[string]any) bool {
	return strings.TrimSpace(reviewTimestamp(doc)) != ""
}

func reviewOverallVerdict(doc map[string]any) (string, bool) {
	phaseA := reviewPhaseASummary(doc)
	phaseAVerdict, _ := phaseA["verdict"].(string)
	phaseB := reviewPhaseBSummary(doc)
	phaseBVerdict, _ := phaseB["verdict"].(string)
	return reviewOverallVerdictFromDoc(doc, phaseAVerdict, phaseBVerdict)
}

func normalizedVerdict(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "pass", "passed":
		return "pass"
	case "fail", "failed":
		return "fail"
	case "conditional":
		return "conditional"
	default:
		return ""
	}
}

func numericValue(value any) (float64, bool) {
	switch v := value.(type) {
	case float64:
		return v, true
	case float32:
		return float64(v), true
	case int:
		return float64(v), true
	case int64:
		return float64(v), true
	case int32:
		return float64(v), true
	default:
		return 0, false
	}
}

func validateMarkdownSections(content string, required map[string]string) []artifactValidationFinding {
	sections := markdownSections(content)
	findings := make([]artifactValidationFinding, 0)
	for heading, label := range required {
		body, ok := sections[heading]
		if !ok {
			findings = append(findings, artifactValidationFinding{Code: "markdown_section_missing", Severity: "error", Message: fmt.Sprintf("missing section %q for %s", heading, label)})
			continue
		}
		if !sectionHasSubstantiveContent(body) {
			findings = append(findings, artifactValidationFinding{Code: "markdown_section_too_thin", Severity: "error", Message: fmt.Sprintf("section %q for %s still looks empty or placeholder-only", heading, label)})
		}
	}
	return findings
}

func markdownSections(content string) map[string]string {
	sections := map[string]string{}
	current := ""
	var body strings.Builder
	flush := func() {
		if current == "" {
			return
		}
		sections[current] = body.String()
		body.Reset()
	}

	for _, line := range strings.Split(content, "\n") {
		if strings.HasPrefix(line, "## ") {
			flush()
			current = strings.TrimSpace(strings.TrimPrefix(line, "## "))
			continue
		}
		if current == "" {
			continue
		}
		body.WriteString(line)
		body.WriteByte('\n')
	}
	flush()
	return sections
}

func sectionHasSubstantiveContent(body string) bool {
	for _, line := range strings.Split(body, "\n") {
		trimmed := strings.TrimSpace(line)
		trimmed = strings.TrimLeft(trimmed, "-*0123456789.> ")
		if isSubstantiveText(trimmed) {
			return true
		}
	}
	return false
}

func isSubstantiveText(value string) bool {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return false
	}
	lower := strings.ToLower(trimmed)
	placeholderPhrases := []string{
		strings.ToLower(scaffoldMarker),
		"todo",
		"replace this placeholder",
		"replace the incomplete scaffold",
		"todo-deliverable",
	}
	for _, phrase := range placeholderPhrases {
		if strings.Contains(lower, phrase) {
			return false
		}
	}
	return true
}

func nameOrFallback(name string, index int) string {
	if strings.TrimSpace(name) != "" {
		return name
	}
	return fmt.Sprintf("deliverable %d", index+1)
}

func blockingArtifactValidation(artifact map[string]any) bool {
	validation, ok := artifact["validation"].(map[string]any)
	if !ok {
		return false
	}
	status, _ := validation["status"].(string)
	return status == "fail"
}

func validationFindingCodes(artifact map[string]any) []string {
	validation, ok := artifact["validation"].(map[string]any)
	if !ok {
		return nil
	}
	raw, ok := validation["findings"].([]map[string]any)
	if ok {
		codes := make([]string, 0, len(raw))
		for _, finding := range raw {
			if code, _ := finding["code"].(string); code != "" {
				codes = append(codes, code)
			}
		}
		return codes
	}
	generic, ok := validation["findings"].([]any)
	if !ok {
		return nil
	}
	codes := make([]string, 0, len(generic))
	for _, rawFinding := range generic {
		finding, _ := rawFinding.(map[string]any)
		if code, _ := finding["code"].(string); code != "" {
			codes = append(codes, code)
		}
	}
	return codes
}

func summarizeArtifactValidation(artifacts []map[string]any) map[string]any {
	summary := map[string]int{"pass": 0, "warn": 0, "fail": 0, "missing": 0}
	for _, artifact := range artifacts {
		validation, ok := artifact["validation"].(map[string]any)
		if !ok {
			continue
		}
		status, _ := validation["status"].(string)
		if _, exists := summary[status]; exists {
			summary[status]++
		}
	}
	return map[string]any{
		"by_status": summary,
		"total":     len(artifacts),
	}
}

func reviewArtifactSummary(artifacts []map[string]any) map[string]any {
	summary := map[string]int{"pass": 0, "warn": 0, "fail": 0, "missing": 0}
	verdicts := map[string]int{"pass": 0, "conditional": 0, "fail": 0, "unknown": 0}
	phaseAVerdicts := map[string]int{"pass": 0, "conditional": 0, "fail": 0, "unknown": 0}
	phaseBVerdicts := map[string]int{"pass": 0, "conditional": 0, "fail": 0, "unknown": 0}
	findingsBySeverity := map[string]int{"critical": 0, "high": 0, "medium": 0, "low": 0, "unknown": 0}
	followUpsBySeverity := map[string]int{"critical": 0, "high": 0, "medium": 0, "low": 0, "unknown": 0}
	followUpsBySource := map[string]int{"real_findings": 0, "failed_dimensions": 0, "conditional_dimensions": 0}
	required := 0
	synthesizedOverrides := 0
	items := make([]map[string]any, 0)
	for _, artifact := range artifacts {
		id, _ := artifact["id"].(string)
		if !strings.HasPrefix(id, "review:") {
			continue
		}
		required++
		status := "unknown"
		if validation, ok := artifact["validation"].(map[string]any); ok {
			if rawStatus, ok := validation["status"].(string); ok && rawStatus != "" {
				status = rawStatus
				if _, exists := summary[status]; exists {
					summary[status]++
				}
			}
		}
		item := map[string]any{
			"label":  artifact["label"],
			"path":   artifact["path"],
			"status": status,
		}
		expectedDeliverable := strings.TrimSpace(strings.TrimPrefix(id, "review:"))
		if details, err := reviewArtifactDetailsFromPath(getStringDefault(artifact, "path", ""), expectedDeliverable); err == nil {
			item["deliverable"] = details["deliverable"]
			item["overall"] = details["overall"]
			item["timestamp"] = details["timestamp"]
			item["phase_a"] = details["phase_a"]
			item["phase_b"] = details["phase_b"]
			item["findings"] = details["findings"]
			item["follow_ups"] = details["follow_ups"]
			item["synthesized"] = details["synthesized"]

			overall, _ := details["overall"].(string)
			if overall == "" {
				verdicts["unknown"]++
			} else {
				verdicts[overall]++
			}
			if phaseA, ok := details["phase_a"].(map[string]any); ok {
				if verdict, _ := phaseA["verdict"].(string); verdict == "" {
					phaseAVerdicts["unknown"]++
				} else {
					phaseAVerdicts[verdict]++
				}
			}
			if phaseB, ok := details["phase_b"].(map[string]any); ok {
				if verdict, _ := phaseB["verdict"].(string); verdict == "" {
					phaseBVerdicts["unknown"]++
				} else {
					phaseBVerdicts[verdict]++
				}
			}
			if synthesized, ok := details["synthesized"].(map[string]any); ok {
				if override, _ := synthesized["override"].(bool); override {
					synthesizedOverrides++
				}
			}
			if findings, ok := details["findings"].(map[string]any); ok {
				if bySeverity, ok := findings["by_severity"].(map[string]int); ok {
					for severity, count := range bySeverity {
						findingsBySeverity[severity] += count
					}
				} else if generic, ok := findings["by_severity"].(map[string]any); ok {
					for severity, rawCount := range generic {
						findingsBySeverity[severity] += numericInt(rawCount)
					}
				}
			}
			if followUps, ok := details["follow_ups"].(map[string]any); ok {
				if bySeverity, ok := followUps["by_severity"].(map[string]int); ok {
					for severity, count := range bySeverity {
						followUpsBySeverity[severity] += count
					}
				} else if generic, ok := followUps["by_severity"].(map[string]any); ok {
					for severity, rawCount := range generic {
						followUpsBySeverity[severity] += numericInt(rawCount)
					}
				}
				if bySource, ok := followUps["by_source"].(map[string]int); ok {
					for source, count := range bySource {
						followUpsBySource[source] += count
					}
				} else if generic, ok := followUps["by_source"].(map[string]any); ok {
					for source, rawCount := range generic {
						followUpsBySource[source] += numericInt(rawCount)
					}
				}
			}
		}
		items = append(items, item)
	}
	followUpsTotal := 0
	for _, count := range followUpsBySource {
		followUpsTotal += count
	}
	return map[string]any{
		"required":              required,
		"by_status":             summary,
		"overall_verdicts":      verdicts,
		"phase_a_verdicts":      phaseAVerdicts,
		"phase_b_verdicts":      phaseBVerdicts,
		"findings_by_severity":  findingsBySeverity,
		"synthesized_overrides": synthesizedOverrides,
		"follow_ups": map[string]any{
			"total":       followUpsTotal,
			"by_source":   followUpsBySource,
			"by_severity": followUpsBySeverity,
		},
		"items": items,
	}
}

func sourceTodoIDsFromState(state map[string]any) []string {
	if raw, ok := state["source_todos"].([]any); ok {
		ids := make([]string, 0, len(raw))
		seen := make(map[string]struct{}, len(raw))
		for _, item := range raw {
			id, ok := item.(string)
			if !ok {
				continue
			}
			id = strings.TrimSpace(id)
			if id == "" {
				continue
			}
			if _, exists := seen[id]; exists {
				continue
			}
			seen[id] = struct{}{}
			ids = append(ids, id)
		}
		if len(ids) > 0 {
			return ids
		}
	}
	todoID := strings.TrimSpace(getStringDefault(state, "source_todo", ""))
	if todoID == "" {
		return nil
	}
	return []string{todoID}
}

func sourceTodosSurface(root string, state map[string]any) map[string]any {
	todoIDs := sourceTodoIDsFromState(state)
	if len(todoIDs) == 0 {
		return map[string]any{"ids": []any{}, "present": false, "items": []any{}}
	}
	todos, err := readTodoList(filepath.Join(root, ".furrow", "almanac", "todos.yaml"))
	if err != nil {
		return map[string]any{"ids": todoIDs, "present": false, "items": []any{}, "error": err.Error()}
	}
	items := make([]any, 0, len(todoIDs))
	allPresent := true
	for _, todoID := range todoIDs {
		todo, ok := findTodoByID(todos, todoID)
		if !ok {
			allPresent = false
			items = append(items, map[string]any{"id": todoID, "present": false})
			continue
		}
		items = append(items, map[string]any{
			"id":         todoID,
			"present":    true,
			"title":      nilIfEmpty(getStringDefault(todo, "title", "")),
			"status":     nilIfEmpty(getStringDefault(todo, "status", "")),
			"seed_id":    nilIfEmpty(getStringDefault(todo, "seed_id", "")),
			"updated_at": nilIfEmpty(getStringDefault(todo, "updated_at", "")),
		})
	}
	return map[string]any{
		"ids":     todoIDs,
		"present": allPresent,
		"items":   items,
	}
}

func countNonEmptyLines(path string) int {
	payload, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	count := 0
	for _, line := range strings.Split(string(payload), "\n") {
		if strings.TrimSpace(line) != "" {
			count++
		}
	}
	return count
}

func archiveCeremonySurface(root, rowName string, state map[string]any, artifacts []map[string]any) map[string]any {
	learningsPath := filepath.Join(rowDirFor(root, rowName), "learnings.jsonl")
	review := reviewArtifactSummary(artifacts)
	followUps, _ := review["follow_ups"].(map[string]any)
	return map[string]any{
		"review":       review,
		"follow_ups":   followUps,
		"pr_prep":      archivePRPrepSurface(root, rowName, state, artifacts),
		"source_todos": sourceTodosSurface(root, state),
		"learnings": map[string]any{
			"path":    learningsPath,
			"present": fileExists(learningsPath),
			"count":   countNonEmptyLines(learningsPath),
		},
	}
}

func archivePRPrepSurface(root, rowName string, state map[string]any, artifacts []map[string]any) map[string]any {
	branch := gitCurrentBranch(root)
	if branch == "" {
		branch = gitOutputAt(root, "branch", "--show-current")
	}
	changedFiles := strings.Fields(gitOutputAt(root, "diff", "--name-only", "HEAD"))
	testCommands := []string{}
	knownRisks := []string{}
	if artifact := findArtifactByID(artifacts, "completion-check"); artifact != nil {
		if payload, err := os.ReadFile(getStringDefault(artifact, "path", "")); err == nil {
			sections := markdownSections(string(payload))
			testCommands = substantiveSectionLines(sections["What Is Now True"], "test")
			knownRisks = substantiveSectionLines(sections["Deferred Work"], "")
		}
	}
	title := strings.TrimSpace(getStringDefault(state, "title", rowName))
	return map[string]any{
		"branch_worktree": map[string]any{
			"branch":                 nilIfEmpty(branch),
			"worktree":               root,
			"implementation_on_main": branch == "main" || branch == "master",
		},
		"changed_files_by_category": categorizeChangedFiles(changedFiles),
		"test_commands_run":         testCommands,
		"known_residual_risks":      knownRisks,
		"follow_ups":                truthBlockingFollowUps(filepath.Join(rowDirFor(root, rowName), "follow-ups.yaml")),
		"suggested_title":           "feat: " + title,
	}
}

func categorizeChangedFiles(paths []string) map[string][]string {
	categories := map[string][]string{"code": {}, "tests": {}, "docs": {}, "row_artifacts": {}, "schemas": {}, "other": {}}
	for _, path := range paths {
		switch {
		case strings.HasPrefix(path, ".furrow/rows/"):
			categories["row_artifacts"] = append(categories["row_artifacts"], path)
		case strings.HasPrefix(path, "tests/") || strings.HasSuffix(path, "_test.go"):
			categories["tests"] = append(categories["tests"], path)
		case strings.HasPrefix(path, "docs/") || strings.HasSuffix(path, ".md"):
			categories["docs"] = append(categories["docs"], path)
		case strings.HasPrefix(path, "schemas/"):
			categories["schemas"] = append(categories["schemas"], path)
		case strings.HasSuffix(path, ".go") || strings.HasPrefix(path, "cmd/") || strings.HasPrefix(path, "internal/") || strings.HasPrefix(path, "bin/"):
			categories["code"] = append(categories["code"], path)
		default:
			categories["other"] = append(categories["other"], path)
		}
	}
	return categories
}

func substantiveSectionLines(body, mustContain string) []string {
	lines := []string{}
	mustContain = strings.ToLower(strings.TrimSpace(mustContain))
	for _, line := range strings.Split(body, "\n") {
		trimmed := strings.TrimSpace(strings.TrimLeft(line, "-*0123456789.> "))
		if !isSubstantiveText(trimmed) {
			continue
		}
		if mustContain != "" && !strings.Contains(strings.ToLower(trimmed), mustContain) {
			continue
		}
		lines = append(lines, trimmed)
	}
	return lines
}

func latestGateEvidenceSurface(state map[string]any) map[string]any {
	latestRaw := latestGateSummary(state)
	if latestRaw == nil {
		return nil
	}
	latest, ok := latestRaw.(map[string]any)
	if !ok {
		return nil
	}
	evidencePath := strings.TrimSpace(getStringDefault(latest, "evidence_path", ""))
	if evidencePath == "" {
		return nil
	}
	surface := map[string]any{
		"path": evidencePath,
	}
	payload, err := loadJSONMap(evidencePath)
	if err != nil {
		surface["available"] = false
		surface["error"] = err.Error()
		return surface
	}
	surface["available"] = true
	surface["overall"] = nilIfEmpty(getStringDefault(payload, "overall", ""))
	surface["reviewer"] = nilIfEmpty(getStringDefault(payload, "reviewer", ""))
	surface["timestamp"] = nilIfEmpty(getStringDefault(payload, "timestamp", ""))
	if phaseA, ok := payload["phase_a"].(map[string]any); ok {
		surface["phase_a"] = phaseA
	}
	return surface
}

func gateEvidencePath(root, rowName, boundary string) string {
	replacer := strings.NewReplacer("->", "-to-", "/", "-", " ", "-")
	fileName := replacer.Replace(boundary) + ".json"
	return filepath.Join(rowDirFor(root, rowName), "gates", fileName)
}

func writeGateEvidence(root, rowName, boundary string, payload map[string]any) (string, error) {
	path := gateEvidencePath(root, rowName, boundary)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return "", &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to create %s", filepath.Dir(path)), details: map[string]any{"path": filepath.Dir(path), "error": err.Error()}}
	}
	blob, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		return "", &cliError{exit: 4, code: "write_failed", message: "failed to encode gate evidence", details: map[string]any{"error": err.Error()}}
	}
	if err := os.WriteFile(path, append(blob, '\n'), 0o644); err != nil {
		return "", &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to write %s", path), details: map[string]any{"path": path, "error": err.Error()}}
	}
	return path, nil
}

func gateHistory(state map[string]any) []map[string]any {
	rawGates, ok := asSlice(state["gates"])
	if !ok || len(rawGates) == 0 {
		return []map[string]any{}
	}
	history := make([]map[string]any, 0, len(rawGates))
	for _, rawGate := range rawGates {
		gate, ok := rawGate.(map[string]any)
		if !ok {
			continue
		}
		history = append(history, map[string]any{
			"boundary":      nilIfEmpty(getStringDefault(gate, "boundary", "")),
			"outcome":       nilIfEmpty(getStringDefault(gate, "outcome", "")),
			"decided_by":    nilIfEmpty(getStringDefault(gate, "decided_by", "")),
			"timestamp":     nilIfEmpty(getStringDefault(gate, "timestamp", "")),
			"evidence":      nilIfEmpty(getStringDefault(gate, "evidence", "")),
			"evidence_path": optionalPath(getStringDefault(gate, "evidence_path", "")),
		})
	}
	return history
}

func latestPassingReviewGate(state map[string]any) (map[string]any, bool) {
	rawGates, ok := asSlice(state["gates"])
	if !ok {
		return nil, false
	}
	for i := len(rawGates) - 1; i >= 0; i-- {
		gate, ok := rawGates[i].(map[string]any)
		if !ok {
			continue
		}
		boundary := getStringDefault(gate, "boundary", "")
		outcome := getStringDefault(gate, "outcome", "")
		if strings.HasSuffix(boundary, "->review") && outcome == "pass" {
			return gate, true
		}
	}
	return nil, false
}
