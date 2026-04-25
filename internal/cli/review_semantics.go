package cli

import (
	"encoding/json"
	"os"
	"strconv"
	"strings"
)

func reviewArtifactDetailsFromPath(path, expectedDeliverable string) (map[string]any, error) {
	payload, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return reviewArtifactDetailsFromContent(string(payload), expectedDeliverable)
}

func reviewArtifactDetailsFromContent(content, expectedDeliverable string) (map[string]any, error) {
	var doc map[string]any
	if err := json.Unmarshal([]byte(content), &doc); err != nil {
		return nil, err
	}
	return reviewArtifactDetails(doc, expectedDeliverable), nil
}

func reviewArtifactDetails(doc map[string]any, expectedDeliverable string) map[string]any {
	phaseA := reviewPhaseASummary(doc)
	phaseAVerdict, _ := phaseA["verdict"].(string)
	phaseB := reviewPhaseBSummary(doc)
	phaseBVerdict, _ := phaseB["verdict"].(string)
	overall, _ := reviewOverallVerdictFromDoc(doc, phaseAVerdict, phaseBVerdict)
	derivedOverall := derivedReviewOverallVerdict(phaseAVerdict, phaseBVerdict)
	synthesizedVerdict := normalizedVerdictPrefix(getStringDefault(doc, "synthesized_verdict", ""))
	synthesizedReason := strings.TrimSpace(getStringDefault(doc, "synthesized_reason", ""))
	findings := reviewFindingsSummary(doc["real_findings"])
	followUps := reviewFollowUpSummary(doc, findings, phaseB)
	deliverable := reviewDeliverableName(doc, expectedDeliverable)

	details := map[string]any{
		"deliverable":           nilIfEmpty(deliverable),
		"expected_deliverable":  nilIfEmpty(strings.TrimSpace(expectedDeliverable)),
		"phase_a":               phaseA,
		"phase_b":               phaseB,
		"overall":               nilIfEmpty(overall),
		"timestamp":             nilIfEmpty(reviewTimestamp(doc)),
		"findings":              findings,
		"follow_ups":            followUps,
		"derived_overall":       nilIfEmpty(derivedOverall),
		"synthesized": map[string]any{
			"override":       synthesizedVerdict != "" && derivedOverall != "" && synthesizedVerdict != derivedOverall,
			"reason_present": isSubstantiveText(synthesizedReason),
			"verdict":        nilIfEmpty(synthesizedVerdict),
		},
	}
	if totalPassed, ok := numericValue(doc["total_passed"]); ok {
		details["total_passed"] = int(totalPassed)
	}
	if totalFailed, ok := numericValue(doc["total_failed"]); ok {
		details["total_failed"] = int(totalFailed)
	}
	return details
}

func reviewDeliverableName(doc map[string]any, expectedDeliverable string) string {
	deliverable := strings.TrimSpace(getStringDefault(doc, "deliverable", ""))
	if deliverable != "" {
		return deliverable
	}
	return strings.TrimSpace(expectedDeliverable)
}

func reviewTimestamp(doc map[string]any) string {
	for _, key := range []string{"timestamp", "reviewed_at", "generated_at"} {
		if raw, ok := doc[key].(string); ok && strings.TrimSpace(raw) != "" {
			return strings.TrimSpace(raw)
		}
	}
	return ""
}

func reviewPhaseASummary(doc map[string]any) map[string]any {
	summary := map[string]any{
		"available":           false,
		"verdict":             nil,
		"artifacts_present":   nil,
		"acceptance_criteria": map[string]any{"total": 0, "met": 0, "unmet": 0, "missing_evidence": 0},
	}

	var phase map[string]any
	if raw, ok := doc["phase_a"].(map[string]any); ok {
		phase = raw
		summary["available"] = true
	}
	if phase == nil {
		if _, ok := doc["phase_a_verdict"].(string); ok {
			summary["available"] = true
		}
		if _, ok := doc["artifacts_present"]; ok {
			summary["available"] = true
		}
		if _, ok := doc["acceptance_criteria"]; ok {
			summary["available"] = true
		}
		if reviewers, ok := doc["reviewers"].(map[string]any); ok {
			if _, ok := reviewers["phase_a"]; ok {
				summary["available"] = true
			}
		}
	}

	verdict := normalizedVerdictPrefix(getStringDefault(doc, "phase_a_verdict", ""))
	if verdict == "" && phase != nil {
		if phaseVerdict, ok := phaseObjectVerdict(phase); ok {
			verdict = phaseVerdict
		}
	}
	if verdict != "" {
		summary["verdict"] = verdict
	}

	if phase != nil {
		if artifactsPresent, ok := phase["artifacts_present"].(bool); ok {
			summary["artifacts_present"] = artifactsPresent
		}
	}
	if summary["artifacts_present"] == nil {
		if artifactsPresent, ok := doc["artifacts_present"].(bool); ok {
			summary["artifacts_present"] = artifactsPresent
		}
	}

	criteriaSource := any(nil)
	if phase != nil {
		if raw, ok := phase["acceptance_criteria"]; ok {
			criteriaSource = raw
		}
	}
	if criteriaSource == nil {
		criteriaSource = doc["acceptance_criteria"]
	}
	summary["acceptance_criteria"] = reviewCriteriaSummary(criteriaSource)
	return summary
}

