package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	yaml "gopkg.in/yaml.v3"
)

// repairManifest is the in-memory representation of the repair-deliverables manifest.
type repairManifest struct {
	Version      string              `yaml:"version"       json:"version"`
	DecidedBy    string              `yaml:"decided_by"    json:"decided_by"`
	Commit       string              `yaml:"commit"        json:"commit"`
	Deliverables []repairDeliverable `yaml:"deliverables"  json:"deliverables"`
}

type repairDeliverable struct {
	Name          string          `yaml:"name"           json:"name"`
	Status        string          `yaml:"status"         json:"status"`
	Commit        string          `yaml:"commit"         json:"commit"`
	EvidencePaths []evidencePaths `yaml:"evidence_paths" json:"evidence_paths"`
}

type evidencePaths struct {
	Path  string `yaml:"path"  json:"path"`
	Lines string `yaml:"lines" json:"lines,omitempty"`
	Note  string `yaml:"note"  json:"note,omitempty"`
}

// runRowRepairDeliverables implements: furrow row repair-deliverables <row-name> --manifest <path> [--force-active] [--replace] [--json]
func (a *App) runRowRepairDeliverables(args []string) int {
	positionals, flags, err := parseArgs(args,
		map[string]bool{"manifest": true},
		map[string]bool{"force-active": true, "replace": true},
	)
	if err != nil {
		return a.fail("furrow row repair-deliverables", err, false)
	}

	jsonOut := flags.json
	if len(positionals) != 1 {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    1,
			code:    "usage",
			message: "usage: furrow row repair-deliverables <row-name> --manifest <path> [--force-active] [--replace] [--json]",
		}, jsonOut)
	}
	rowName := positionals[0]

	manifestPath := flags.values["manifest"]
	if manifestPath == "" {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    1,
			code:    "usage",
			message: "missing required flag --manifest",
		}, jsonOut)
	}

	forceActive := flags.bools["force-active"]
	replace := flags.bools["replace"]

	// 1. Find furrow root and state path.
	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    1,
			code:    "not_found",
			message: ".furrow root not found",
		}, jsonOut)
	}

	statePath := statePathForRow(root, rowName)

	// 2. Check row exists (exit 2 if not).
	if !fileExists(statePath) {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    2,
			code:    "row_not_found",
			message: fmt.Sprintf("state file not found for row %q", rowName),
		}, jsonOut)
	}

	// 3. Check manifest exists (exit 3 if not).
	if !fileExists(manifestPath) {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    3,
			code:    "manifest_not_found",
			message: fmt.Sprintf("manifest not found: %s", manifestPath),
		}, jsonOut)
	}

	// 4. Load state.json.
	state, err := loadJSONMap(statePath)
	if err != nil {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    6,
			code:    "write_error",
			message: fmt.Sprintf("failed to load %s: %s", statePath, err.Error()),
		}, jsonOut)
	}

	// 5. Check archived_at unless --force-active.
	if !forceActive && !isArchivedState(state) {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    1,
			code:    "not_archived",
			message: fmt.Sprintf("row %s is not archived; pass --force-active to repair active rows", rowName),
		}, jsonOut)
	}

	// 6. Load and parse manifest (YAML or JSON).
	manifestBytes, err := os.ReadFile(manifestPath)
	if err != nil {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    3,
			code:    "manifest_not_found",
			message: fmt.Sprintf("manifest not found: %s", manifestPath),
		}, jsonOut)
	}

	var manifest repairManifest
	// Try YAML first (also handles JSON since YAML is a superset of JSON).
	if err := yaml.Unmarshal(manifestBytes, &manifest); err != nil {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    4,
			code:    "schema_validation_failed",
			message: fmt.Sprintf("manifest parse error: %s", err.Error()),
		}, jsonOut)
	}

	// 7. Schema-validate manifest inline.
	if err := validateRepairManifest(&manifest); err != nil {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    4,
			code:    "schema_validation_failed",
			message: err.Error(),
		}, jsonOut)
	}

	// Set defaults.
	if manifest.DecidedBy == "" {
		manifest.DecidedBy = "manual"
	}

	// 8. Load existing deliverables from state.
	existingDeliverables, ok := state["deliverables"].(map[string]any)
	if !ok || existingDeliverables == nil {
		existingDeliverables = map[string]any{}
	}

	// 9. Classify entries into would-be-added vs would-be-skipped without --replace.
	//    If every entry conflicts and --replace is not set, refuse (exit 5) naming the first conflict.
	//    If at least one entry is new, process new entries and silently skip existing ones (AC 9).
	if !replace {
		allConflict := true
		firstConflict := ""
		for _, entry := range manifest.Deliverables {
			if _, exists := existingDeliverables[entry.Name]; exists {
				if firstConflict == "" {
					firstConflict = entry.Name
				}
			} else {
				allConflict = false
			}
		}
		if allConflict && firstConflict != "" {
			return a.fail("furrow row repair-deliverables", &cliError{
				exit:    5,
				code:    "conflict",
				message: fmt.Sprintf("deliverable '%s' already exists in row '%s'; pass --replace to overwrite", firstConflict, rowName),
			}, jsonOut)
		}
	}

	// 10. Apply entries, tracking added and skipped.
	entriesAdded := []string{}
	entriesSkipped := []string{}

	for _, entry := range manifest.Deliverables {
		if _, exists := existingDeliverables[entry.Name]; exists && !replace {
			entriesSkipped = append(entriesSkipped, entry.Name)
			continue
		}

		// Resolve effective commit: per-entry commit is required (schema enforces it), but
		// top-level commit serves as documentation of the batch; per spec per-entry overrides.
		effectiveCommit := entry.Commit
		if effectiveCommit == "" {
			effectiveCommit = manifest.Commit
		}

		// Build evidence_paths as []any for state.json.
		evidenceList := make([]any, 0, len(entry.EvidencePaths))
		for _, ep := range entry.EvidencePaths {
			epMap := map[string]any{"path": ep.Path}
			if ep.Lines != "" {
				epMap["lines"] = ep.Lines
			}
			if ep.Note != "" {
				epMap["note"] = ep.Note
			}
			evidenceList = append(evidenceList, epMap)
		}

		existingDeliverables[entry.Name] = map[string]any{
			"name":           entry.Name,
			"status":         entry.Status,
			"commit":         effectiveCommit,
			"evidence_paths": evidenceList,
			"decided_by":     manifest.DecidedBy,
		}
		entriesAdded = append(entriesAdded, entry.Name)
	}

	state["deliverables"] = existingDeliverables

	// 11. Append audit entry to sidecar JSONL.
	absManifestPath := manifestPath
	if !filepath.IsAbs(manifestPath) {
		cwd, err := os.Getwd()
		if err == nil {
			absManifestPath = filepath.Join(cwd, manifestPath)
		}
	}

	auditEntry := map[string]any{
		"timestamp":       nowRFC3339(),
		"manifest":        absManifestPath,
		"commit":          manifest.Commit,
		"decided_by":      manifest.DecidedBy,
		"entries_added":   entriesAdded,
		"entries_skipped": entriesSkipped,
	}
	if err := appendAuditEntry(root, rowName, auditEntry); err != nil {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    6,
			code:    "write_error",
			message: fmt.Sprintf("failed to write audit entry: %s", err.Error()),
		}, jsonOut)
	}

	// 12. Atomic write of state.json.
	if err := writeJSONMapAtomic(statePath, state); err != nil {
		return a.fail("furrow row repair-deliverables", &cliError{
			exit:    6,
			code:    "write_error",
			message: fmt.Sprintf("failed to write %s: %s", statePath, err.Error()),
		}, jsonOut)
	}

	data := map[string]any{
		"row":             rowName,
		"entries_added":   entriesAdded,
		"entries_skipped": entriesSkipped,
	}
	if jsonOut {
		return a.okJSON("furrow row repair-deliverables", data)
	}
	_, _ = fmt.Fprintf(a.stdout, "repaired %s: added=%s skipped=%s\n",
		rowName,
		strings.Join(entriesAdded, ","),
		strings.Join(entriesSkipped, ","),
	)
	return 0
}

