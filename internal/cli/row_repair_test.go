package cli

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// validRepairManifestYAML returns a valid YAML manifest with the given deliverable names.
func validRepairManifestYAML(names ...string) string {
	var sb strings.Builder
	sb.WriteString("version: \"1\"\ndecided_by: manual\ncommit: abc1234\ndeliverables:\n")
	for _, name := range names {
		fmt.Fprintf(&sb, "  - name: %s\n    status: completed\n    commit: abc1234\n    evidence_paths:\n      - path: some/file.md\n        note: test evidence\n", name)
	}
	return sb.String()
}

// runRepairCommand runs the repair-deliverables command without JSON output and returns (exitCode, stderr).
func runRepairCommand(t *testing.T, root string, args []string) (int, string) {
	t.Helper()
	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(root); err != nil {
		t.Fatal(err)
	}

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	app := New(&stdout, &stderr)
	code := app.Run(append([]string{"row", "repair-deliverables"}, args...))
	return code, stderr.String()
}

func TestRowRepairDeliverables_HappyPath(t *testing.T) {
	root := setupFurrowRoot(t)
	writeRowState(t, root, "test-row", map[string]any{
		"name":        "test-row",
		"archived_at": "2026-04-01T00:00:00Z",
		"updated_at":  "2026-04-01T00:00:00Z",
	})

	manifestPath := filepath.Join(t.TempDir(), "repair.yaml")
	mustWrite(t, manifestPath, validRepairManifestYAML("backend-work-loop-support", "pi-work-command"))

	code, payload, stderr := runJSONCommand(t, root, []string{
		"row", "repair-deliverables", "test-row",
		"--manifest", manifestPath,
		"--json",
	})
	if code != 0 {
		t.Fatalf("expected exit 0, got %d; stderr=%s payload=%v", code, stderr, payload)
	}
	if payload["ok"] != true {
		t.Fatalf("expected ok=true, got %#v", payload["ok"])
	}

	// Verify deliverables written to state.json
	statePath := statePathForRow(root, "test-row")
	state := readJSONFile(t, statePath)
	deliverables, ok := state["deliverables"].(map[string]any)
	if !ok {
		t.Fatalf("deliverables not a map: %T", state["deliverables"])
	}
	for _, name := range []string{"backend-work-loop-support", "pi-work-command"} {
		if _, exists := deliverables[name]; !exists {
			t.Errorf("deliverable %q missing from state.json", name)
		}
	}

	// Verify audit sidecar
	auditPath := filepath.Join(root, ".furrow", "rows", "test-row", "repair-audit.jsonl")
	auditData, err := os.ReadFile(auditPath)
	if err != nil {
		t.Fatalf("repair-audit.jsonl not created: %v", err)
	}
	var auditEntry map[string]any
	if err := json.Unmarshal(bytes.TrimSpace(auditData), &auditEntry); err != nil {
		t.Fatalf("invalid audit JSONL: %v; raw=%s", err, auditData)
	}
	added, _, err := auditStringSlices(auditEntry)
	if err != nil {
		t.Fatal(err)
	}
	if len(added) != 2 {
		t.Errorf("expected 2 entries_added, got %v", added)
	}
	skipped := auditSkipped(auditEntry)
	if len(skipped) != 0 {
		t.Errorf("expected 0 entries_skipped, got %v", skipped)
	}
}

func TestRowRepairDeliverables_MissingManifest(t *testing.T) {
	root := setupFurrowRoot(t)
	writeRowState(t, root, "test-row", map[string]any{
		"name":        "test-row",
		"archived_at": "2026-04-01T00:00:00Z",
	})

	code, stderr := runRepairCommand(t, root, []string{
		"test-row", "--manifest", "/nonexistent/path.yaml",
	})
	if code != 3 {
		t.Fatalf("expected exit 3, got %d; stderr=%s", code, stderr)
	}
	if !strings.Contains(stderr, "manifest not found") {
		t.Errorf("expected 'manifest not found' in stderr, got %q", stderr)
	}
}

func TestRowRepairDeliverables_SchemaInvalid_MissingEvidencePaths(t *testing.T) {
	root := setupFurrowRoot(t)
	writeRowState(t, root, "test-row", map[string]any{
		"name":        "test-row",
		"archived_at": "2026-04-01T00:00:00Z",
	})

	manifestPath := filepath.Join(t.TempDir(), "bad.yaml")
	// Missing evidence_paths entirely
	mustWrite(t, manifestPath, `version: "1"
deliverables:
  - name: my-deliverable
    status: completed
    commit: abc1234
`)

	code, stderr := runRepairCommand(t, root, []string{
		"test-row", "--manifest", manifestPath,
	})
	if code != 4 {
		t.Fatalf("expected exit 4, got %d; stderr=%s", code, stderr)
	}
	if !strings.Contains(stderr, "evidence_paths") {
		t.Errorf("expected 'evidence_paths' in stderr, got %q", stderr)
	}
}