func reviewPhaseBSummary(doc map[string]any) map[string]any {
	summary := map[string]any{
		"available":   false,
		"verdict":     nil,
		"dimensions":  map[string]any{"total": 0, "pass": 0, "fail": 0, "conditional": 0, "missing_evidence": 0},
		"cross_model": false,
	}

	var phase map[string]any
	if raw, ok := doc["phase_b"].(map[string]any); ok {
		phase = raw
		summary["available"] = true
	}
	if phase == nil {
		for _, key := range []string{"phase_b_verdict", "phase_b_cross_verdict", "synthesized_verdict", "overall", "verdict", "dimensions"} {
			if _, ok := doc[key]; ok {
				summary["available"] = true
				break
			}
		}
	}

	verdict := normalizedVerdictPrefix(getStringDefault(doc, "phase_b_verdict", ""))
	if verdict == "" {
			verdict = normalizedVerdictPrefix(getStringDefault(doc, "phase_b_cross_verdict", ""))
	}
	if verdict == "" && phase != nil {
		if phaseVerdict, ok := phaseObjectVerdict(phase); ok {
			verdict = phaseVerdict
		}
	}
	if verdict != "" {
		summary["verdict"] = verdict
	}

	dimensionsSource := any(nil)
	if phase != nil {
		if raw, ok := phase["dimensions"]; ok {
			dimensionsSource = raw
		} else {
			dimensionsSource = phase
		}
	}
	if dimensionsSource == nil {
		dimensionsSource = doc["dimensions"]
	}
	summary["dimensions"] = reviewDimensionSummary(dimensionsSource)

	if crossModel, ok := doc["cross_model"].(bool); ok {
		summary["cross_model"] = crossModel
	} else if getStringDefault(doc, "phase_b_cross_verdict", "") != "" {
		summary["cross_model"] = true
	}
	return summary
}

func reviewCriteriaSummary(raw any) map[string]any {
	summary := map[string]any{"total": 0, "met": 0, "unmet": 0, "missing_evidence": 0}
	entries, ok := asSlice(raw)
	if !ok {
		return summary
	}
	for _, rawEntry := range entries {
		entry, ok := rawEntry.(map[string]any)
		if !ok {
			continue
		}
		summary["total"] = numericInt(summary["total"]) + 1
		if met, ok := entry["met"].(bool); ok {
			if met {
				summary["met"] = numericInt(summary["met"]) + 1
				if !isSubstantiveText(getStringDefault(entry, "evidence", "")) {
					summary["missing_evidence"] = numericInt(summary["missing_evidence"]) + 1
				}
			} else {
				summary["unmet"] = numericInt(summary["unmet"]) + 1
			}
		}
	}
	return summary
}

func reviewDimensionSummary(raw any) map[string]any {
	summary := map[string]any{"total": 0, "pass": 0, "fail": 0, "conditional": 0, "missing_evidence": 0}
	for _, signal := range reviewDimensionSignals(raw) {
		summary["total"] = numericInt(summary["total"]) + 1
		verdict := getStringDefault(signal, "verdict", "")
		if verdict != "" {
			summary[verdict] = numericInt(summary[verdict]) + 1
		}
		if verdict != "" && !isSubstantiveText(getStringDefault(signal, "evidence", "")) {
			summary["missing_evidence"] = numericInt(summary["missing_evidence"]) + 1
		}
	}
	return summary
}

