package cli

import (
	"bufio"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	yaml "gopkg.in/yaml.v3"
)

type rowInitOptions struct {
	Title      string
	Mode       string
	GatePolicy string
	SourceTodo string
	SeedID     string
}

func (a *App) runRowInit(args []string) int {
	positionals, flags, err := parseArgs(args, map[string]bool{
		"title":       true,
		"mode":        true,
		"gate-policy": true,
		"source-todo": true,
		"seed-id":     true,
	}, nil)
	if err != nil {
		return a.fail("furrow row init", err, false)
	}
	if len(positionals) != 1 {
		return a.fail("furrow row init", &cliError{exit: 1, code: "usage", message: "usage: furrow row init <row-name> [--title <title>] [--mode <code|research>] [--gate-policy <supervised|delegated|autonomous>] [--source-todo <id>] [--seed-id <id>] [--json]"}, flags.json)
	}

	rowName := positionals[0]
	if !isValidSlug(rowName) {
		return a.fail("furrow row init", &cliError{exit: 1, code: "usage", message: fmt.Sprintf("row name %q must be kebab-case", rowName)}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow row init", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	opts := rowInitOptions{
		Title:      strings.TrimSpace(flags.values["title"]),
		Mode:       strings.TrimSpace(flags.values["mode"]),
		GatePolicy: strings.TrimSpace(flags.values["gate-policy"]),
		SourceTodo: strings.TrimSpace(flags.values["source-todo"]),
		SeedID:     strings.TrimSpace(flags.values["seed-id"]),
	}
	if opts.Mode != "" && opts.Mode != "code" && opts.Mode != "research" {
		return a.fail("furrow row init", &cliError{exit: 1, code: "usage", message: fmt.Sprintf("invalid mode %q", opts.Mode)}, flags.json)
	}
	if opts.GatePolicy != "" && !isValidGatePolicy(opts.GatePolicy) {
		return a.fail("furrow row init", &cliError{exit: 1, code: "usage", message: fmt.Sprintf("invalid gate policy %q", opts.GatePolicy)}, flags.json)
	}
	if opts.SourceTodo != "" && !isValidSlug(opts.SourceTodo) {
		return a.fail("furrow row init", &cliError{exit: 1, code: "usage", message: fmt.Sprintf("source todo %q must be kebab-case", opts.SourceTodo)}, flags.json)
	}

	state, err := initRow(root, rowName, opts)
	if err != nil {
		return a.fail("furrow row init", err, flags.json)
	}

	statusData := buildRowStatusData(root, rowName, state, "explicit", "", nil)
	data := map[string]any{
		"row":   statusData["row"],
		"seed":  statusData["seed"],
		"paths": map[string]any{"row_dir": rowDirFor(root, rowName), "state": statePathForRow(root, rowName)},
	}
	if flags.json {
		return a.okJSON("furrow row init", data)
	}
	_, _ = fmt.Fprintf(a.stdout, "initialized row %s\n", rowName)
	return 0
}

func (a *App) runRowFocus(args []string) int {
	positionals, flags, err := parseArgs(args, nil, map[string]bool{"clear": true})
	if err != nil {
		return a.fail("furrow row focus", err, false)
	}
	if len(positionals) > 1 {
		return a.fail("furrow row focus", &cliError{exit: 1, code: "usage", message: "usage: furrow row focus [row-name|--clear] [--json]"}, flags.json)
	}
	if flags.bools["clear"] && len(positionals) > 0 {
		return a.fail("furrow row focus", &cliError{exit: 1, code: "usage", message: "use either a row name or --clear, not both"}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow row focus", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	focusedPath := filepath.Join(root, ".furrow", ".focused")
	if flags.bools["clear"] {
		existed := fileExists(focusedPath)
		if err := os.Remove(focusedPath); err != nil && !os.IsNotExist(err) {
			return a.fail("furrow row focus", &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to clear %s", focusedPath), details: map[string]any{"path": focusedPath, "error": err.Error()}}, flags.json)
		}
		data := map[string]any{"focused_row": nil, "changed": existed, "path": focusedPath}
		if flags.json {
			return a.okJSON("furrow row focus", data)
		}
		_, _ = fmt.Fprintln(a.stdout, "focus cleared")
		return 0
	}

	if len(positionals) == 0 {
		focused, _, focusedErr := readFocusedRowName(root)
		warnings := []map[string]any{}
		if focusedErr != nil {
			warnings = append(warnings, map[string]any{"code": "focused_row_invalid", "message": focusedErr.Error()})
		}
		data := map[string]any{"focused_row": nilIfEmpty(focused), "changed": false, "path": focusedPath, "warnings": warnings}
		if flags.json {
			return a.okJSON("furrow row focus", data)
		}
		if focused == "" {
			_, _ = fmt.Fprintln(a.stdout, "no focused row")
		} else {
			_, _ = fmt.Fprintln(a.stdout, focused)
		}
		return 0
	}

	rowName := positionals[0]
	statePath := statePathForRow(root, rowName)
	if !fileExists(statePath) {
		return a.fail("furrow row focus", &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("state file not found for row %q", rowName)}, flags.json)
	}
	state, err := loadJSONMap(statePath)
	if err != nil {
		return a.fail("furrow row focus", &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", statePath), details: map[string]any{"path": statePath}}, flags.json)
	}
	if isArchivedState(state) {
		return a.fail("furrow row focus", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q is archived", rowName)}, flags.json)
	}
	if err := os.WriteFile(focusedPath, []byte(rowName+"\n"), 0o644); err != nil {
		return a.fail("furrow row focus", &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to write %s", focusedPath), details: map[string]any{"path": focusedPath, "error": err.Error()}}, flags.json)
	}
	data := map[string]any{"focused_row": rowName, "changed": true, "path": focusedPath}
	if flags.json {
		return a.okJSON("furrow row focus", data)
	}
	_, _ = fmt.Fprintf(a.stdout, "focused %s\n", rowName)
	return 0
}

func (a *App) runRowScaffold(args []string) int {
	positionals, flags, err := parseArgs(args, nil, map[string]bool{"current-step": true})
	if err != nil {
		return a.fail("furrow row scaffold", err, false)
	}
	if len(positionals) != 1 {
		return a.fail("furrow row scaffold", &cliError{exit: 1, code: "usage", message: "usage: furrow row scaffold <row-name> [--current-step] [--json]"}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow row scaffold", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}
	rowName := positionals[0]
	statePath := statePathForRow(root, rowName)
	if !fileExists(statePath) {
		return a.fail("furrow row scaffold", &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("state file not found for row %q", rowName)}, flags.json)
	}
	state, err := loadJSONMap(statePath)
	if err != nil {
		return a.fail("furrow row scaffold", &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", statePath), details: map[string]any{"path": statePath}}, flags.json)
	}
	if isArchivedState(state) {
		return a.fail("furrow row scaffold", &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("row %q is archived", rowName)}, flags.json)
	}

	artifacts := currentStepArtifacts(root, rowName, state)
	created, err := scaffoldMissingCurrentStepArtifacts(root, rowName, state, artifacts)
	if err != nil {
		return a.fail("furrow row scaffold", err, flags.json)
	}
	refreshed := currentStepArtifacts(root, rowName, state)

	data := map[string]any{
		"row": map[string]any{
			"name":        rowName,
			"step":        getStringDefault(state, "step", "unknown"),
			"step_status": getStringDefault(state, "step_status", "unknown"),
		},
		"created":                created,
		"current_step_artifacts": refreshed,
		"note":                   "artifact existence is never completion; scaffolded files are intentionally incomplete templates",
	}
	if flags.json {
		return a.okJSON("furrow row scaffold", data)
	}
	_, _ = fmt.Fprintf(a.stdout, "scaffolded %d artifact(s) for %s\n", len(created), rowName)
	return 0
}

func initRow(root, rowName string, opts rowInitOptions) (map[string]any, error) {
	rowDir := rowDirFor(root, rowName)
	if fileExists(rowDir) {
		return nil, &cliError{exit: 2, code: "already_exists", message: fmt.Sprintf("row %q already exists", rowName)}
	}

	defaultMode, defaultGatePolicy := readProjectDefaults(root)
	mode := opts.Mode
	if mode == "" {
		mode = defaultMode
	}
	if mode == "" {
		mode = "code"
	}
	gatePolicy := opts.GatePolicy
	if gatePolicy == "" {
		gatePolicy = defaultGatePolicy
	}
	if gatePolicy == "" {
		gatePolicy = "supervised"
	}

	title := strings.TrimSpace(opts.Title)
	if title == "" {
		title = rowName
	}
	seedID, seedRecord, err := resolveSeedForInit(root, title, opts.SourceTodo, opts.SeedID, "ideate")
	if err != nil {
		return nil, err
	}

	baseCommit := "unknown"
	if branch, err := gitCurrentCommit(root); err == nil && branch != "" {
		baseCommit = branch
	}
	branchName := gitCurrentBranch(root)
	if !strings.HasPrefix(branchName, "work/") {
		branchName = ""
	}
	now := nowRFC3339()

	if err := os.MkdirAll(filepath.Join(rowDir, "reviews"), 0o755); err != nil {
		return nil, &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to create %s", rowDir), details: map[string]any{"path": rowDir, "error": err.Error()}}
	}

	state := map[string]any{
		"name":                 rowName,
		"title":                title,
		"description":          title,
		"step":                 "ideate",
		"step_status":          "in_progress",
		"steps_sequence":       defaultStepsSequence(),
		"deliverables":         map[string]any{},
		"gates":                []any{},
		"force_stop_at":        nil,
		"branch":               nilIfEmpty(branchName),
		"mode":                 mode,
		"base_commit":          baseCommit,
		"seed_id":              seedID,
		"epic_seed_id":         nil,
		"created_at":           now,
		"updated_at":           now,
		"archived_at":          nil,
		"gate_policy_init":     gatePolicy,
		"truth_gates_version":  1,
		"pending_user_actions": []any{},
	}
	if opts.SourceTodo != "" {
		state["source_todos"] = []any{opts.SourceTodo}
	}
	if err := writeJSONMapAtomic(filepath.Join(rowDir, "state.json"), state); err != nil {
		return nil, &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to write %s", filepath.Join(rowDir, "state.json")), details: map[string]any{"path": filepath.Join(rowDir, "state.json"), "error": err.Error()}}
	}

	_ = seedRecord
	return state, nil
}

func readProjectDefaults(root string) (string, string) {
	path := filepath.Join(root, ".claude", "furrow.yaml")
	if !fileExists(path) {
		return "code", "supervised"
	}
	payload, err := os.ReadFile(path)
	if err != nil {
		return "code", "supervised"
	}
	var doc map[string]any
	if err := yaml.Unmarshal(payload, &doc); err != nil {
		return "code", "supervised"
	}
	defaults, ok := doc["defaults"].(map[string]any)
	if !ok {
		return "code", "supervised"
	}
	mode, _ := defaults["mode"].(string)
	gatePolicy, _ := defaults["gate_policy"].(string)
	if mode == "" {
		mode = "code"
	}
	if gatePolicy == "" {
		gatePolicy = "supervised"
	}
	return mode, gatePolicy
}

func gitCurrentCommit(root string) (string, error) {
	if !fileExists(filepath.Join(root, ".git")) {
		return "", nil
	}
	oldwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(root); err != nil {
		return "", err
	}
	return strings.TrimSpace(commandOutput("git", "rev-parse", "HEAD")), nil
}

func gitCurrentBranch(root string) string {
	if !fileExists(filepath.Join(root, ".git")) {
		return ""
	}
	oldwd, err := os.Getwd()
	if err != nil {
		return ""
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(root); err != nil {
		return ""
	}
	return strings.TrimSpace(commandOutput("git", "branch", "--show-current"))
}

func commandOutput(name string, args ...string) string {
	payload, err := exec.Command(name, args...).Output()
	if err != nil {
		return ""
	}
	return string(payload)
}

func isValidGatePolicy(value string) bool {
	switch value {
	case "supervised", "delegated", "autonomous":
		return true
	default:
		return false
	}
}

func resolveSeedForInit(root, title, sourceTodo, seedID, step string) (string, map[string]any, error) {
	seedsPath := filepath.Join(root, ".furrow", "seeds", "seeds.jsonl")
	configPath := filepath.Join(root, ".furrow", "seeds", "config")
	if !fileExists(seedsPath) || !fileExists(configPath) {
		return "", nil, &cliError{exit: 5, code: "not_found", message: "seed store is not initialized", details: map[string]any{"seeds": seedsPath, "config": configPath}}
	}
	seeds, err := loadLatestSeedRecords(root)
	if err != nil {
		return "", nil, err
	}
	if seedID != "" {
		record, ok := seeds[seedID]
		if !ok {
			return "", nil, &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("seed %q not found", seedID)}
		}
		if seedRecordClosed(record) {
			return "", nil, &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("seed %q is closed", seedID)}
		}
		updated, err := appendSeedStatus(root, record, seedStatusForStep(step))
		if err != nil {
			return "", nil, err
		}
		return seedID, updated, nil
	}

	if sourceTodo != "" {
		todos, err := readTodoList(filepath.Join(root, ".furrow", "almanac", "todos.yaml"))
		if err != nil {
			return "", nil, err
		}
		todo, ok := findTodoByID(todos, sourceTodo)
		if !ok {
			return "", nil, &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("source todo %q not found", sourceTodo)}
		}
		if linkedSeedID, ok := todo["seed_id"].(string); ok && strings.TrimSpace(linkedSeedID) != "" {
			record, ok := seeds[linkedSeedID]
			if !ok {
				return "", nil, &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("linked seed %q for todo %q not found", linkedSeedID, sourceTodo)}
			}
			if seedRecordClosed(record) {
				return "", nil, &cliError{exit: 2, code: "blocked", message: fmt.Sprintf("linked seed %q for todo %q is closed", linkedSeedID, sourceTodo)}
			}
			updated, err := appendSeedStatus(root, record, seedStatusForStep(step))
			if err != nil {
				return "", nil, err
			}
			return linkedSeedID, updated, nil
		}
		newRecord, err := createSeedRecord(root, seeds, title, seedStatusForStep(step))
		if err != nil {
			return "", nil, err
		}
		if err := writeTodoSeedLink(filepath.Join(root, ".furrow", "almanac", "todos.yaml"), sourceTodo, newRecord["id"].(string)); err != nil {
			return "", nil, err
		}
		return newRecord["id"].(string), newRecord, nil
	}

	newRecord, err := createSeedRecord(root, seeds, title, seedStatusForStep(step))
	if err != nil {
		return "", nil, err
	}
	return newRecord["id"].(string), newRecord, nil
}

func loadLatestSeedRecords(root string) (map[string]map[string]any, error) {
	path := filepath.Join(root, ".furrow", "seeds", "seeds.jsonl")
	file, err := os.Open(path)
	if err != nil {
		return nil, &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("seed store not found: %s", path), details: map[string]any{"path": path}}
	}
	defer file.Close()

	seeds := map[string]map[string]any{}
	scanner := bufio.NewScanner(file)
	lineNumber := 0
	for scanner.Scan() {
		lineNumber++
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var record map[string]any
		if err := json.Unmarshal([]byte(line), &record); err != nil {
			return nil, &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", path), details: map[string]any{"path": path, "line": lineNumber, "error": err.Error()}}
		}
		id, _ := record["id"].(string)
		if id == "" {
			return nil, &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("seed record missing id in %s", path), details: map[string]any{"path": path, "line": lineNumber}}
		}
		seeds[id] = record
	}
	if err := scanner.Err(); err != nil {
		return nil, &cliError{exit: 4, code: "read_failed", message: fmt.Sprintf("failed reading %s", path), details: map[string]any{"path": path, "error": err.Error()}}
	}
	return seeds, nil
}

func latestSeedRecord(root, id string) (map[string]any, bool, error) {
	seeds, err := loadLatestSeedRecords(root)
	if err != nil {
		return nil, false, err
	}
	record, ok := seeds[id]
	return record, ok, nil
}

func seedStatusForStep(step string) string {
	switch step {
	case "ideate":
		return "ideating"
	case "research":
		return "researching"
	case "plan":
		return "planning"
	case "spec":
		return "speccing"
	case "decompose":
		return "decomposing"
	case "implement":
		return "implementing"
	case "review":
		return "reviewing"
	default:
		return ""
	}
}

func seedRecordClosed(record map[string]any) bool {
	status, _ := record["status"].(string)
	closedAt, _ := record["closed_at"].(string)
	return status == "closed" || strings.TrimSpace(closedAt) != ""
}

func appendSeedStatus(root string, record map[string]any, status string) (map[string]any, error) {
	if status == "" {
		return record, nil
	}
	updated := cloneMap(record)
	updated["status"] = status
	updated["updated_at"] = nowRFC3339()
	if err := appendSeedRecord(root, updated); err != nil {
		return nil, err
	}
	return updated, nil
}

func createSeedRecord(root string, existing map[string]map[string]any, title, status string) (map[string]any, error) {
	prefixPayload, err := os.ReadFile(filepath.Join(root, ".furrow", "seeds", "config"))
	if err != nil {
		return nil, &cliError{exit: 5, code: "not_found", message: "seed config missing", details: map[string]any{"path": filepath.Join(root, ".furrow", "seeds", "config")}}
	}
	prefix := strings.TrimSpace(string(prefixPayload))
	if prefix == "" {
		prefix = filepath.Base(root)
	}
	id, err := generateSeedID(prefix, existing)
	if err != nil {
		return nil, err
	}
	now := nowRFC3339()
	record := map[string]any{
		"id":           id,
		"title":        title,
		"status":       status,
		"type":         "task",
		"priority":     2,
		"description":  nil,
		"close_reason": nil,
		"depends_on":   []any{},
		"blocks":       []any{},
		"created_at":   now,
		"updated_at":   now,
		"closed_at":    nil,
	}
	if err := appendSeedRecord(root, record); err != nil {
		return nil, err
	}
	return record, nil
}

func generateSeedID(prefix string, existing map[string]map[string]any) (string, error) {
	for i := 0; i < 10; i++ {
		bytes := make([]byte, 2)
		if _, err := rand.Read(bytes); err != nil {
			return "", &cliError{exit: 4, code: "subcommand_failed", message: "failed to generate seed id", details: map[string]any{"error": err.Error()}}
		}
		candidate := prefix + "-" + hex.EncodeToString(bytes)
		if _, exists := existing[candidate]; !exists {
			return candidate, nil
		}
	}
	return "", &cliError{exit: 4, code: "subcommand_failed", message: "failed to generate unique seed id"}
}

func appendSeedRecord(root string, record map[string]any) error {
	path := filepath.Join(root, ".furrow", "seeds", "seeds.jsonl")
	file, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to open %s", path), details: map[string]any{"path": path, "error": err.Error()}}
	}
	defer file.Close()
	payload, err := json.Marshal(record)
	if err != nil {
		return &cliError{exit: 4, code: "write_failed", message: "failed to encode seed record", details: map[string]any{"error": err.Error()}}
	}
	if _, err := file.Write(append(payload, '\n')); err != nil {
		return &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to append %s", path), details: map[string]any{"path": path, "error": err.Error()}}
	}
	return nil
}

func readTodoList(path string) ([]map[string]any, error) {
	doc, findings := loadYAMLDocument(path)
	if len(findings) > 0 {
		finding := findings[0]
		return nil, &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid YAML in %s", path), details: map[string]any{"path": path, "error": finding.Message}}
	}
	entries, ok := doc.([]any)
	if !ok {
		return nil, &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid YAML in %s", path), details: map[string]any{"path": path, "error": "todos document must be a YAML sequence"}}
	}
	out := make([]map[string]any, 0, len(entries))
	for index, raw := range entries {
		entry, ok := raw.(map[string]any)
		if !ok {
			return nil, &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid YAML in %s", path), details: map[string]any{"path": path, "error": fmt.Sprintf("todo entry %d is not a mapping", index)}}
		}
		out = append(out, entry)
	}
	return out, nil
}

func findTodoByID(todos []map[string]any, id string) (map[string]any, bool) {
	for _, todo := range todos {
		if todoID, _ := todo["id"].(string); todoID == id {
			return todo, true
		}
	}
	return nil, false
}

func writeTodoSeedLink(path, todoID, seedID string) error {
	todos, err := readTodoList(path)
	if err != nil {
		return err
	}
	found := false
	now := nowRFC3339()
	for _, todo := range todos {
		if id, _ := todo["id"].(string); id == todoID {
			todo["seed_id"] = seedID
			todo["updated_at"] = now
			found = true
			break
		}
	}
	if !found {
		return &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("source todo %q not found", todoID)}
	}
	payload, err := yaml.Marshal(todos)
	if err != nil {
		return &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to marshal %s", path), details: map[string]any{"path": path, "error": err.Error()}}
	}
	if err := os.WriteFile(path, payload, 0o644); err != nil {
		return &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to write %s", path), details: map[string]any{"path": path, "error": err.Error()}}
	}
	return nil
}