func TestRowRepairDeliverables_EmptyDeliverables(t *testing.T) {
	root := setupFurrowRoot(t)
	writeRowState(t, root, "test-row", map[string]any{
		"name":        "test-row",
		"archived_at": "2026-04-01T00:00:00Z",
	})

	manifestPath := filepath.Join(t.TempDir(), "empty.yaml")
	mustWrite(t, manifestPath, "version: \"1\"\ndeliverables: []\n")

	code, stderr := runRepairCommand(t, root, []string{
		"test-row", "--manifest", manifestPath,
	})
	if code != 4 {
		t.Fatalf("expected exit 4 for empty deliverables, got %d; stderr=%s", code, stderr)
	}
}

func TestRowRepairDeliverables_ConflictWithoutReplace(t *testing.T) {
	root := setupFurrowRoot(t)
	writeRowState(t, root, "pi-step-row", map[string]any{
		"name":        "pi-step-row",
		"archived_at": "2026-04-01T00:00:00Z",
		"deliverables": map[string]any{
			"backend-work-loop-support": map[string]any{
				"status": "completed",
			},
		},
	})

	manifestPath := filepath.Join(t.TempDir(), "conflict.yaml")
	mustWrite(t, manifestPath, validRepairManifestYAML("backend-work-loop-support"))

	code, stderr := runRepairCommand(t, root, []string{
		"pi-step-row", "--manifest", manifestPath,
	})
	if code != 5 {
		t.Fatalf("expected exit 5, got %d; stderr=%s", code, stderr)
	}
	if !strings.Contains(stderr, "backend-work-loop-support") {
		t.Errorf("expected deliverable name in stderr, got %q", stderr)
	}
	if !strings.Contains(stderr, "--replace") {
		t.Errorf("expected '--replace' in stderr, got %q", stderr)
	}
}

func TestRowRepairDeliverables_ConflictWithReplace(t *testing.T) {
	root := setupFurrowRoot(t)
	writeRowState(t, root, "pi-step-row", map[string]any{
		"name":        "pi-step-row",
		"archived_at": "2026-04-01T00:00:00Z",
		"deliverables": map[string]any{
			"backend-work-loop-support": map[string]any{
				"status": "in_progress",
			},
		},
	})

	manifestPath := filepath.Join(t.TempDir(), "conflict.yaml")
	mustWrite(t, manifestPath, validRepairManifestYAML("backend-work-loop-support"))

	code, payload, stderr := runJSONCommand(t, root, []string{
		"row", "repair-deliverables", "pi-step-row",
		"--manifest", manifestPath,
		"--replace",
		"--json",
	})
	if code != 0 {
		t.Fatalf("expected exit 0 with --replace, got %d; stderr=%s payload=%v", code, stderr, payload)
	}

	// Verify the deliverable was overwritten
	statePath := statePathForRow(root, "pi-step-row")
	state := readJSONFile(t, statePath)
	deliverables := state["deliverables"].(map[string]any)
	entry, ok := deliverables["backend-work-loop-support"].(map[string]any)
	if !ok {
		t.Fatalf("deliverable not found or wrong type")
	}
	if entry["status"] != "completed" {
		t.Errorf("expected status=completed after replace, got %v", entry["status"])
	}
}

func TestRowRepairDeliverables_NonExistentRow(t *testing.T) {
	root := setupFurrowRoot(t)
	// No state.json for "no-such-row"

	manifestPath := filepath.Join(t.TempDir(), "repair.yaml")
	mustWrite(t, manifestPath, validRepairManifestYAML("some-deliverable"))

	code, stderr := runRepairCommand(t, root, []string{
		"no-such-row", "--manifest", manifestPath,
	})
	if code != 2 {
		t.Fatalf("expected exit 2, got %d; stderr=%s", code, stderr)
	}
	if !strings.Contains(stderr, "no-such-row") {
		t.Errorf("expected row name in stderr, got %q", stderr)
	}
}