func reviewDimensionSignals(raw any) []map[string]any {
	signals := make([]map[string]any, 0)
	switch typed := raw.(type) {
	case []any:
		for index, rawEntry := range typed {
			defaultName := "dimension-" + strconv.Itoa(index+1)
			switch entry := rawEntry.(type) {
			case map[string]any:
				if signal, ok := reviewSignalFromMap(defaultName, entry); ok {
					signals = append(signals, signal)
				}
			case string:
				if signal, ok := reviewSignalFromText(defaultName, entry); ok {
					signals = append(signals, signal)
				}
			}
		}
	case map[string]any:
		for key, value := range typed {
			if key == "verdict" || key == "dimensions" || key == "cross_model" {
				continue
			}
			switch entry := value.(type) {
			case map[string]any:
				if signal, ok := reviewSignalFromMap(key, entry); ok {
					signals = append(signals, signal)
				}
			case string:
				if signal, ok := reviewSignalFromText(key, entry); ok {
					signals = append(signals, signal)
				}
			}
		}
	}
	return signals
}

func reviewSignalFromMap(defaultName string, value map[string]any) (map[string]any, bool) {
	verdict := normalizedVerdictPrefix(getStringDefault(value, "verdict", ""))
	if verdict == "" {
		return nil, false
	}
	return map[string]any{
		"name":     signalName(defaultName, value),
		"verdict":  verdict,
		"evidence": signalEvidence(value),
	}, true
}

func reviewSignalFromText(defaultName, value string) (map[string]any, bool) {
	verdict := normalizedVerdictPrefix(value)
	if verdict == "" {
		return nil, false
	}
	return map[string]any{
		"name":     defaultName,
		"verdict":  verdict,
		"evidence": strings.TrimSpace(value),
	}, true
}

func signalName(defaultName string, value map[string]any) string {
	for _, key := range []string{"name", "dimension", "criterion", "label"} {
		if raw, ok := value[key].(string); ok && strings.TrimSpace(raw) != "" {
			return strings.TrimSpace(raw)
		}
	}
	return defaultName
}

func signalEvidence(value map[string]any) string {
	for _, key := range []string{"evidence", "note", "message", "summary"} {
		if raw, ok := value[key].(string); ok && strings.TrimSpace(raw) != "" {
			return strings.TrimSpace(raw)
		}
	}
	return ""
}

func phaseObjectVerdict(raw map[string]any) (string, bool) {
	if verdict := normalizedVerdictPrefix(getStringDefault(raw, "verdict", "")); verdict != "" {
		return verdict, true
	}
	verdicts := make([]string, 0)
	for key, value := range raw {
		if key == "verdict" || key == "dimensions" || key == "acceptance_criteria" || key == "artifacts_present" || key == "cross_model" {
			continue
		}
		switch typed := value.(type) {
		case map[string]any:
			if verdict := normalizedVerdictPrefix(getStringDefault(typed, "verdict", "")); verdict != "" {
				verdicts = append(verdicts, verdict)
			}
		case string:
			if verdict := normalizedVerdictPrefix(typed); verdict != "" {
				verdicts = append(verdicts, verdict)
			}
		}
	}
	return aggregateVerdict(verdicts)
}

func aggregateVerdict(verdicts []string) (string, bool) {
	if len(verdicts) == 0 {
		return "", false
	}
	hasPass := false
	hasConditional := false
	for _, verdict := range verdicts {
		switch verdict {
		case "fail":
			return "fail", true
		case "conditional":
			hasConditional = true
		case "pass":
			hasPass = true
		}
	}
	if hasConditional {
		return "conditional", true
	}
	if hasPass {
		return "pass", true
	}
	return "", false
}

func derivedReviewOverallVerdict(phaseAVerdict, phaseBVerdict string) string {
	switch {
	case phaseAVerdict == "fail" || phaseBVerdict == "fail":
		return "fail"
	case phaseAVerdict == "conditional" || phaseBVerdict == "conditional":
		return "conditional"
	case phaseAVerdict == "pass" && phaseBVerdict == "pass":
		return "pass"
	default:
		return ""
	}
}

func reviewOverallVerdictFromDoc(doc map[string]any, phaseAVerdict, phaseBVerdict string) (string, bool) {
	for _, key := range []string{"synthesized_verdict", "overall", "verdict"} {
		if verdict := normalizedVerdictPrefix(getStringDefault(doc, key, "")); verdict != "" {
			return verdict, true
		}
	}
	if totalFailed, ok := numericValue(doc["total_failed"]); ok {
		if totalFailed == 0 {
			if totalPassed, ok := numericValue(doc["total_passed"]); ok && totalPassed >= 0 {
				return "pass", true
			}
		}
		return "fail", true
	}
	if derived := derivedReviewOverallVerdict(phaseAVerdict, phaseBVerdict); derived != "" {
		return derived, true
	}
	if verdict := normalizedVerdictPrefix(getStringDefault(doc, "phase_b_verdict", "")); verdict != "" {
		return verdict, true
	}
	if verdict := normalizedVerdictPrefix(getStringDefault(doc, "phase_b_cross_verdict", "")); verdict != "" {
		return verdict, true
	}
	return "", false
}

