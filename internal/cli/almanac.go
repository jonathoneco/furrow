package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"

	yaml "gopkg.in/yaml.v2"
)

type validationFinding struct {
	File     string `json:"file"`
	Severity string `json:"severity"`
	Code     string `json:"code"`
	Path     string `json:"path,omitempty"`
	Message  string `json:"message"`
}

type almanacFileReport struct {
	File           string `json:"file"`
	Status         string `json:"status"`
	FindingCount   int    `json:"finding_count"`
	ErrorCount     int    `json:"error_count"`
	WarningCount   int    `json:"warning_count"`
	DocumentSummary any   `json:"document_summary,omitempty"`
}

type almanacValidationResult struct {
	Paths    map[string]string    `json:"paths"`
	Files    []almanacFileReport  `json:"files"`
	Summary  map[string]any       `json:"summary"`
	Findings []validationFinding  `json:"findings"`
}

func (a *App) runAlmanacValidate(args []string) int {
	positionals, flags, err := parseArgs(args, nil, nil)
	if err != nil {
		return a.fail("furrow almanac validate", err, false)
	}
	if len(positionals) > 0 {
		return a.fail("furrow almanac validate", &cliError{exit: 1, code: "usage", message: "usage: furrow almanac validate [--json]"}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow almanac validate", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	result, err := validateAlmanac(root)
	if err != nil {
		return a.fail("furrow almanac validate", err, flags.json)
	}

	hasErrors := result.Summary["error_count"].(int) > 0
	if flags.json {
		if hasErrors {
			return a.writeJSON(envelope{OK: false, Command: "furrow almanac validate", Version: contractVersion, Data: result, Error: &errBody{Code: "validation_failed", Message: "almanac validation failed", Details: map[string]any{"error_count": result.Summary["error_count"], "warning_count": result.Summary["warning_count"]}}}, 3)
		}
		return a.okJSON("furrow almanac validate", result)
	}

	for _, report := range result.Files {
		_, _ = fmt.Fprintf(a.stdout, "%s: %s (%d findings)\n", report.File, report.Status, report.FindingCount)
	}
	if hasErrors {
		for _, finding := range result.Findings {
			_, _ = fmt.Fprintf(a.stderr, "%s: %s\n", finding.File, finding.Message)
		}
		return 3
	}
	_, _ = fmt.Fprintln(a.stdout, "almanac validation passed")
	return 0
}

func validateAlmanac(root string) (almanacValidationResult, error) {
	paths := map[string]string{
		"todos":        filepath.Join(root, ".furrow", "almanac", "todos.yaml"),
		"observations": filepath.Join(root, ".furrow", "almanac", "observations.yaml"),
		"roadmap":      filepath.Join(root, ".furrow", "almanac", "roadmap.yaml"),
	}
	for kind, path := range paths {
		if !fileExists(path) {
			return almanacValidationResult{}, &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("required almanac file missing: %s", path), details: map[string]any{"missing": kind, "path": path}}
		}
	}

	result := almanacValidationResult{Paths: paths}
	allFindings := make([]validationFinding, 0)

	todosDoc, todosFindings, todoIDs, todoSummary := validateTodos(paths["todos"])
	_ = todosDoc
	allFindings = append(allFindings, todosFindings...)
	obsDoc, obsFindings, obsIDs, obsSummary := validateObservations(root, paths["observations"])
	_ = obsDoc
	allFindings = append(allFindings, obsFindings...)
	roadmapFindings, roadmapSummary := validateRoadmap(paths["roadmap"], todoIDs, obsIDs)
	allFindings = append(allFindings, roadmapFindings...)

	result.Files = []almanacFileReport{
		buildAlmanacFileReport(paths["todos"], todosFindings, todoSummary),
		buildAlmanacFileReport(paths["observations"], obsFindings, obsSummary),
		buildAlmanacFileReport(paths["roadmap"], roadmapFindings, roadmapSummary),
	}
	result.Findings = allFindings
	result.Summary = summarizeFindings(allFindings)
	return result, nil
}

func buildAlmanacFileReport(path string, findings []validationFinding, summary any) almanacFileReport {
	errors := 0
	warnings := 0
	for _, finding := range findings {
		if finding.Severity == "warning" {
			warnings++
		} else {
			errors++
		}
	}
	status := "pass"
	if errors > 0 {
		status = "fail"
	} else if warnings > 0 {
		status = "warn"
	}
	return almanacFileReport{File: path, Status: status, FindingCount: len(findings), ErrorCount: errors, WarningCount: warnings, DocumentSummary: summary}
}

func summarizeFindings(findings []validationFinding) map[string]any {
	errors := 0
	warnings := 0
	for _, finding := range findings {
		if finding.Severity == "warning" {
			warnings++
		} else {
			errors++
		}
	}
	return map[string]any{
		"error_count":   errors,
		"warning_count": warnings,
		"valid":         errors == 0,
	}
}

func validateTodos(path string) (any, []validationFinding, map[string]struct{}, map[string]any) {
	doc, findings := loadYAMLDocument(path)
	if len(findings) > 0 {
		return nil, findings, map[string]struct{}{}, map[string]any{"entries": 0}
	}

	entries, ok := doc.([]any)
	if !ok {
		return nil, []validationFinding{{File: path, Severity: "error", Code: "invalid_type", Path: "$", Message: "todos document must be a YAML sequence"}}, map[string]struct{}{}, map[string]any{"entries": 0}
	}

	ids := map[string]struct{}{}
	duplicateIDs := map[string]int{}
	depends := make([]struct {
		id   string
		dep  string
		path string
	}, 0)

	allowedSourceTypes := map[string]struct{}{"open-question": {}, "unpromoted-learning": {}, "review-finding": {}, "brain-dump": {}, "manual": {}, "legacy": {}}
	allowedStatuses := map[string]struct{}{"active": {}, "done": {}, "blocked": {}, "deferred": {}}
	allowedUrgency := map[string]struct{}{"critical": {}, "high": {}, "medium": {}, "low": {}}
	allowedImpact := map[string]struct{}{"high": {}, "medium": {}, "low": {}}
	allowedEffort := map[string]struct{}{"small": {}, "medium": {}, "large": {}}

	for i, raw := range entries {
		entry, ok := raw.(map[string]any)
		if !ok {
			findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_entry", Path: fmt.Sprintf("[%d]", i), Message: "todo entry must be a mapping"})
			continue
		}
		id := requireStringField(path, entry, "id", fmt.Sprintf("[%d].id", i), &findings)
		_ = requireStringField(path, entry, "title", fmt.Sprintf("[%d].title", i), &findings)
		_ = requireStringField(path, entry, "context", fmt.Sprintf("[%d].context", i), &findings)
		_ = requireStringField(path, entry, "work_needed", fmt.Sprintf("[%d].work_needed", i), &findings)
		_ = requireStringField(path, entry, "created_at", fmt.Sprintf("[%d].created_at", i), &findings)
		_ = requireStringField(path, entry, "updated_at", fmt.Sprintf("[%d].updated_at", i), &findings)

		if id != "" {
			if !isValidSlug(id) {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_slug", Path: fmt.Sprintf("[%d].id", i), Message: fmt.Sprintf("invalid TODO id %q", id)})
			}
			if _, exists := ids[id]; exists {
				duplicateIDs[id]++
			} else {
				ids[id] = struct{}{}
			}
		}

		if sourceType, ok := getString(entry, "source_type"); ok {
			if _, allowed := allowedSourceTypes[sourceType]; !allowed {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_enum", Path: fmt.Sprintf("[%d].source_type", i), Message: fmt.Sprintf("invalid source_type %q", sourceType)})
			}
		}
		if status, ok := getString(entry, "status"); ok {
			if _, allowed := allowedStatuses[status]; !allowed {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_enum", Path: fmt.Sprintf("[%d].status", i), Message: fmt.Sprintf("invalid status %q", status)})
			}
		}
		if urgency, ok := getString(entry, "urgency"); ok {
			if _, allowed := allowedUrgency[urgency]; !allowed {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_enum", Path: fmt.Sprintf("[%d].urgency", i), Message: fmt.Sprintf("invalid urgency %q", urgency)})
			}
		}
		if impact, ok := getString(entry, "impact"); ok {
			if _, allowed := allowedImpact[impact]; !allowed {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_enum", Path: fmt.Sprintf("[%d].impact", i), Message: fmt.Sprintf("invalid impact %q", impact)})
			}
		}
		if effort, ok := getString(entry, "effort"); ok {
			if _, allowed := allowedEffort[effort]; !allowed {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_enum", Path: fmt.Sprintf("[%d].effort", i), Message: fmt.Sprintf("invalid effort %q", effort)})
			}
		}
		if seedID, ok := getString(entry, "seed_id"); ok && !isValidSlug(seedID) {
			findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_slug", Path: fmt.Sprintf("[%d].seed_id", i), Message: fmt.Sprintf("invalid seed_id %q", seedID)})
		}

		if deps, ok := asSlice(entry["depends_on"]); ok {
			for j, rawDep := range deps {
				dep, ok := rawDep.(string)
				if !ok || dep == "" {
					findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_dependency", Path: fmt.Sprintf("[%d].depends_on[%d]", i, j), Message: "depends_on values must be non-empty strings"})
					continue
				}
				depends = append(depends, struct {
					id   string
					dep  string
					path string
				}{id: id, dep: dep, path: fmt.Sprintf("[%d].depends_on[%d]", i, j)})
			}
		}
	}

	for dupID := range duplicateIDs {
		findings = append(findings, validationFinding{File: path, Severity: "error", Code: "duplicate_id", Path: "$.id", Message: fmt.Sprintf("duplicate TODO id %q", dupID)})
	}
	for _, dep := range depends {
		if _, ok := ids[dep.dep]; !ok {
			findings = append(findings, validationFinding{File: path, Severity: "error", Code: "dangling_dependency", Path: dep.path, Message: fmt.Sprintf("TODO %q depends on missing TODO %q", dep.id, dep.dep)})
		}
	}

	sortFindings(findings)
	return doc, findings, ids, map[string]any{"entries": len(entries), "unique_ids": len(ids)}
}

func validateObservations(root, path string) (any, []validationFinding, map[string]struct{}, map[string]any) {
	doc, findings := loadYAMLDocument(path)
	if len(findings) > 0 {
		return nil, findings, map[string]struct{}{}, map[string]any{"entries": 0}
	}

	entries, ok := doc.([]any)
	if !ok {
		return nil, []validationFinding{{File: path, Severity: "error", Code: "invalid_type", Path: "$", Message: "observations document must be a YAML sequence"}}, map[string]struct{}{}, map[string]any{"entries": 0}
	}

	ids := map[string]struct{}{}
	duplicateIDs := map[string]int{}
	allowedKinds := map[string]struct{}{"watch": {}, "decision-review": {}}
	allowedLifecycle := map[string]struct{}{"open": {}, "resolved": {}, "dismissed": {}}
	allowedTriggers := map[string]struct{}{"row_archived": {}, "rows_since": {}, "manual": {}}

	for i, raw := range entries {
		entry, ok := raw.(map[string]any)
		if !ok {
			findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_entry", Path: fmt.Sprintf("[%d]", i), Message: "observation entry must be a mapping"})
			continue
		}
		id := requireStringField(path, entry, "id", fmt.Sprintf("[%d].id", i), &findings)
		kind := requireStringField(path, entry, "kind", fmt.Sprintf("[%d].kind", i), &findings)
		_ = requireStringField(path, entry, "title", fmt.Sprintf("[%d].title", i), &findings)
		lifecycle := requireStringField(path, entry, "lifecycle", fmt.Sprintf("[%d].lifecycle", i), &findings)
		_ = requireStringField(path, entry, "created_at", fmt.Sprintf("[%d].created_at", i), &findings)
		_ = requireStringField(path, entry, "updated_at", fmt.Sprintf("[%d].updated_at", i), &findings)

		if id != "" {
			if !isValidSlug(id) {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_slug", Path: fmt.Sprintf("[%d].id", i), Message: fmt.Sprintf("invalid observation id %q", id)})
			}
			if _, exists := ids[id]; exists {
				duplicateIDs[id]++
			} else {
				ids[id] = struct{}{}
			}
		}
		if kind != "" {
			if _, allowed := allowedKinds[kind]; !allowed {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_enum", Path: fmt.Sprintf("[%d].kind", i), Message: fmt.Sprintf("invalid kind %q", kind)})
			}
		}
		if lifecycle != "" {
			if _, allowed := allowedLifecycle[lifecycle]; !allowed {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_enum", Path: fmt.Sprintf("[%d].lifecycle", i), Message: fmt.Sprintf("invalid lifecycle %q", lifecycle)})
			}
		}

		trigger, ok := asMap(entry["triggered_by"])
		if !ok {
			findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_trigger", Path: fmt.Sprintf("[%d].triggered_by", i), Message: "triggered_by must be a mapping"})
		} else {
			triggerType := requireStringField(path, trigger, "type", fmt.Sprintf("[%d].triggered_by.type", i), &findings)
			if triggerType != "" {
				if _, allowed := allowedTriggers[triggerType]; !allowed {
					findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_enum", Path: fmt.Sprintf("[%d].triggered_by.type", i), Message: fmt.Sprintf("invalid trigger type %q", triggerType)})
				}
				switch triggerType {
				case "row_archived":
					row := requireStringField(path, trigger, "row", fmt.Sprintf("[%d].triggered_by.row", i), &findings)
					if row != "" && !fileExists(statePathForRow(root, row)) {
						findings = append(findings, validationFinding{File: path, Severity: "error", Code: "unknown_row", Path: fmt.Sprintf("[%d].triggered_by.row", i), Message: fmt.Sprintf("observation trigger references missing row %q", row)})
					}
				case "rows_since":
					sinceRow := requireStringField(path, trigger, "since_row", fmt.Sprintf("[%d].triggered_by.since_row", i), &findings)
					if sinceRow != "" && !fileExists(statePathForRow(root, sinceRow)) {
						findings = append(findings, validationFinding{File: path, Severity: "error", Code: "unknown_row", Path: fmt.Sprintf("[%d].triggered_by.since_row", i), Message: fmt.Sprintf("observation trigger references missing row %q", sinceRow)})
					}
					count, ok := intFromAny(trigger["count"])
					if !ok || count < 1 {
						findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_count", Path: fmt.Sprintf("[%d].triggered_by.count", i), Message: "rows_since trigger requires count >= 1"})
					}
				case "manual":
					// no extra required fields
				}
			}
		}

		switch kind {
		case "watch":
			_ = requireStringField(path, entry, "signal", fmt.Sprintf("[%d].signal", i), &findings)
		case "decision-review":
			_ = requireStringField(path, entry, "question", fmt.Sprintf("[%d].question", i), &findings)
			_ = requireStringField(path, entry, "acceptance_criteria", fmt.Sprintf("[%d].acceptance_criteria", i), &findings)
			if options, ok := asSlice(entry["options"]); !ok || len(options) < 2 {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_options", Path: fmt.Sprintf("[%d].options", i), Message: "decision-review observations require at least two options"})
			} else {
				for j, rawOption := range options {
					option, ok := rawOption.(map[string]any)
					if !ok {
						findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_option", Path: fmt.Sprintf("[%d].options[%d]", i, j), Message: "option must be a mapping"})
						continue
					}
					optionID := requireStringField(path, option, "id", fmt.Sprintf("[%d].options[%d].id", i, j), &findings)
					_ = requireStringField(path, option, "label", fmt.Sprintf("[%d].options[%d].label", i, j), &findings)
					if optionID != "" && !isValidSlug(optionID) {
						findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_slug", Path: fmt.Sprintf("[%d].options[%d].id", i, j), Message: fmt.Sprintf("invalid option id %q", optionID)})
					}
				}
			}
		}
	}

	for dupID := range duplicateIDs {
		findings = append(findings, validationFinding{File: path, Severity: "error", Code: "duplicate_id", Path: "$.id", Message: fmt.Sprintf("duplicate observation id %q", dupID)})
	}

	sortFindings(findings)
	return doc, findings, ids, map[string]any{"entries": len(entries), "unique_ids": len(ids)}
}

func validateRoadmap(path string, todoIDs, observationIDs map[string]struct{}) ([]validationFinding, map[string]any) {
	doc, findings := loadYAMLDocument(path)
	if len(findings) > 0 {
		return findings, map[string]any{"phases": 0}
	}

	root, ok := doc.(map[string]any)
	if !ok {
		return []validationFinding{{File: path, Severity: "error", Code: "invalid_type", Path: "$", Message: "roadmap document must be a mapping"}}, map[string]any{"phases": 0}
	}

	nodeIDs := map[string]struct{}{}
	nodeCount := 0
	phaseCount := 0
	rowsCount := 0
	activeObservationCount := 0

	if _, ok := getString(root, "schema_version"); !ok {
		findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_field", Path: "$.schema_version", Message: "roadmap missing schema_version"})
	}
	if metadata, ok := asMap(root["metadata"]); ok {
		if total, ok := intFromAny(metadata["total_phases"]); ok {
			if phases, ok := asSlice(root["phases"]); ok && total != len(phases) {
				findings = append(findings, validationFinding{File: path, Severity: "warning", Code: "phase_count_mismatch", Path: "$.metadata.total_phases", Message: fmt.Sprintf("metadata total_phases=%d does not match phases length=%d", total, len(phases))})
			}
		}
	} else {
		findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_field", Path: "$.metadata", Message: "roadmap missing metadata mapping"})
	}

	if depGraph, ok := asMap(root["dependency_graph"]); ok {
		if nodes, ok := asSlice(depGraph["nodes"]); ok {
			nodeCount = len(nodes)
			for i, rawNode := range nodes {
				node, ok := rawNode.(map[string]any)
				if !ok {
					findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_node", Path: fmt.Sprintf("$.dependency_graph.nodes[%d]", i), Message: "roadmap node must be a mapping"})
					continue
				}
				nodeID := requireStringField(path, node, "id", fmt.Sprintf("$.dependency_graph.nodes[%d].id", i), &findings)
				if nodeID != "" {
					if _, exists := nodeIDs[nodeID]; exists {
						findings = append(findings, validationFinding{File: path, Severity: "error", Code: "duplicate_id", Path: fmt.Sprintf("$.dependency_graph.nodes[%d].id", i), Message: fmt.Sprintf("duplicate roadmap node id %q", nodeID)})
					} else {
						nodeIDs[nodeID] = struct{}{}
					}
					if len(todoIDs) > 0 {
						if _, ok := todoIDs[nodeID]; !ok {
							findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_todo", Path: fmt.Sprintf("$.dependency_graph.nodes[%d].id", i), Message: fmt.Sprintf("roadmap node references missing TODO %q", nodeID)})
						}
					}
				}
			}
		} else {
			findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_field", Path: "$.dependency_graph.nodes", Message: "roadmap missing dependency_graph.nodes sequence"})
		}
		if edges, ok := asSlice(depGraph["edges"]); ok {
			for i, rawEdge := range edges {
				edge, ok := rawEdge.(map[string]any)
				if !ok {
					findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_edge", Path: fmt.Sprintf("$.dependency_graph.edges[%d]", i), Message: "roadmap edge must be a mapping"})
					continue
				}
				from := requireStringField(path, edge, "from", fmt.Sprintf("$.dependency_graph.edges[%d].from", i), &findings)
				to := requireStringField(path, edge, "to", fmt.Sprintf("$.dependency_graph.edges[%d].to", i), &findings)
				if from != "" {
					if _, ok := nodeIDs[from]; !ok {
						findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_node", Path: fmt.Sprintf("$.dependency_graph.edges[%d].from", i), Message: fmt.Sprintf("edge references missing node %q", from)})
					}
				}
				if to != "" {
					if _, ok := nodeIDs[to]; !ok {
						findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_node", Path: fmt.Sprintf("$.dependency_graph.edges[%d].to", i), Message: fmt.Sprintf("edge references missing node %q", to)})
					}
				}
			}
		}
	} else {
		findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_field", Path: "$.dependency_graph", Message: "roadmap missing dependency_graph mapping"})
	}

	if phases, ok := asSlice(root["phases"]); ok {
		phaseCount = len(phases)
		for i, rawPhase := range phases {
			phase, ok := rawPhase.(map[string]any)
			if !ok {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_phase", Path: fmt.Sprintf("$.phases[%d]", i), Message: "phase must be a mapping"})
				continue
			}
			_, _ = intFromAny(phase["number"])
			rows, rowsOK := asSlice(phase["rows"])
			workUnits, workUnitsOK := asSlice(phase["work_units"])
			if rowsOK {
				rowsCount += validateRoadmapRows(path, rows, todoIDs, &findings, fmt.Sprintf("$.phases[%d].rows", i))
			} else if workUnitsOK {
				rowsCount += validateRoadmapRows(path, workUnits, todoIDs, &findings, fmt.Sprintf("$.phases[%d].work_units", i))
			} else {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_rows", Path: fmt.Sprintf("$.phases[%d]", i), Message: "phase must contain rows or work_units"})
			}
		}
	} else {
		findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_field", Path: "$.phases", Message: "roadmap missing phases sequence"})
	}

	if deferred, ok := asSlice(root["deferred"]); ok {
		for i, rawDeferred := range deferred {
			entry, ok := rawDeferred.(map[string]any)
			if !ok {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_deferred", Path: fmt.Sprintf("$.deferred[%d]", i), Message: "deferred entry must be a mapping"})
				continue
			}
			id := requireStringField(path, entry, "id", fmt.Sprintf("$.deferred[%d].id", i), &findings)
			if id != "" {
				if _, ok := todoIDs[id]; !ok {
					findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_todo", Path: fmt.Sprintf("$.deferred[%d].id", i), Message: fmt.Sprintf("deferred entry references missing TODO %q", id)})
				}
			}
		}
	}

	if activeObservations, ok := asSlice(root["active_observations"]); ok {
		activeObservationCount = len(activeObservations)
		for i, rawObservation := range activeObservations {
			entry, ok := rawObservation.(map[string]any)
			if !ok {
				findings = append(findings, validationFinding{File: path, Severity: "error", Code: "invalid_active_observation", Path: fmt.Sprintf("$.active_observations[%d]", i), Message: "active_observations entry must be a mapping"})
				continue
			}
			id := requireStringField(path, entry, "id", fmt.Sprintf("$.active_observations[%d].id", i), &findings)
			if id != "" {
				if _, ok := observationIDs[id]; !ok {
					findings = append(findings, validationFinding{File: path, Severity: "error", Code: "missing_observation", Path: fmt.Sprintf("$.active_observations[%d].id", i), Message: fmt.Sprintf("active observation references missing observation %q", id)})
				}
			}
		}
	}

	sortFindings(findings)
	return findings, map[string]any{"node_count": nodeCount, "phase_count": phaseCount, "row_count": rowsCount, "active_observation_count": activeObservationCount}
}

func validateRoadmapRows(path string, rows []any, todoIDs map[string]struct{}, findings *[]validationFinding, base string) int {
	count := 0
	for i, rawRow := range rows {
		row, ok := rawRow.(map[string]any)
		if !ok {
			*findings = append(*findings, validationFinding{File: path, Severity: "error", Code: "invalid_row", Path: fmt.Sprintf("%s[%d]", base, i), Message: "roadmap row/work unit must be a mapping"})
			continue
		}
		count++
		if todos, ok := asSlice(row["todos"]); ok {
			for j, rawTodo := range todos {
				todoID, ok := rawTodo.(string)
				if !ok || todoID == "" {
					*findings = append(*findings, validationFinding{File: path, Severity: "error", Code: "invalid_todo_ref", Path: fmt.Sprintf("%s[%d].todos[%d]", base, i, j), Message: "row todo references must be non-empty strings"})
					continue
				}
				if _, ok := todoIDs[todoID]; !ok {
					*findings = append(*findings, validationFinding{File: path, Severity: "error", Code: "missing_todo", Path: fmt.Sprintf("%s[%d].todos[%d]", base, i, j), Message: fmt.Sprintf("roadmap row references missing TODO %q", todoID)})
				}
			}
		}
	}
	return count
}

func loadYAMLDocument(path string) (any, []validationFinding) {
	payload, err := os.ReadFile(path)
	if err != nil {
		return nil, []validationFinding{{File: path, Severity: "error", Code: "read_failed", Path: "$", Message: err.Error()}}
	}
	var doc any
	if err := yaml.Unmarshal(payload, &doc); err != nil {
		return nil, []validationFinding{{File: path, Severity: "error", Code: "parse_failed", Path: "$", Message: err.Error()}}
	}
	return normalizeYAMLValue(doc), nil
}

func normalizeYAMLValue(value any) any {
	switch v := value.(type) {
	case map[any]any:
		out := make(map[string]any, len(v))
		for key, item := range v {
			out[fmt.Sprint(key)] = normalizeYAMLValue(item)
		}
		return out
	case map[string]any:
		out := make(map[string]any, len(v))
		for key, item := range v {
			out[key] = normalizeYAMLValue(item)
		}
		return out
	case []any:
		out := make([]any, len(v))
		for i, item := range v {
			out[i] = normalizeYAMLValue(item)
		}
		return out
	default:
		return value
	}
}

func requireStringField(file string, entry map[string]any, key, path string, findings *[]validationFinding) string {
	value, ok := entry[key]
	if !ok || value == nil {
		*findings = append(*findings, validationFinding{File: file, Severity: "error", Code: "missing_field", Path: path, Message: fmt.Sprintf("missing required field %q", key)})
		return ""
	}
	str, ok := value.(string)
	if !ok || str == "" {
		*findings = append(*findings, validationFinding{File: file, Severity: "error", Code: "invalid_field", Path: path, Message: fmt.Sprintf("field %q must be a non-empty string", key)})
		return ""
	}
	return str
}

func sortFindings(findings []validationFinding) {
	sort.Slice(findings, func(i, j int) bool {
		if findings[i].File != findings[j].File {
			return findings[i].File < findings[j].File
		}
		if findings[i].Path != findings[j].Path {
			return findings[i].Path < findings[j].Path
		}
		return findings[i].Code < findings[j].Code
	})
}
