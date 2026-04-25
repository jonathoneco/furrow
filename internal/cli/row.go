package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func (a *App) runRowList(args []string) int {
	positionals, flags, err := parseArgs(args, nil, map[string]bool{"active": true, "archived": true, "all": true})
	if err != nil {
		return a.fail("furrow row list", err, false)
	}
	if len(positionals) > 0 {
		return a.fail("furrow row list", &cliError{exit: 1, code: "usage", message: "usage: furrow row list [--active|--archived|--all] [--json]"}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow row list", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	filter := "all"
	flagCount := 0
	for _, name := range []string{"active", "archived", "all"} {
		if flags.bools[name] {
			filter = name
			flagCount++
		}
	}
	if flagCount > 1 {
		return a.fail("furrow row list", &cliError{exit: 1, code: "usage", message: "use at most one of --active, --archived, or --all"}, flags.json)
	}

	focusedRow, _, focusedErr := readFocusedRowName(root)
	rows, warnings, err := listRows(root, focusedRow)
	if err != nil {
		return a.fail("furrow row list", err, flags.json)
	}
	if focusedErr != nil {
		warnings = append(warnings, map[string]any{"code": "focused_row_invalid", "message": focusedErr.Error()})
	}

	filtered := make([]rowListEntry, 0, len(rows))
	for _, row := range rows {
		switch filter {
		case "active":
			if row.Archived {
				continue
			}
		case "archived":
			if !row.Archived {
				continue
			}
		}
		filtered = append(filtered, row)
	}

	dataRows := make([]map[string]any, 0, len(filtered))
	activeCount := 0
	archivedCount := 0
	for _, row := range filtered {
		if row.Archived {
			archivedCount++
		} else {
			activeCount++
		}
		dataRows = append(dataRows, map[string]any{
			"name":         row.Name,
			"title":        row.Title,
			"step":         row.Step,
			"step_status":  row.StepStatus,
			"archived":     row.Archived,
			"focused":      row.Focused,
			"updated_at":   row.UpdatedAt,
			"branch":       row.Branch,
			"deliverables": row.DeliverableCounts,
		})
	}

	data := map[string]any{
		"filter":      filter,
		"focused_row": nilIfEmpty(focusedRow),
		"summary": map[string]any{
			"total":    len(filtered),
			"active":   activeCount,
			"archived": archivedCount,
		},
		"rows":     dataRows,
		"warnings": warnings,
	}
	if flags.json {
		return a.okJSON("furrow row list", data)
	}

	for _, row := range filtered {
		focused := " "
		if row.Focused {
			focused = "*"
		}
		_, _ = fmt.Fprintf(a.stdout, "%s %s\t%s\t%s\tarchived=%t\n", focused, row.Name, row.Step, row.StepStatus, row.Archived)
	}
	return 0
}

func (a *App) runRowStatus(args []string) int {
	positionals, flags, err := parseArgs(args, nil, nil)
	if err != nil {
		return a.fail("furrow row status", err, false)
	}
	if len(positionals) > 1 {
		return a.fail("furrow row status", &cliError{exit: 1, code: "usage", message: "usage: furrow row status [row-name] [--json]"}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow row status", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	explicit := ""
	if len(positionals) == 1 {
		explicit = positionals[0]
	}
	rowName, resolution, focusedRow, warnings, err := resolveRowForStatus(root, explicit)
	if err != nil {
		return a.fail("furrow row status", err, flags.json)
	}

	statePath := statePathForRow(root, rowName)
	state, err := loadJSONMap(statePath)
	if err != nil {
		return a.fail("furrow row status", &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", statePath), details: map[string]any{"path": statePath}}, flags.json)
	}

	statusData := buildRowStatusData(root, rowName, state, resolution, focusedRow, warnings)
	if flags.json {
		return a.okJSON("furrow row status", statusData)
	}

	row := statusData["row"].(map[string]any)
	_, _ = fmt.Fprintf(a.stdout, "row: %s\nstep: %s\nstatus: %s\n", row["name"], row["step"], row["step_status"])
	return 0
}

func (a *App) runRowTransition(args []string) int {
	positionals, flags, err := parseArgs(args, map[string]bool{"step": true}, nil)
	if err != nil {
		return a.fail("furrow row transition", err, false)
	}
	if len(positionals) != 1 {
		return a.fail("furrow row transition", &cliError{exit: 1, code: "usage", message: "usage: furrow row transition <row-name> --step <step> [--json]"}, flags.json)
	}
	targetStep := flags.values["step"]
	if targetStep == "" {
		return a.fail("furrow row transition", &cliError{exit: 1, code: "usage", message: "missing required flag --step"}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow row transition", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	rowName := positionals[0]
	statePath := statePathForRow(root, rowName)
	if !fileExists(statePath) {
		return a.fail("furrow row transition", &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("state file not found for row %q", rowName)}, flags.json)
	}
	state, err := loadJSONMap(statePath)
	if err != nil {
		return a.fail("furrow row transition", &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", statePath), details: map[string]any{"path": statePath}}, flags.json)
	}
	if isArchivedState(state) {
		return a.fail("furrow row transition", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q is archived", rowName)}, flags.json)
	}

	currentStep, ok := getString(state, "step")
	if !ok || currentStep == "" {
		return a.fail("furrow row transition", &cliError{exit: 3, code: "invalid_state", message: "row state missing current step"}, flags.json)
	}
	steps, ok := stepsSequenceFromState(state)
	if !ok {
		return a.fail("furrow row transition", &cliError{exit: 3, code: "invalid_state", message: "row state missing valid steps_sequence"}, flags.json)
	}
	currentIdx := indexOfStep(steps, currentStep)
	targetIdx := indexOfStep(steps, targetStep)
	if currentIdx == -1 || targetIdx == -1 {
		return a.fail("furrow row transition", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("transition requires known steps; current=%q target=%q", currentStep, targetStep)}, flags.json)
	}
	if targetIdx != currentIdx+1 {
		return a.fail("furrow row transition", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("only adjacent forward transitions are supported; current=%q target=%q", currentStep, targetStep)}, flags.json)
	}
	if getStringDefault(state, "step_status", "") != "completed" {
		return a.fail("furrow row transition", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q must have step_status=completed before advancing", rowName)}, flags.json)
	}

	artifacts := currentStepArtifacts(root, rowName, state)
	seed := rowSeedSurface(root, state)
	blockers := rowBlockers(state, seed, artifacts, rowBlockersOpts{})
	if len(blockers) > 0 {
		return a.fail("furrow row transition", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q is blocked from advancing", rowName), details: map[string]any{"blockers": blockers, "artifact_validation": summarizeArtifactValidation(artifacts)}}, flags.json)
	}

	now := nowRFC3339()
	boundary := currentStep + "->" + targetStep
	evidencePath, err := writeGateEvidence(root, rowName, boundary, map[string]any{
		"boundary":  boundary,
		"overall":   "pass",
		"reviewer":  "furrow row transition",
		"timestamp": now,
		"notes":     "backend-canonical checkpoint evidence for the narrow /work loop transition",
		"phase_a": map[string]any{
			"step_status_required": getStringDefault(state, "step_status", ""),
			"seed":                 seed,
			"artifacts":            artifacts,
			"artifact_validation":  summarizeArtifactValidation(artifacts),
			"blockers":             blockers,
		},
	})
	if err != nil {
		return a.fail("furrow row transition", err, flags.json)
	}
	state["step"] = targetStep
	state["step_status"] = "not_started"
	state["updated_at"] = now

	writtenRecord := false
	gates, ok := asSlice(state["gates"])
	if !ok {
		if state["gates"] == nil {
			gates = []any{}
		} else {
			return a.fail("furrow row transition", &cliError{exit: 3, code: "invalid_state", message: "row state has non-array gates field"}, flags.json)
		}
	}
	gates = append(gates, map[string]any{
		"boundary":      boundary,
		"outcome":       "pass",
		"decided_by":    "manual",
		"evidence":      "furrow row transition enforced adjacent ordering, completed-step requirement, blocker taxonomy checks, seed sync, and per-artifact validation; summary regeneration and evaluator phases were not performed",
		"evidence_path": evidencePath,
		"timestamp":     now,
	})
	state["gates"] = gates
	writtenRecord = true

	if seedID, ok := getString(state, "seed_id"); ok && strings.TrimSpace(seedID) != "" {
		seedRecord, ok, err := latestSeedRecord(root, seedID)
		if err != nil {
			return a.fail("furrow row transition", err, flags.json)
		}
		if !ok {
			return a.fail("furrow row transition", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("linked seed %q was not found", seedID)}, flags.json)
		}
		if _, err := appendSeedStatus(root, seedRecord, seedStatusForStep(targetStep)); err != nil {
			return a.fail("furrow row transition", err, flags.json)
		}
	}

	if err := writeJSONMapAtomic(statePath, state); err != nil {
		return a.fail("furrow row transition", &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to write %s", statePath), details: map[string]any{"path": statePath, "error": err.Error()}}, flags.json)
	}

	data := map[string]any{
		"row": map[string]any{
			"name":          rowName,
			"previous_step": currentStep,
			"step":          targetStep,
			"step_status":   "not_started",
			"updated_at":    now,
		},
		"changed":                   []string{"step", "step_status", "updated_at", "gates"},
		"transition_record_written": writtenRecord,
		"paths": map[string]any{
			"state": statePath,
		},
		"limitations": []string{
			"manual adjacent forward transition only",
			"supervised confirmation remains adapter-driven rather than CLI-prompted",
			"summary regeneration not performed",
			"conditional/fail outcomes not implemented",
		},
		"checkpoint_evidence": map[string]any{
			"path":                evidencePath,
			"artifact_validation": summarizeArtifactValidation(artifacts),
		},
	}
	if flags.json {
		return a.okJSON("furrow row transition", data)
	}
	_, _ = fmt.Fprintf(a.stdout, "transitioned %s: %s -> %s\n", rowName, currentStep, targetStep)
	return 0
}

func (a *App) runRowComplete(args []string) int {
	positionals, flags, err := parseArgs(args, nil, nil)
	if err != nil {
		return a.fail("furrow row complete", err, false)
	}
	if len(positionals) != 1 {
		return a.fail("furrow row complete", &cliError{exit: 1, code: "usage", message: "usage: furrow row complete <row-name> [--json]"}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow row complete", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	rowName := positionals[0]
	statePath := statePathForRow(root, rowName)
	if !fileExists(statePath) {
		return a.fail("furrow row complete", &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("state file not found for row %q", rowName)}, flags.json)
	}
	state, err := loadJSONMap(statePath)
	if err != nil {
		return a.fail("furrow row complete", &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", statePath), details: map[string]any{"path": statePath}}, flags.json)
	}
	if isArchivedState(state) {
		return a.fail("furrow row complete", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q is archived", rowName)}, flags.json)
	}

	artifacts := currentStepArtifacts(root, rowName, state)
	for _, artifact := range artifacts {
		if required, _ := artifact["required"].(bool); !required {
			continue
		}
		if exists, _ := artifact["exists"].(bool); !exists {
			return a.fail("furrow row complete", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("required current-step artifact %v is missing", artifact["label"]), details: map[string]any{"artifact": artifact}}, flags.json)
		}
		if incomplete, _ := artifact["incomplete"].(bool); incomplete {
			return a.fail("furrow row complete", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("current-step artifact %v is still an incomplete scaffold", artifact["label"]), details: map[string]any{"artifact": artifact}}, flags.json)
		}
		if blockingArtifactValidation(artifact) {
			return a.fail("furrow row complete", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("current-step artifact %v failed validation", artifact["label"]), details: map[string]any{"artifact": artifact}}, flags.json)
		}
	}

	beforeCounts := summarizeDeliverableCounts(state)
	previousStatus, _ := getString(state, "step_status")
	changed := make([]string, 0, 3)
	if previousStatus != "completed" {
		state["step_status"] = "completed"
		changed = append(changed, "step_status")
	}

	deliverablesUpdated, err := completeDeliverables(state)
	if err != nil {
		return a.fail("furrow row complete", err, flags.json)
	}
	if deliverablesUpdated > 0 {
		changed = append(changed, "deliverables")
	}

	writePerformed := false
	if len(changed) > 0 {
		now := nowRFC3339()
		state["updated_at"] = now
		changed = append(changed, "updated_at")
		if err := writeJSONMapAtomic(statePath, state); err != nil {
			return a.fail("furrow row complete", &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to write %s", statePath), details: map[string]any{"path": statePath, "error": err.Error()}}, flags.json)
		}
		writePerformed = true
	}

	afterCounts := summarizeDeliverableCounts(state)
	data := map[string]any{
		"row": map[string]any{
			"name":                 rowName,
			"step":                 getStringDefault(state, "step", "unknown"),
			"previous_step_status": nilIfEmpty(previousStatus),
			"step_status":          getStringDefault(state, "step_status", "completed"),
			"updated_at":           nilIfEmpty(getStringDefault(state, "updated_at", "")),
		},
		"deliverables": map[string]any{
			"before":  beforeCounts,
			"after":   afterCounts,
			"updated": deliverablesUpdated,
		},
		"changed":         changed,
		"write_performed": writePerformed,
		"paths": map[string]any{
			"state": statePath,
		},
		"limitations": []string{
			"bookkeeping only; no transition semantics were performed",
			"bookkeeping only; no review/archive semantics were performed",
			"bookkeeping only; no summary regeneration was performed",
		},
		"artifact_validation": summarizeArtifactValidation(artifacts),
	}
	if flags.json {
		return a.okJSON("furrow row complete", data)
	}
	_, _ = fmt.Fprintf(a.stdout, "completed bookkeeping for %s\n", rowName)
	return 0
}

func (a *App) runRowArchive(args []string) int {
	positionals, flags, err := parseArgs(args, map[string]bool{"supersedes-confirmed": true}, nil)
	if err != nil {
		return a.fail("furrow row archive", err, false)
	}
	if len(positionals) != 1 {
		return a.fail("furrow row archive", &cliError{exit: 1, code: "usage", message: "usage: furrow row archive <row-name> [--json]"}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow row archive", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	rowName := positionals[0]
	statePath := statePathForRow(root, rowName)
	if !fileExists(statePath) {
		return a.fail("furrow row archive", &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("state file not found for row %q", rowName)}, flags.json)
	}
	state, err := loadJSONMap(statePath)
	if err != nil {
		return a.fail("furrow row archive", &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", statePath), details: map[string]any{"path": statePath}}, flags.json)
	}
	if isArchivedState(state) {
		return a.fail("furrow row archive", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q is already archived", rowName)}, flags.json)
	}
	if getStringDefault(state, "step", "") != "review" {
		return a.fail("furrow row archive", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q must be at step review before archiving", rowName)}, flags.json)
	}
	if getStringDefault(state, "step_status", "") != "completed" {
		return a.fail("furrow row archive", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q must have step_status=completed before archiving", rowName)}, flags.json)
	}

	artifacts := currentStepArtifacts(root, rowName, state)
	seed := rowSeedSurface(root, state)
	archiveOpts := rowBlockersOpts{
		SupersedesConfirmed:  flags.values["supersedes-confirmed"],
		DefinitionSupersedes: definitionSupersedes(root, rowName),
	}
	blockers := rowBlockers(state, seed, artifacts, archiveOpts)
	if len(blockers) > 0 {
		return a.fail("furrow row archive", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q is blocked from archiving", rowName), details: map[string]any{"blockers": blockers}}, flags.json)
	}
	reviewGate, ok := latestPassingReviewGate(state)
	if !ok {
		return a.fail("furrow row archive", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q cannot archive without a passing ->review gate", rowName)}, flags.json)
	}
	archiveCeremony := archiveCeremonySurface(root, rowName, state, artifacts)

	// Build phase_a notes: include supersedence acknowledgement if applicable.
	phaseANotes := "backend-canonical archive checkpoint evidence for the narrow /work loop"
	if archiveOpts.DefinitionSupersedes != nil && archiveOpts.SupersedesConfirmed != "" {
		phaseANotes = fmt.Sprintf("supersedence confirmed: %s", archiveOpts.SupersedesConfirmed)
	}

	now := nowRFC3339()
	boundary := "review->archive"
	evidencePath, err := writeGateEvidence(root, rowName, boundary, map[string]any{
		"boundary":  boundary,
		"overall":   "pass",
		"reviewer":  "furrow row archive",
		"timestamp": now,
		"notes":     "backend-canonical archive checkpoint evidence for the narrow /work loop",
		"phase_a": map[string]any{
			"notes":               phaseANotes,
			"review_gate":         latestGateSummary(map[string]any{"gates": []any{reviewGate}}),
			"seed":                seed,
			"artifacts":           artifacts,
			"artifact_validation": summarizeArtifactValidation(artifacts),
			"archive_ceremony":    archiveCeremony,
			"blockers":            blockers,
		},
	})
	if err != nil {
		return a.fail("furrow row archive", err, flags.json)
	}

	gates, ok := asSlice(state["gates"])
	if !ok {
		if state["gates"] == nil {
			gates = []any{}
		} else {
			return a.fail("furrow row archive", &cliError{exit: 3, code: "invalid_state", message: "row state has non-array gates field"}, flags.json)
		}
	}
	gates = append(gates, map[string]any{
		"boundary":      boundary,
		"outcome":       "pass",
		"decided_by":    "manual",
		"evidence":      "furrow row archive enforced review-complete preconditions, shared blocker taxonomy, and durable archive checkpoint evidence",
		"evidence_path": evidencePath,
		"timestamp":     now,
	})
	state["gates"] = gates
	state["archived_at"] = now
	state["updated_at"] = now

	if err := writeJSONMapAtomic(statePath, state); err != nil {
		return a.fail("furrow row archive", &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to write %s", statePath), details: map[string]any{"path": statePath, "error": err.Error()}}, flags.json)
	}

	data := map[string]any{
		"row": map[string]any{
			"name":        rowName,
			"step":        getStringDefault(state, "step", "review"),
			"step_status": getStringDefault(state, "step_status", "completed"),
			"archived":    true,
			"archived_at": now,
			"updated_at":  now,
		},
		"paths": map[string]any{
			"state":               statePath,
			"checkpoint_evidence": evidencePath,
		},
		"review_gate": map[string]any{
			"boundary":      nilIfEmpty(getStringDefault(reviewGate, "boundary", "")),
			"outcome":       nilIfEmpty(getStringDefault(reviewGate, "outcome", "")),
			"timestamp":     nilIfEmpty(getStringDefault(reviewGate, "timestamp", "")),
			"evidence_path": optionalPath(getStringDefault(reviewGate, "evidence_path", "")),
		},
		"archive_ceremony": archiveCeremony,
	}
	if flags.json {
		return a.okJSON("furrow row archive", data)
	}
	_, _ = fmt.Fprintf(a.stdout, "archived %s\n", rowName)
	return 0
}

func listRows(root, focusedRow string) ([]rowListEntry, []map[string]any, error) {
	paths, err := filepath.Glob(filepath.Join(root, ".furrow", "rows", "*", "state.json"))
	if err != nil {
		return nil, nil, err
	}
	rows := make([]rowListEntry, 0, len(paths))
	warnings := make([]map[string]any, 0)
	for _, path := range paths {
		state, err := loadJSONMap(path)
		if err != nil {
			warnings = append(warnings, map[string]any{"code": "invalid_state_json", "path": path, "message": err.Error()})
			continue
		}
		rowName := getStringDefault(state, "name", filepath.Base(filepath.Dir(path)))
		entry := rowListEntry{
			Name:              rowName,
			Title:             getStringDefault(state, "title", rowName),
			Step:              getStringDefault(state, "step", "unknown"),
			StepStatus:        getStringDefault(state, "step_status", "unknown"),
			Archived:          isArchivedState(state),
			Focused:           focusedRow != "" && focusedRow == rowName,
			UpdatedAt:         getStringDefault(state, "updated_at", ""),
			Branch:            normalizeBranch(state),
			DeliverableCounts: summarizeDeliverableCounts(state),
			StatePath:         path,
		}
		rows = append(rows, entry)
	}
	sortRowEntries(rows)
	return rows, warnings, nil
}

func resolveRowForStatus(root, explicit string) (string, string, string, []map[string]any, error) {
	warnings := make([]map[string]any, 0)
	focusedRow, focusedExists, focusedErr := readFocusedRowName(root)
	if focusedErr != nil {
		warnings = append(warnings, map[string]any{"code": "focused_row_invalid", "message": focusedErr.Error()})
	}
	if explicit != "" {
		if !fileExists(statePathForRow(root, explicit)) {
			return "", "", focusedRow, warnings, &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("state file not found for row %q", explicit)}
		}
		return explicit, "explicit", focusedRow, warnings, nil
	}

	if focusedExists && focusedErr == nil && focusedRow != "" {
		statePath := statePathForRow(root, focusedRow)
		if fileExists(statePath) {
			state, err := loadJSONMap(statePath)
			if err != nil {
				return "", "", focusedRow, warnings, &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", statePath), details: map[string]any{"path": statePath}}
			}
			if !isArchivedState(state) {
				return focusedRow, "focused", focusedRow, warnings, nil
			}
			warnings = append(warnings, map[string]any{"code": "focused_row_archived", "message": fmt.Sprintf("focused row %q is archived; falling back to latest active row", focusedRow)})
		} else {
			warnings = append(warnings, map[string]any{"code": "focused_row_missing", "message": fmt.Sprintf("focused row %q is missing; falling back to latest active row", focusedRow)})
		}
	}

	rows, listWarnings, err := listRows(root, focusedRow)
	warnings = append(warnings, listWarnings...)
	if err != nil {
		return "", "", focusedRow, warnings, err
	}
	for _, row := range rows {
		if !row.Archived {
			return row.Name, "latest_active", focusedRow, warnings, nil
		}
	}
	return "", "", focusedRow, warnings, &cliError{exit: 5, code: "not_found", message: "no explicit row, usable focused row, or active row found"}
}

func buildRowStatusData(root, rowName string, state map[string]any, resolution, focusedRow string, warnings []map[string]any) map[string]any {
	rowDir := rowDirFor(root, rowName)
	latestGate := latestGateSummary(state)
	steps, _ := stepsSequenceFromState(state)
	nextTransitions := nextValidTransitions(state, steps)
	seed := rowSeedSurface(root, state)
	artifacts := currentStepArtifacts(root, rowName, state)
	blockers := rowBlockers(state, seed, artifacts, rowBlockersOpts{})
	checkpoint := rowCheckpointSurface(root, rowName, state, blockers, seed, artifacts)
	rowWarnings := append([]map[string]any{}, warnings...)
	if seedState, _ := seed["state"].(string); seedState == "missing" {
		rowWarnings = append(rowWarnings, map[string]any{"code": "missing_seed", "message": "row has no linked seed; new /work flows should initialize or link one"})
	}
	return map[string]any{
		"resolution": map[string]any{
			"source":        resolution,
			"requested_row": nilIfEmpty(rowName),
			"focused_row":   nilIfEmpty(focusedRow),
		},
		"row": map[string]any{
			"name":        getStringDefault(state, "name", rowName),
			"title":       getStringDefault(state, "title", rowName),
			"description": nilIfEmpty(getStringDefault(state, "description", "")),
			"focused":     focusedRow == rowName,
			"archived":    isArchivedState(state),
			"step":        getStringDefault(state, "step", "unknown"),
			"step_status": getStringDefault(state, "step_status", "unknown"),
			"mode":        nilIfEmpty(getStringDefault(state, "mode", "")),
			"branch":      normalizeBranch(state),
			"updated_at":  nilIfEmpty(getStringDefault(state, "updated_at", "")),
			"deliverables": map[string]any{
				"counts": summarizeDeliverableCounts(state),
				"items":  deliverableItems(state),
			},
			"gates": map[string]any{
				"count":              gateCount(state),
				"latest":             latestGate,
				"pending_blockers":   blockers,
				"transition_history": gateHistory(state),
			},
			"artifact_paths": map[string]any{
				"row_dir":     rowDir,
				"state":       statePathForRow(root, rowName),
				"definition":  filepath.Join(rowDir, "definition.yaml"),
				"summary":     filepath.Join(rowDir, "summary.md"),
				"plan":        optionalPath(filepath.Join(rowDir, "plan.json")),
				"reviews_dir": optionalPath(filepath.Join(rowDir, "reviews")),
			},
			"current_step": map[string]any{
				"name":      getStringDefault(state, "step", "unknown"),
				"artifacts": artifacts,
				"note":      "artifact existence is never completion",
			},
			"next_valid_transitions": nextTransitions,
		},
		"seed":       seed,
		"blockers":   blockers,
		"checkpoint": checkpoint,
		"warnings":   rowWarnings,
	}
}

func completeDeliverables(state map[string]any) (int, error) {
	raw, exists := state["deliverables"]
	if !exists || raw == nil {
		return 0, nil
	}
	deliverables, ok := asMap(raw)
	if !ok {
		return 0, &cliError{exit: 3, code: "invalid_state", message: "row state has non-object deliverables field"}
	}

	names := make([]string, 0, len(deliverables))
	for name := range deliverables {
		names = append(names, name)
	}
	sort.Strings(names)

	updated := 0
	for _, name := range names {
		entry, ok := deliverables[name].(map[string]any)
		if !ok {
			return 0, &cliError{exit: 3, code: "invalid_state", message: fmt.Sprintf("deliverable %q is not an object", name)}
		}
		status, _ := getString(entry, "status")
		if status == "completed" {
			continue
		}
		entry["status"] = "completed"
		updated++
	}
	return updated, nil
}

func summarizeDeliverableCounts(state map[string]any) map[string]int {
	counts := map[string]int{"total": 0, "completed": 0, "in_progress": 0, "blocked": 0, "not_started": 0, "unknown": 0}
	deliverables, ok := asMap(state["deliverables"])
	if !ok {
		return counts
	}
	for _, raw := range deliverables {
		counts["total"]++
		entry, ok := raw.(map[string]any)
		if !ok {
			counts["unknown"]++
			continue
		}
		status, _ := getString(entry, "status")
		switch status {
		case "completed":
			counts["completed"]++
		case "in_progress":
			counts["in_progress"]++
		case "blocked":
			counts["blocked"]++
		case "not_started":
			counts["not_started"]++
		default:
			counts["unknown"]++
		}
	}
	return counts
}

func deliverableItems(state map[string]any) []map[string]any {
	deliverables, ok := asMap(state["deliverables"])
	if !ok {
		return []map[string]any{}
	}
	names := make([]string, 0, len(deliverables))
	for name := range deliverables {
		names = append(names, name)
	}
	sort.Strings(names)
	items := make([]map[string]any, 0, len(names))
	for _, name := range names {
		item := map[string]any{"name": name}
		entry, ok := deliverables[name].(map[string]any)
		if ok {
			item["status"] = nilIfEmpty(getStringDefault(entry, "status", ""))
			if wave, ok := intFromAny(entry["wave"]); ok {
				item["wave"] = wave
			} else {
				item["wave"] = nil
			}
			if corrections, ok := intFromAny(entry["corrections"]); ok {
				item["corrections"] = corrections
			} else {
				item["corrections"] = nil
			}
			if assigned, ok := getString(entry, "assigned_to"); ok {
				item["assigned_to"] = assigned
			} else {
				item["assigned_to"] = nil
			}
		} else {
			item["status"] = nil
			item["wave"] = nil
			item["corrections"] = nil
			item["assigned_to"] = nil
		}
		items = append(items, item)
	}
	return items
}

func gateCount(state map[string]any) int {
	gates, ok := asSlice(state["gates"])
	if !ok {
		return 0
	}
	return len(gates)
}

func latestGateSummary(state map[string]any) any {
	gates, ok := asSlice(state["gates"])
	if !ok || len(gates) == 0 {
		return nil
	}
	gate, ok := gates[len(gates)-1].(map[string]any)
	if !ok {
		return nil
	}
	return map[string]any{
		"boundary":      nilIfEmpty(getStringDefault(gate, "boundary", "")),
		"outcome":       nilIfEmpty(getStringDefault(gate, "outcome", "")),
		"decided_by":    nilIfEmpty(getStringDefault(gate, "decided_by", "")),
		"timestamp":     nilIfEmpty(getStringDefault(gate, "timestamp", "")),
		"evidence":      nilIfEmpty(getStringDefault(gate, "evidence", "")),
		"evidence_path": optionalPath(getStringDefault(gate, "evidence_path", "")),
	}
}

func nextValidTransitions(state map[string]any, steps []string) []map[string]any {
	if isArchivedState(state) {
		return []map[string]any{}
	}
	if len(steps) == 0 {
		steps = defaultStepsSequence()
	}
	current := getStringDefault(state, "step", "")
	idx := indexOfStep(steps, current)
	if idx == -1 || idx+1 >= len(steps) {
		return []map[string]any{}
	}
	return []map[string]any{{"step": steps[idx+1], "kind": "forward_adjacent"}}
}

func normalizeBranch(state map[string]any) any {
	if branch, ok := getString(state, "branch"); ok && branch != "" {
		return branch
	}
	return nil
}

func optionalPath(path string) any {
	if _, err := os.Stat(path); err == nil {
		return path
	}
	return nil
}

func nilIfEmpty(value string) any {
	if value == "" {
		return nil
	}
	return value
}

func mustJSON(v any) string {
	payload, _ := json.Marshal(v)
	return string(payload)
}