func cloneMap(input map[string]any) map[string]any {
	out := make(map[string]any, len(input))
	for key, value := range input {
		out[key] = value
	}
	return out
}

func rowDeliverableNames(root, rowName string, state map[string]any) []string {
	names := make([]string, 0)
	seen := map[string]struct{}{}

	definitionPath := filepath.Join(rowDirFor(root, rowName), "definition.yaml")
	if fileExists(definitionPath) {
		payload, err := os.ReadFile(definitionPath)
		if err == nil {
			var doc map[string]any
			if err := yaml.Unmarshal(payload, &doc); err == nil {
				if rawDeliverables, ok := doc["deliverables"].([]any); ok {
					for _, raw := range rawDeliverables {
						deliverable, ok := raw.(map[string]any)
						if !ok {
							continue
						}
						name, _ := deliverable["name"].(string)
						name = strings.TrimSpace(name)
						if !isSubstantiveText(name) {
							continue
						}
						if _, exists := seen[name]; exists {
							continue
						}
						seen[name] = struct{}{}
						names = append(names, name)
					}
				}
			}
		}
	}

	if deliverables, ok := asMap(state["deliverables"]); ok {
		stateNames := make([]string, 0, len(deliverables))
		for name := range deliverables {
			name = strings.TrimSpace(name)
			if name == "" {
				continue
			}
			if _, exists := seen[name]; exists {
				continue
			}
			seen[name] = struct{}{}
			stateNames = append(stateNames, name)
		}
		sort.Strings(stateNames)
		names = append(names, stateNames...)
	}

	return names
}

