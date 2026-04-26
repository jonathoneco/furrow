package cli

import (
	"fmt"
	"os"
	"path/filepath"
)

type doctorCheck struct {
	ID       string         `json:"id"`
	Status   string         `json:"status"`
	Severity string         `json:"severity"`
	Message  string         `json:"message"`
	Details  map[string]any `json:"details,omitempty"`
}

func (a *App) runDoctor(args []string) int {
	positionals, flags, err := parseArgs(args, map[string]bool{"host": true}, nil)
	if err != nil {
		return a.fail("furrow doctor", err, false)
	}
	if len(positionals) > 0 {
		return a.fail("furrow doctor", &cliError{exit: 1, code: "usage", message: "usage: furrow doctor [--host <host>] [--json]"}, flags.json)
	}

	host := flags.values["host"]
	if host == "" {
		host = "auto"
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow doctor", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	result := runDoctorChecks(root, host)
	hasFailures := result["summary"].(map[string]any)["fail"].(int) > 0
	if flags.json {
		if hasFailures {
			return a.writeJSON(envelope{OK: false, Command: "furrow doctor", Version: contractVersion, Data: result, Error: &errBody{Code: "validation_failed", Message: "backend structural readiness checks failed", Details: map[string]any{"fail": result["summary"].(map[string]any)["fail"], "warn": result["summary"].(map[string]any)["warn"]}}}, 3)
		}
		return a.okJSON("furrow doctor", result)
	}

	checks := result["checks"].([]doctorCheck)
	for _, check := range checks {
		_, _ = fmt.Fprintf(a.stdout, "[%s] %s: %s\n", check.Status, check.ID, check.Message)
	}
	if hasFailures {
		return 3
	}
	return 0
}

func runDoctorChecks(root, host string) map[string]any {
	checks := make([]doctorCheck, 0)
	add := func(id, status, severity, message string, details map[string]any) {
		checks = append(checks, doctorCheck{ID: id, Status: status, Severity: severity, Message: message, Details: details})
	}

	add("furrow_root_present", "pass", "error", ".furrow root found", map[string]any{"root": root})

	rowsDir := filepath.Join(root, ".furrow", "rows")
	almanacDir := filepath.Join(root, ".furrow", "almanac")
	if info, err := os.Stat(rowsDir); err == nil && info.IsDir() {
		add("rows_dir_present", "pass", "error", "rows directory present", map[string]any{"path": rowsDir})
	} else {
		add("rows_dir_present", "fail", "error", "rows directory missing", map[string]any{"path": rowsDir})
	}
	if info, err := os.Stat(almanacDir); err == nil && info.IsDir() {
		add("almanac_dir_present", "pass", "error", "almanac directory present", map[string]any{"path": almanacDir})
	} else {
		add("almanac_dir_present", "fail", "error", "almanac directory missing", map[string]any{"path": almanacDir})
	}

	for _, required := range []struct {
		id   string
		path string
	}{
		{id: "todos_present", path: filepath.Join(almanacDir, "todos.yaml")},
		{id: "observations_present", path: filepath.Join(almanacDir, "observations.yaml")},
		{id: "roadmap_present", path: filepath.Join(almanacDir, "roadmap.yaml")},
	} {
		if fileExists(required.path) {
			add(required.id, "pass", "error", "required almanac file present", map[string]any{"path": required.path})
		} else {
			add(required.id, "fail", "error", "required almanac file missing", map[string]any{"path": required.path})
		}
	}

	rowPaths, _ := filepath.Glob(filepath.Join(rowsDir, "*", "state.json"))
	parseFailures := 0
	for _, path := range rowPaths {
		if _, err := loadJSONMap(path); err != nil {
			parseFailures++
		}
	}
	if parseFailures == 0 {
		add("row_state_parse", "pass", "error", "all row state files parsed successfully", map[string]any{"state_files": len(rowPaths)})
	} else {
		add("row_state_parse", "fail", "error", "one or more row state files could not be parsed", map[string]any{"state_files": len(rowPaths), "parse_failures": parseFailures})
	}

	focusedRow, focusedExists, focusedErr := readFocusedRowName(root)
	switch {
	case !focusedExists:
		add("focused_row", "warn", "warning", "no focused row set", nil)
	case focusedErr != nil:
		add("focused_row", "warn", "warning", focusedErr.Error(), nil)
	case !fileExists(statePathForRow(root, focusedRow)):
		add("focused_row", "warn", "warning", fmt.Sprintf("focused row %q does not exist", focusedRow), map[string]any{"row": focusedRow})
	default:
		state, err := loadJSONMap(statePathForRow(root, focusedRow))
		if err != nil {
			add("focused_row", "fail", "error", fmt.Sprintf("focused row %q has unreadable state", focusedRow), map[string]any{"row": focusedRow})
		} else if isArchivedState(state) {
			add("focused_row", "warn", "warning", fmt.Sprintf("focused row %q is archived", focusedRow), map[string]any{"row": focusedRow})
		} else {
			add("focused_row", "pass", "error", fmt.Sprintf("focused row %q is usable", focusedRow), map[string]any{"row": focusedRow})
		}
	}

	// AC11: warn if Claude teams experimental flag is not set.
	if host == "claude" || host == "auto" {
		teams := os.Getenv("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS")
		if teams == "1" {
			add("experimental_agent_teams", "pass", "warning", "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 is set", nil)
		} else {
			add("experimental_agent_teams", "warn", "warning", "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is not set to 1; multi-agent dispatch requires this flag", map[string]any{"current_value": teams})
		}
	}

	almanacResult, err := validateAlmanac(root)
	if err != nil {
		add("almanac_validation", "fail", "error", err.Error(), nil)
	} else {
		summary := almanacResult.Summary
		errorCount := summary["error_count"].(int)
		warningCount := summary["warning_count"].(int)
		status := "pass"
		message := "almanac validation passed"
		severity := "error"
		if errorCount > 0 {
			status = "fail"
			message = "almanac validation found errors"
			severity = "error"
		} else if warningCount > 0 {
			status = "warn"
			message = "almanac validation found warnings"
			severity = "warning"
		}
		add("almanac_validation", status, severity, message, map[string]any{"error_count": errorCount, "warning_count": warningCount})
	}

	passCount := 0
	warnCount := 0
	failCount := 0
	for _, check := range checks {
		switch check.Status {
		case "pass":
			passCount++
		case "warn":
			warnCount++
		case "fail":
			failCount++
		}
	}

	cwd, _ := os.Getwd()
	return map[string]any{
		"host": host,
		"cwd":  cwd,
		"root": root,
		"summary": map[string]any{
			"pass": passCount,
			"warn": warnCount,
			"fail": failCount,
		},
		"checks": checks,
	}
}
