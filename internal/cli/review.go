package cli

import "fmt"

func (a *App) runReview(args []string) int {
	if len(args) == 0 {
		a.printReviewHelp()
		return 0
	}

	switch args[0] {
	case "status":
		return a.runReviewStatus(args[1:])
	case "validate":
		return a.runReviewValidate(args[1:])
	case "run", "cross-model":
		return a.runStubLeaf("furrow review "+args[0], args[1:])
	case "help", "-h", "--help":
		a.printReviewHelp()
		return 0
	default:
		return a.fail("furrow review", &cliError{exit: 1, code: "usage", message: fmt.Sprintf("unknown review command %q", args[0])}, false)
	}
}

func (a *App) runReviewStatus(args []string) int {
	positionals, flags, err := parseArgs(args, nil, nil)
	if err != nil {
		return a.fail("furrow review status", err, false)
	}
	if len(positionals) > 1 {
		return a.fail("furrow review status", &cliError{exit: 1, code: "usage", message: "usage: furrow review status [row-name] [--json]"}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow review status", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	explicit := ""
	if len(positionals) == 1 {
		explicit = positionals[0]
	}
	rowName, resolution, focusedRow, warnings, err := resolveRowForStatus(root, explicit)
	if err != nil {
		return a.fail("furrow review status", err, flags.json)
	}

	state, err := loadJSONMap(statePathForRow(root, rowName))
	if err != nil {
		return a.fail("furrow review status", &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", statePathForRow(root, rowName)), details: map[string]any{"path": statePathForRow(root, rowName)}}, flags.json)
	}

	reviewArtifacts := reviewArtifactsForRow(root, rowName, state)
	reviewSummary := reviewArtifactSummary(reviewArtifacts)
	seed := rowSeedSurface(root, state)
	currentArtifacts := currentStepArtifacts(root, rowName, state)
	blockers := rowBlockers(state, seed, currentArtifacts, rowBlockersOpts{Root: root, RowName: rowName})
	checkpoint := rowCheckpointSurface(root, rowName, state, blockers, seed, currentArtifacts)

	data := map[string]any{
		"resolution": map[string]any{
			"source":        resolution,
			"requested_row": nilIfEmpty(rowName),
			"focused_row":   nilIfEmpty(focusedRow),
		},
		"row": map[string]any{
			"name":        getStringDefault(state, "name", rowName),
			"title":       getStringDefault(state, "title", rowName),
			"archived":    isArchivedState(state),
			"step":        getStringDefault(state, "step", "unknown"),
			"step_status": getStringDefault(state, "step_status", "unknown"),
			"updated_at":  nilIfEmpty(getStringDefault(state, "updated_at", "")),
		},
		"review": map[string]any{
			"artifacts":             reviewArtifacts,
			"summary":               reviewSummary,
			"current_boundary":      checkpoint["boundary"],
			"ready_to_archive":      checkpoint["action"] == "archive" && checkpoint["ready_to_advance"] == true,
			"current_step_blockers": blockers,
		},
		"warnings": warnings,
	}
	if flags.json {
		return a.okJSON("furrow review status", data)
	}
	_, _ = fmt.Fprintf(a.stdout, "review status for %s\n", rowName)
	return 0
}

func (a *App) runReviewValidate(args []string) int {
	positionals, flags, err := parseArgs(args, nil, nil)
	if err != nil {
		return a.fail("furrow review validate", err, false)
	}
	if len(positionals) > 1 {
		return a.fail("furrow review validate", &cliError{exit: 1, code: "usage", message: "usage: furrow review validate [row-name] [--json]"}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow review validate", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	explicit := ""
	if len(positionals) == 1 {
		explicit = positionals[0]
	}
	rowName, resolution, focusedRow, warnings, err := resolveRowForStatus(root, explicit)
	if err != nil {
		return a.fail("furrow review validate", err, flags.json)
	}
	state, err := loadJSONMap(statePathForRow(root, rowName))
	if err != nil {
		return a.fail("furrow review validate", &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", statePathForRow(root, rowName)), details: map[string]any{"path": statePathForRow(root, rowName)}}, flags.json)
	}

	reviewArtifacts := reviewArtifactsForRow(root, rowName, state)
	reviewSummary := reviewArtifactSummary(reviewArtifacts)
	problems := make([]map[string]any, 0)
	for _, artifact := range reviewArtifacts {
		validation, _ := artifact["validation"].(map[string]any)
		status, _ := validation["status"].(string)
		if status == "pass" {
			continue
		}
		problems = append(problems, map[string]any{
			"artifact_id": artifact["id"],
			"label":       artifact["label"],
			"path":        artifact["path"],
			"status":      nilIfEmpty(status),
			"findings":    validation["findings"],
		})
	}

	data := map[string]any{
		"resolution": map[string]any{
			"source":        resolution,
			"requested_row": nilIfEmpty(rowName),
			"focused_row":   nilIfEmpty(focusedRow),
		},
		"row": map[string]any{
			"name":        getStringDefault(state, "name", rowName),
			"title":       getStringDefault(state, "title", rowName),
			"archived":    isArchivedState(state),
			"step":        getStringDefault(state, "step", "unknown"),
			"step_status": getStringDefault(state, "step_status", "unknown"),
			"updated_at":  nilIfEmpty(getStringDefault(state, "updated_at", "")),
		},
		"review": map[string]any{
			"artifacts": reviewArtifacts,
			"summary":   reviewSummary,
		},
		"problems": problems,
		"warnings": warnings,
	}
	if len(problems) > 0 {
		return a.fail("furrow review validate", &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("review artifacts for row %q failed validation", rowName), details: data}, flags.json)
	}
	if flags.json {
		return a.okJSON("furrow review validate", data)
	}
	_, _ = fmt.Fprintf(a.stdout, "review validation passed for %s\n", rowName)
	return 0
}