func reviewArtifactFileName(name string) string {
	trimmed := strings.TrimSpace(strings.ToLower(name))
	if trimmed == "" {
		return "all-deliverables.json"
	}
	trimmed = strings.ReplaceAll(trimmed, "/", "-")
	trimmed = strings.ReplaceAll(trimmed, " ", "-")
	builder := strings.Builder{}
	lastDash := false
	for _, r := range trimmed {
		switch {
		case (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9'):
			builder.WriteRune(r)
			lastDash = false
		case r == '-' || r == '_':
			if !lastDash {
				builder.WriteByte('-')
				lastDash = true
			}
		default:
			if !lastDash {
				builder.WriteByte('-')
				lastDash = true
			}
		}
	}
	file := strings.Trim(builder.String(), "-")
	if file == "" {
		file = "all-deliverables"
	}
	return file + ".json"
}

func reviewArtifactsForRow(root, rowName string, state map[string]any) []map[string]any {
	rowDir := rowDirFor(root, rowName)
	deliverableNames := rowDeliverableNames(root, rowName, state)
	artifacts := []rowArtifactSpec{}
	if len(deliverableNames) == 0 {
		artifacts = append(artifacts, artifactSpec(rowDir, "review:all-deliverables", "reviews/all-deliverables.json", true, false))
	} else {
		for _, deliverableName := range deliverableNames {
			fileName := reviewArtifactFileName(deliverableName)
			artifacts = append(artifacts, artifactSpec(rowDir, "review:"+deliverableName, filepath.Join("reviews", fileName), true, false))
		}
	}

	return materializeRowArtifacts(state, artifacts)
}

func currentStepArtifacts(root, rowName string, state map[string]any) []map[string]any {
	rowDir := rowDirFor(root, rowName)
	step := getStringDefault(state, "step", "")
	artifacts := []rowArtifactSpec{}

	switch step {
	case "ideate":
		artifacts = append(artifacts, artifactSpec(rowDir, "definition", "definition.yaml", true, true))
		if rowTruthGatesRequired(state) {
			artifacts = append(artifacts, artifactSpec(rowDir, "ask-analysis", "ask-analysis.md", true, true))
		}
	case "research":
		artifacts = append(artifacts, artifactSpec(rowDir, "research", "research.md", true, true))
	case "plan":
		artifacts = append(artifacts, artifactSpec(rowDir, "implementation-plan", "implementation-plan.md", true, true))
	case "spec":
		artifacts = append(artifacts, artifactSpec(rowDir, "spec", "spec.md", true, true))
	case "decompose":
		artifacts = append(artifacts,
			artifactSpec(rowDir, "plan", "plan.json", true, true),
		)
	case "implement":
		deliverableNames := rowDeliverableNames(root, rowName, state)
		requireCoordinationArtifacts := len(deliverableNames) > 1 || fileExists(filepath.Join(rowDir, "plan.json"))
		if requireCoordinationArtifacts {
			artifacts = append(artifacts,
				artifactSpec(rowDir, "plan", "plan.json", true, false),
			)
		}
	case "review":
		reviewArtifacts := reviewArtifactsForRow(root, rowName, state)
		if rowTruthGatesRequired(state) {
			reviewArtifacts = append(reviewArtifacts, truthGateArtifactsForRow(root, rowName, state)...)
		}
		return reviewArtifacts
	}

	return materializeRowArtifacts(state, artifacts)
}

func continuationArtifacts(root, rowName string, state map[string]any) []map[string]any {
	rowDir := rowDirFor(root, rowName)
	step := getStringDefault(state, "step", "")
	specs := []rowArtifactSpec{}
	add := func(id, label string, required bool) {
		specs = append(specs, artifactSpecWithRole(rowDir, id, label, "continuation_input", required, false))
	}

	switch step {
	case "research":
		add("definition", "definition.yaml", true)
		if rowTruthGatesRequired(state) {
			add("ask-analysis", "ask-analysis.md", true)
		}
	case "plan":
		add("definition", "definition.yaml", true)
		if rowTruthGatesRequired(state) {
			add("ask-analysis", "ask-analysis.md", true)
		}
		add("research", "research.md", true)
	case "spec":
		add("definition", "definition.yaml", true)
		if rowTruthGatesRequired(state) {
			add("ask-analysis", "ask-analysis.md", true)
		}
		add("research", "research.md", true)
		add("implementation-plan", "implementation-plan.md", true)
	case "decompose":
		add("definition", "definition.yaml", true)
		if rowTruthGatesRequired(state) {
			add("ask-analysis", "ask-analysis.md", true)
		}
		add("research", "research.md", true)
		add("implementation-plan", "implementation-plan.md", true)
		add("spec", "spec.md", true)
	case "implement":
		add("definition", "definition.yaml", true)
		if rowTruthGatesRequired(state) {
			add("ask-analysis", "ask-analysis.md", true)
		}
		add("spec", "spec.md", true)
		add("plan", "plan.json", true)
	case "review":
		add("definition", "definition.yaml", true)
		if rowTruthGatesRequired(state) {
			add("ask-analysis", "ask-analysis.md", true)
		}
		add("spec", "spec.md", true)
		add("plan", "plan.json", true)
	}
	return materializeRowArtifacts(state, specs)
}

func checkpointArtifacts(root, rowName string, state map[string]any) []map[string]any {
	current := currentStepArtifacts(root, rowName, state)
	continuation := continuationArtifacts(root, rowName, state)
	seen := make(map[string]bool, len(current)+len(continuation))
	result := make([]map[string]any, 0, len(current)+len(continuation))
	for _, artifact := range current {
		key := getStringDefault(artifact, "path", "") + "\x00" + getStringDefault(artifact, "id", "")
		seen[key] = true
		result = append(result, artifact)
	}
	for _, artifact := range continuation {
		key := getStringDefault(artifact, "path", "") + "\x00" + getStringDefault(artifact, "id", "")
		if seen[key] {
			continue
		}
		result = append(result, artifact)
	}
	return result
}

func artifactContractSurface(currentArtifacts, continuationInputs []map[string]any) map[string]any {
	return map[string]any{
		"required_current_step_outputs": artifactContractItems(currentArtifacts, true),
		"optional_current_step_outputs": artifactContractItems(currentArtifacts, false),
		"required_continuation_inputs":  artifactContractItems(continuationInputs, true),
		"optional_continuation_inputs":  artifactContractItems(continuationInputs, false),
		"retired":                       []map[string]any{},
		"completion_checks":             artifactCompletionChecks(),
		"archive_checks":                artifactArchiveChecks(),
	}
}

func artifactCompletionChecks() []map[string]any {
	return []map[string]any{
		{"code": "artifact_exists", "label": "required artifact exists"},
		{"code": "scaffold_resolved", "label": "artifact is not an incomplete scaffold"},
		{"code": "validation_passes", "label": "backend validation has no blocking findings"},
	}
}

func artifactArchiveChecks() []map[string]any {
	checks := artifactCompletionChecks()
	checks = append(checks,
		map[string]any{"code": "review_step_completed", "label": "review step is completed"},
		map[string]any{"code": "review_artifacts_valid", "label": "required review and truth-gate artifacts pass validation"},
		map[string]any{"code": "continuation_inputs_valid", "label": "required continuation inputs still pass validation"},
		map[string]any{"code": "review_gate_passed", "label": "passing ->review gate exists"},
	)
	return checks
}

func artifactContractItems(artifacts []map[string]any, required bool) []map[string]any {
	items := make([]map[string]any, 0)
	for _, artifact := range artifacts {
		if isRequired, _ := artifact["required"].(bool); isRequired != required {
			continue
		}
		items = append(items, map[string]any{
			"id":     artifact["id"],
			"label":  artifact["label"],
			"path":   artifact["path"],
			"role":   artifact["role"],
			"checks": artifact["checks"],
		})
	}
	return items
}

func blockersForArtifactRole(blockers []map[string]any, role string) []map[string]any {
	matches := make([]map[string]any, 0)
	for _, blocker := range blockers {
		details, _ := blocker["details"].(map[string]any)
		if details == nil {
			continue
		}
		if detailsRole, _ := details["artifact_role"].(string); detailsRole == role {
			matches = append(matches, blocker)
		}
	}
	return matches
}

func scaffoldMissingCurrentStepArtifacts(root, rowName string, state map[string]any, artifacts []map[string]any) ([]map[string]any, error) {
	created := make([]map[string]any, 0)
	for _, artifact := range artifacts {
		path, _ := artifact["path"].(string)
		if path == "" || fileExists(path) {
			continue
		}
		content, ok := scaffoldTemplateForArtifact(state, artifact)
		if !ok {
			continue
		}
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			return nil, &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to create %s", filepath.Dir(path)), details: map[string]any{"path": filepath.Dir(path), "error": err.Error()}}
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			return nil, &cliError{exit: 4, code: "write_failed", message: fmt.Sprintf("failed to write %s", path), details: map[string]any{"path": path, "error": err.Error()}}
		}
		created = append(created, map[string]any{"id": artifact["id"], "label": artifact["label"], "path": path})
	}
	return created, nil
}

