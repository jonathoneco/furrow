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

func blocker(code, category, message string, details map[string]any) map[string]any {
	entry := map[string]any{
		"code":              code,
		"category":          category,
		"severity":          "error",
		"message":           message,
		"confirmation_path": blockerConfirmationPath(code),
	}
	for key, value := range details {
		entry[key] = value
	}
	return entry
}

func blockerConfirmationPath(code string) string {
	switch code {
	case "pending_user_actions":
		return "Resolve or clear the pending user actions through the canonical workflow before advancing."
	case "seed_store_unavailable", "missing_seed_record", "closed_seed", "seed_status_mismatch":
		return "Repair the linked seed state so it matches the row step, then retry the checkpoint through the backend."
	case "missing_required_artifact":
		return "Create or scaffold the required current-step artifact, then rerun /work or furrow row status."
	case "artifact_scaffold_incomplete":
		return "Replace the incomplete scaffold with real step content, then rerun furrow row complete or /work --complete."
	case "artifact_validation_failed":
		return "Address the reported validation findings in the artifact, then rerun furrow row status or /work."
	case "archive_requires_review_gate":
		return "Record a passing implement->review gate before archiving so the review boundary has durable evidence."
	default:
		return "Resolve the blocker through the backend-mediated workflow, then retry the checkpoint."
	}
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
	case "team-plan":
		return validateMarkdownSections(content, map[string]string{
			"Scope Analysis":   "team scope analysis",
			"Team Composition": "team composition",
			"Task Assignment":  "task assignment",
			"Coordination":     "coordination plan",
			"Skills":           "skills plan",
		})
	default:
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