func TestRowRepairDeliverables_PartialRepair(t *testing.T) {
	root := setupFurrowRoot(t)
	writeRowState(t, root, "partial-row", map[string]any{
		"name":        "partial-row",
		"archived_at": "2026-04-01T00:00:00Z",
		"deliverables": map[string]any{
			"existing-deliverable": map[string]any{
				"status": "completed",
			},
		},
	})

	manifestPath := filepath.Join(t.TempDir(), "partial.yaml")
	// 3 deliverables: 1 existing, 2 new
	mustWrite(t, manifestPath, validRepairManifestYAML("existing-deliverable", "new-one", "new-two"))

	code, stderr := runRepairCommand(t, root, []string{
		"partial-row", "--manifest", manifestPath,
	})
	if code != 0 {
		t.Fatalf("expected exit 0 for partial repair, got %d; stderr=%s", code, stderr)
	}

	statePath := statePathForRow(root, "partial-row")
	state := readJSONFile(t, statePath)
	deliverables := state["deliverables"].(map[string]any)

	for _, name := range []string{"existing-deliverable", "new-one", "new-two"} {
		if _, ok := deliverables[name]; !ok {
			t.Errorf("deliverable %q missing from state after partial repair", name)
		}
	}

	// Verify audit: entries_added has 2, entries_skipped has 1
	auditPath := filepath.Join(root, ".furrow", "rows", "partial-row", "repair-audit.jsonl")
	auditData, err := os.ReadFile(auditPath)
	if err != nil {
		t.Fatalf("repair-audit.jsonl not created: %v", err)
	}
	var auditEntry map[string]any
	if err := json.Unmarshal(bytes.TrimSpace(auditData), &auditEntry); err != nil {
		t.Fatalf("invalid audit JSONL: %v", err)
	}
	added, _, err := auditStringSlices(auditEntry)
	if err != nil {
		t.Fatal(err)
	}
	if len(added) != 2 {
		t.Errorf("expected 2 entries_added, got %v", added)
	}
	skipped := auditSkipped(auditEntry)
	if len(skipped) != 1 || skipped[0] != "existing-deliverable" {
		t.Errorf("expected entries_skipped=[existing-deliverable], got %v", skipped)
	}
}

func TestRowRepairDeliverables_NonArchivedWithoutForceActive(t *testing.T) {
	root := setupFurrowRoot(t)
	writeRowState(t, root, "active-row", map[string]any{
		"name":        "active-row",
		"archived_at": nil,
		"updated_at":  "2026-04-01T00:00:00Z",
	})

	manifestPath := filepath.Join(t.TempDir(), "repair.yaml")
	mustWrite(t, manifestPath, validRepairManifestYAML("some-deliverable"))

	code, stderr := runRepairCommand(t, root, []string{
		"active-row", "--manifest", manifestPath,
	})
	if code != 1 {
		t.Fatalf("expected exit 1 for non-archived row, got %d; stderr=%s", code, stderr)
	}
	if !strings.Contains(stderr, "--force-active") {
		t.Errorf("expected '--force-active' in stderr, got %q", stderr)
	}
}

func TestRowRepairDeliverables_NonArchivedWithForceActive(t *testing.T) {
	root := setupFurrowRoot(t)
	writeRowState(t, root, "active-row", map[string]any{
		"name":        "active-row",
		"archived_at": nil,
		"updated_at":  "2026-04-01T00:00:00Z",
	})

	manifestPath := filepath.Join(t.TempDir(), "repair.yaml")
	mustWrite(t, manifestPath, validRepairManifestYAML("some-deliverable"))

	code, stderr := runRepairCommand(t, root, []string{
		"active-row", "--manifest", manifestPath, "--force-active",
	})
	if code != 0 {
		t.Fatalf("expected exit 0 with --force-active, got %d; stderr=%s", code, stderr)
	}
}

// --- helpers ---

// auditStringSlices extracts (entries_added, _, error) from an audit entry.
func auditStringSlices(entry map[string]any) (added []string, _ struct{}, err error) {
	raw, ok := entry["entries_added"]
	if !ok {
		return nil, struct{}{}, nil
	}
	slice, ok := raw.([]any)
	if !ok {
		return nil, struct{}{}, fmt.Errorf("entries_added is not an array: %T", raw)
	}
	for _, v := range slice {
		s, ok := v.(string)
		if !ok {
			return nil, struct{}{}, fmt.Errorf("entries_added item is not string: %T", v)
		}
		added = append(added, s)
	}
	return added, struct{}{}, nil
}

func auditSkipped(entry map[string]any) []string {
	raw, ok := entry["entries_skipped"]
	if !ok {
		return nil
	}
	slice, ok := raw.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(slice))
	for _, v := range slice {
		if s, ok := v.(string); ok {
			out = append(out, s)
		}
	}
	return out
}

func readRepairAuditLast(t *testing.T, root, rowName string) map[string]any {
	t.Helper()
	auditPath := filepath.Join(root, ".furrow", "rows", rowName, "repair-audit.jsonl")
	data, err := os.ReadFile(auditPath)
	if err != nil {
		t.Fatalf("repair-audit.jsonl not found: %v", err)
	}
	scanner := bufio.NewScanner(bytes.NewReader(data))
	var lastLine string
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" {
			lastLine = line
		}
	}
	if lastLine == "" {
		t.Fatal("repair-audit.jsonl is empty")
	}
	var entry map[string]any
	if err := json.Unmarshal([]byte(lastLine), &entry); err != nil {
		t.Fatalf("invalid JSONL line: %v; line=%q", err, lastLine)
	}
	return entry
}