func rowSeedSurface(root string, state map[string]any) map[string]any {
	step := getStringDefault(state, "step", "")
	expected := seedStatusForStep(step)
	seedID := strings.TrimSpace(getStringDefault(state, "seed_id", ""))
	if seedID == "" {
		return map[string]any{
			"id":              nil,
			"state":           "missing",
			"status":          nil,
			"title":           nil,
			"expected_status": nilIfEmpty(expected),
			"consistent":      false,
		}
	}
	seeds, err := loadLatestSeedRecords(root)
	if err != nil {
		return map[string]any{
			"id":              seedID,
			"state":           "unavailable",
			"status":          nil,
			"title":           nil,
			"expected_status": nilIfEmpty(expected),
			"consistent":      false,
			"error":           err.Error(),
		}
	}
	record, ok := seeds[seedID]
	if !ok {
		return map[string]any{
			"id":              seedID,
			"state":           "missing_record",
			"status":          nil,
			"title":           nil,
			"expected_status": nilIfEmpty(expected),
			"consistent":      false,
		}
	}
	status, _ := record["status"].(string)
	title, _ := record["title"].(string)
	closed := seedRecordClosed(record)
	consistent := expected == "" || status == expected
	stateLabel := "linked"
	switch {
	case closed:
		stateLabel = "closed"
	case !consistent:
		stateLabel = "inconsistent"
	}
	return map[string]any{
		"id":              seedID,
		"state":           stateLabel,
		"status":          nilIfEmpty(status),
		"title":           nilIfEmpty(title),
		"expected_status": nilIfEmpty(expected),
		"consistent":      consistent && !closed,
	}
}