func normalizedVerdictPrefix(value string) string {
	if verdict := normalizedVerdict(value); verdict != "" {
		return verdict
	}
	trimmed := strings.TrimSpace(strings.ToLower(value))
	if trimmed == "" {
		return ""
	}
	fields := strings.FieldsFunc(trimmed, func(r rune) bool {
		switch r {
		case ' ', '\t', '\n', '\r', ':', ';', ',', '-', '—', '–', '(', ')', '[', ']':
			return true
		default:
			return false
		}
	})
	if len(fields) == 0 {
		return ""
	}
	return normalizedVerdict(fields[0])
}

func reviewFindingsSummary(raw any) map[string]any {
	counts := map[string]int{"critical": 0, "high": 0, "medium": 0, "low": 0, "unknown": 0}
	total := 0
	entries, ok := asSlice(raw)
	if !ok {
		return map[string]any{"total": 0, "by_severity": counts}
	}
	for _, rawEntry := range entries {
		entry, ok := rawEntry.(map[string]any)
		if !ok {
			continue
		}
		total++
		severity := normalizedSeverity(getStringDefault(entry, "severity", ""))
		counts[severity]++
	}
	return map[string]any{"total": total, "by_severity": counts}
}

func reviewFollowUpSummary(doc map[string]any, findings map[string]any, phaseB map[string]any) map[string]any {
	bySeverity := map[string]int{"critical": 0, "high": 0, "medium": 0, "low": 0, "unknown": 0}
	bySource := map[string]int{"real_findings": 0, "failed_dimensions": 0, "conditional_dimensions": 0}
	items := make([]map[string]any, 0)

	if entries, ok := asSlice(doc["real_findings"]); ok {
		for _, rawEntry := range entries {
			entry, ok := rawEntry.(map[string]any)
			if !ok {
				continue
			}
			severity := normalizedSeverity(getStringDefault(entry, "severity", ""))
			bySeverity[severity]++
			bySource["real_findings"]++
			items = append(items, map[string]any{
				"source":   "real_finding",
				"severity": severity,
				"dimension": nilIfEmpty(getStringDefault(entry, "dim", "")),
				"note":     nilIfEmpty(signalEvidence(entry)),
			})
		}
	}

	var phaseRaw any
	if phase, ok := doc["phase_b"].(map[string]any); ok {
		if raw, ok := phase["dimensions"]; ok {
			phaseRaw = raw
		} else {
			phaseRaw = phase
		}
	} else {
		phaseRaw = doc["dimensions"]
	}
	for _, signal := range reviewDimensionSignals(phaseRaw) {
		verdict := getStringDefault(signal, "verdict", "")
		if verdict != "fail" && verdict != "conditional" {
			continue
		}
		if verdict == "fail" {
			bySource["failed_dimensions"]++
		} else {
			bySource["conditional_dimensions"]++
		}
		bySeverity["unknown"]++
		items = append(items, map[string]any{
			"source":   "dimension",
			"severity": "unknown",
			"dimension": nilIfEmpty(getStringDefault(signal, "name", "")),
			"verdict":  verdict,
			"note":     nilIfEmpty(getStringDefault(signal, "evidence", "")),
		})
	}

	_ = findings
	return map[string]any{
		"total":       len(items),
		"by_severity": bySeverity,
		"by_source":   bySource,
		"items":       items,
		"phase_b":     phaseB,
	}
}

func normalizedSeverity(value string) string {
	trimmed := strings.ToLower(strings.TrimSpace(value))
	switch {
	case strings.Contains(trimmed, "critical"):
		return "critical"
	case strings.Contains(trimmed, "high"):
		return "high"
	case strings.Contains(trimmed, "medium"), strings.Contains(trimmed, "med"):
		return "medium"
	case strings.Contains(trimmed, "low"):
		return "low"
	default:
		return "unknown"
	}
}

func numericInt(value any) int {
	if number, ok := numericValue(value); ok {
		return int(number)
	}
	return 0
}