// validateRepairManifest validates the manifest against the schema rules defined in
// schemas/repair-deliverables-manifest.schema.json, implemented inline (no external deps).
func validateRepairManifest(m *repairManifest) error {
	// deliverables required, minItems 1
	if len(m.Deliverables) == 0 {
		return fmt.Errorf("repair-deliverables: manifest deliverables is required and must have at least 1 item")
	}

	validStatuses := map[string]bool{
		"not_started": true,
		"in_progress": true,
		"completed":   true,
		"blocked":     true,
	}

	for i, entry := range m.Deliverables {
		prefix := fmt.Sprintf("repair-deliverables: deliverables[%d]", i)

		if strings.TrimSpace(entry.Name) == "" {
			return fmt.Errorf("%s.name is required and must be non-empty", prefix)
		}
		if !validStatuses[entry.Status] {
			return fmt.Errorf("%s.status must be one of not_started, in_progress, completed, blocked; got %q", prefix, entry.Status)
		}
		if strings.TrimSpace(entry.Commit) == "" {
			return fmt.Errorf("%s.commit is required and must be non-empty", prefix)
		}
		// evidence_paths: required array, minItems 1
		if len(entry.EvidencePaths) == 0 {
			return fmt.Errorf("%s.evidence_paths is required and must have at least 1 item", prefix)
		}
		for j, ep := range entry.EvidencePaths {
			if strings.TrimSpace(ep.Path) == "" {
				return fmt.Errorf("%s.evidence_paths[%d].path is required and must be non-empty", prefix, j)
			}
		}
	}
	return nil
}

// appendAuditEntry appends a JSON object as a new line to the sidecar repair-audit.jsonl file.
func appendAuditEntry(root, rowName string, entry map[string]any) error {
	auditPath := filepath.Join(root, ".furrow", "rows", rowName, "repair-audit.jsonl")
	line, err := json.Marshal(entry)
	if err != nil {
		return fmt.Errorf("repair-deliverables: marshal audit entry: %w", err)
	}
	f, err := os.OpenFile(auditPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return fmt.Errorf("repair-deliverables: open audit file: %w", err)
	}
	defer func() { _ = f.Close() }()
	_, err = fmt.Fprintf(f, "%s\n", line)
	if err != nil {
		return fmt.Errorf("repair-deliverables: write audit entry: %w", err)
	}
	return nil
}