// rowBlockersOpts carries optional context beyond state/seed/artifacts.
// The zero value (rowBlockersOpts{}) is safe for all existing callers.
type rowBlockersOpts struct {
	Root    string
	RowName string
	// SupersedesConfirmed is the raw "--supersedes-confirmed <commit>:<row>" value.
	// Empty string means the flag was not passed.
	SupersedesConfirmed string
	// DefinitionSupersedes holds the parsed supersedes block from definition.yaml,
	// or nil if the definition has no supersedes block.
	DefinitionSupersedes map[string]any
}

func rowBlockers(state map[string]any, seed map[string]any, artifacts []map[string]any, opts rowBlockersOpts) []map[string]any {
	if isArchivedState(state) {
		return []map[string]any{}
	}

	// Single-point migration: every emit-site routes through the canonical
	// taxonomy via `blocker(tx, ...)`. LoadTaxonomy is cached package-level;
	// a missing/invalid registry is a programmer error and the test-mode
	// panic surfaces it loudly. Production fallback (synthetic envelope)
	// keeps the runtime alive if the YAML ever ships broken.
	tx, _ := LoadTaxonomy()

	blockers := make([]map[string]any, 0)
	if pending, ok := asSlice(state["pending_user_actions"]); ok && len(pending) > 0 {
		count := len(pending)
		blockers = append(blockers, blocker(tx, "pending_user_actions",
			map[string]string{"count": fmt.Sprintf("%d", count)},
			map[string]any{"count": count}))
	}
	seedState, _ := seed["state"].(string)
	switch seedState {
	case "unavailable":
		blockers = append(blockers, blocker(tx, "seed_store_unavailable", nil, nil))
	case "missing_record":
		seedID := fmt.Sprintf("%v", seed["id"])
		blockers = append(blockers, blocker(tx, "missing_seed_record",
			map[string]string{"seed_id": seedID},
			map[string]any{"seed_id": seed["id"]}))
	case "closed":
		seedID := fmt.Sprintf("%v", seed["id"])
		blockers = append(blockers, blocker(tx, "closed_seed",
			map[string]string{"seed_id": seedID},
			map[string]any{"seed_id": seed["id"]}))
	case "inconsistent":
		seedID := fmt.Sprintf("%v", seed["id"])
		actual := fmt.Sprintf("%v", seed["status"])
		expected := fmt.Sprintf("%v", seed["expected_status"])
		blockers = append(blockers, blocker(tx, "seed_status_mismatch",
			map[string]string{"seed_id": seedID, "actual_status": actual, "expected_status": expected},
			map[string]any{"seed_id": seed["id"], "expected_status": seed["expected_status"], "actual_status": seed["status"]}))
	}
	// Supersedence confirmation check
	if opts.DefinitionSupersedes != nil {
		requiredCommit, _ := opts.DefinitionSupersedes["commit"].(string)
		requiredRow, _ := opts.DefinitionSupersedes["row"].(string)
		confirmed := opts.SupersedesConfirmed // may be ""
		var confirmedCommit, confirmedRow string
		if confirmed != "" {
			parts := strings.SplitN(confirmed, ":", 2)
			if len(parts) == 2 {
				confirmedCommit, confirmedRow = parts[0], parts[1]
			}
		}
		switch {
		case confirmed == "":
			blockers = append(blockers, blocker(tx, "supersedence_evidence_missing",
				map[string]string{
					"required_commit":  requiredCommit,
					"required_row":     requiredRow,
					"confirmed_commit": "",
					"confirmed_row":    "",
				},
				map[string]any{"required_commit": requiredCommit, "required_row": requiredRow},
			))
		case confirmedCommit != requiredCommit || confirmedRow != requiredRow:
			blockers = append(blockers, blocker(tx, "supersedence_evidence_missing",
				map[string]string{
					"required_commit":  requiredCommit,
					"required_row":     requiredRow,
					"confirmed_commit": confirmedCommit,
					"confirmed_row":    confirmedRow,
				},
				map[string]any{
					"required_commit":  requiredCommit,
					"required_row":     requiredRow,
					"confirmed_commit": confirmedCommit,
					"confirmed_row":    confirmedRow,
				},
			))
		}
	}
	for _, artifact := range artifacts {
		required, _ := artifact["required"].(bool)
		artifactID := fmt.Sprintf("%v", artifact["id"])
		artifactPath := fmt.Sprintf("%v", artifact["path"])
		artifactRole := getStringDefault(artifact, "role", "")
		if exists, _ := artifact["exists"].(bool); !exists {
			if !required {
				continue
			}
			blockers = append(blockers, blocker(tx, "missing_required_artifact",
				map[string]string{"artifact_id": artifactID, "path": artifactPath},
				map[string]any{"path": artifact["path"], "artifact_id": artifact["id"], "artifact_role": artifactRole}))
			continue
		}
		if incomplete, _ := artifact["incomplete"].(bool); incomplete {
			blockers = append(blockers, blocker(tx, "artifact_scaffold_incomplete",
				map[string]string{"artifact_id": artifactID, "path": artifactPath},
				map[string]any{"path": artifact["path"], "artifact_id": artifact["id"], "artifact_role": artifactRole}))
			continue
		}
		if blockingArtifactValidation(artifact) {
			blockers = append(blockers, blocker(tx, "artifact_validation_failed",
				map[string]string{"artifact_id": artifactID, "path": artifactPath},
				map[string]any{"path": artifact["path"], "artifact_id": artifact["id"], "artifact_role": artifactRole, "finding_codes": validationFindingCodes(artifact)}))
		}
	}
	if getStringDefault(state, "step", "") == "review" && getStringDefault(state, "step_status", "") == "completed" {
		for _, blockerEntry := range truthGateBlockers(opts.Root, opts.RowName, state, artifacts) {
			blockers = append(blockers, blocker(tx, "truth_gate_blocked",
				map[string]string{"reason": getStringDefault(blockerEntry, "reason", "truth gate blocked")},
				blockerEntry))
		}
		if _, ok := latestPassingReviewGate(state); !ok {
			blockers = append(blockers, blocker(tx, "archive_requires_review_gate", nil, nil))
		}
	}
	return blockers
}

func rowCheckpointSurface(root, rowName string, state map[string]any, blockers []map[string]any, seed map[string]any, artifacts []map[string]any) map[string]any {
	if isArchivedState(state) {
		return map[string]any{
			"gate_policy":       rowGatePolicy(root, rowName, state),
			"boundary":          nil,
			"next_step":         nil,
			"action":            nil,
			"approval_required": false,
			"ready_to_advance":  false,
			"evidence": map[string]any{
				"latest_gate":         latestGateSummary(state),
				"artifact_validation": summarizeArtifactValidation(artifacts),
				"blocker_count":       0,
				"seed":                seed,
				"archived":            true,
			},
		}
	}

	steps, _ := stepsSequenceFromState(state)
	if len(steps) == 0 {
		steps = defaultStepsSequence()
	}
	current := getStringDefault(state, "step", "")
	idx := indexOfStep(steps, current)
	boundary := ""
	nextStep := ""
	action := ""
	if idx >= 0 && idx+1 < len(steps) {
		nextStep = steps[idx+1]
		boundary = current + "->" + nextStep
		action = "transition"
	} else if idx == len(steps)-1 {
		boundary = current + "->archive"
		action = "archive"
	}
	gatePolicy := rowGatePolicy(root, rowName, state)
	approvalRequired := gatePolicy == "supervised" && boundary != ""
	ready := getStringDefault(state, "step_status", "") == "completed" && boundary != "" && len(blockers) == 0
	evidence := map[string]any{
		"latest_gate":          latestGateSummary(state),
		"latest_gate_evidence": latestGateEvidenceSurface(state),
		"artifact_validation":  summarizeArtifactValidation(artifacts),
		"blocker_count":        len(blockers),
		"seed":                 seed,
	}
	if action == "archive" {
		evidence["archive_ceremony"] = archiveCeremonySurface(root, rowName, state, artifacts)
	}
	return map[string]any{
		"gate_policy":       gatePolicy,
		"boundary":          nilIfEmpty(boundary),
		"next_step":         nilIfEmpty(nextStep),
		"action":            nilIfEmpty(action),
		"approval_required": approvalRequired,
		"ready_to_advance":  ready,
		"evidence":          evidence,
	}
}

// definitionSupersedes reads the definition.yaml for the named row and returns
// the parsed "supersedes" map (or nil if the definition has no supersedes block or cannot be read).
func definitionSupersedes(root, rowName string) map[string]any {
	definitionPath := filepath.Join(rowDirFor(root, rowName), "definition.yaml")
	if !fileExists(definitionPath) {
		return nil
	}
	payload, err := os.ReadFile(definitionPath)
	if err != nil {
		return nil
	}
	var doc map[string]any
	if err := yaml.Unmarshal(payload, &doc); err != nil {
		return nil
	}
	supersedes, _ := doc["supersedes"].(map[string]any)
	return supersedes
}

func rowGatePolicy(root, rowName string, state map[string]any) string {
	definitionPath := filepath.Join(rowDirFor(root, rowName), "definition.yaml")
	if fileExists(definitionPath) {
		payload, err := os.ReadFile(definitionPath)
		if err == nil {
			var doc map[string]any
			if err := yaml.Unmarshal(payload, &doc); err == nil {
				if gatePolicy, _ := doc["gate_policy"].(string); isValidGatePolicy(gatePolicy) {
					return gatePolicy
				}
			}
		}
	}
	if gatePolicy, ok := getString(state, "gate_policy_init"); ok && isValidGatePolicy(gatePolicy) {
		return gatePolicy
	}
	return "supervised"
}
