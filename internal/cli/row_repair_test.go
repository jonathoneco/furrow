package cli

import (
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

// readAuditFile reads the entire audit JSONL file and returns all entries.
func readAuditFile(t *testing.T, root, rowName string) []map[string]any {
	t.Helper()
	auditPath := filepath.Join(root, ".furrow", "rows", rowName, "repair-audit.jsonl")
	data, err := os.ReadFile(auditPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		t.Fatalf("read repair-audit.jsonl: %v", err)
	}
	var entries []map[string]any
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		var entry map[string]any
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			t.Fatalf("invalid JSONL line: %v; line=%q", err, line)
		}
		entries = append(entries, entry)
	}
	return entries
}

// TestRowRepairDeliverables is the unified table-driven test for the repair-deliverables command.
func TestRowRepairDeliverables(t *testing.T) {
	cases := []struct {
		name     string
		manifest string         // YAML contents to write to manifest file; empty means don't create
		setup    func(t *testing.T, root string)
		args     []string // appended after the row name (row name is "test-row" unless overridden by fullArgs)
		rowName  string   // defaults to "test-row"
		fullArgs []string // if set, used as the complete args list (after "row repair-deliverables")
		wantExit int
		check    func(t *testing.T, root string)
	}{
		{
			name:     "happy path - two new deliverables",
			manifest: validRepairManifestYAML("backend-work-loop-support", "pi-work-command"),
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "test-row", map[string]any{
					"name":        "test-row",
					"archived_at": "2026-04-01T00:00:00Z",
					"updated_at":  "2026-04-01T00:00:00Z",
				})
			},
			wantExit: 0,
			check: func(t *testing.T, root string) {
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
				entries := readAuditFile(t, root, "test-row")
				if len(entries) != 1 {
					t.Fatalf("expected 1 audit entry, got %d", len(entries))
				}
				added, _, err := auditStringSlices(entries[0])
				if err != nil {
					t.Fatal(err)
				}
				if len(added) != 2 {
					t.Errorf("expected 2 entries_added, got %v", added)
				}
				skipped := auditSkipped(entries[0])
				if len(skipped) != 0 {
					t.Errorf("expected 0 entries_skipped, got %v", skipped)
				}
			},
		},
		{
			name:     "missing manifest",
			manifest: "", // don't create
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "test-row", map[string]any{
					"name":        "test-row",
					"archived_at": "2026-04-01T00:00:00Z",
				})
			},
			fullArgs: []string{"test-row", "--manifest", "/nonexistent/path.yaml"},
			wantExit: 3,
			check: func(t *testing.T, root string) {},
		},
		{
			name:     "schema invalid - missing evidence_paths",
			manifest: "version: \"1\"\ndeliverables:\n  - name: my-deliverable\n    status: completed\n    commit: abc1234\n",
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "test-row", map[string]any{
					"name":        "test-row",
					"archived_at": "2026-04-01T00:00:00Z",
				})
			},
			wantExit: 4,
			check:    func(t *testing.T, root string) {},
		},
		{
			name:     "schema invalid - empty deliverables list",
			manifest: "version: \"1\"\ndeliverables: []\n",
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "test-row", map[string]any{
					"name":        "test-row",
					"archived_at": "2026-04-01T00:00:00Z",
				})
			},
			wantExit: 4,
			check:    func(t *testing.T, root string) {},
		},
		{
			name:     "conflict without --replace",
			manifest: validRepairManifestYAML("backend-work-loop-support"),
			rowName:  "pi-step-row",
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "pi-step-row", map[string]any{
					"name":        "pi-step-row",
					"archived_at": "2026-04-01T00:00:00Z",
					"deliverables": map[string]any{
						"backend-work-loop-support": map[string]any{
							"status": "completed",
						},
					},
				})
			},
			wantExit: 5,
			check:    func(t *testing.T, root string) {},
		},
		{
			name:     "conflict with --replace - overwrites existing",
			manifest: validRepairManifestYAML("backend-work-loop-support"),
			rowName:  "pi-step-row",
			args:     []string{"--replace"},
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "pi-step-row", map[string]any{
					"name":        "pi-step-row",
					"archived_at": "2026-04-01T00:00:00Z",
					"deliverables": map[string]any{
						"backend-work-loop-support": map[string]any{
							"status": "in_progress",
						},
					},
				})
			},
			wantExit: 0,
			check: func(t *testing.T, root string) {
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
			},
		},
		{
			name:    "non-existent row",
			rowName: "no-such-row",
			setup:   func(t *testing.T, root string) {},
			// manifest will be created but row won't exist
			manifest: validRepairManifestYAML("some-deliverable"),
			wantExit: 2,
			check:    func(t *testing.T, root string) {},
		},
		{
			name:     "partial repair - skips existing, adds new",
			manifest: validRepairManifestYAML("existing-deliverable", "new-one", "new-two"),
			rowName:  "partial-row",
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "partial-row", map[string]any{
					"name":        "partial-row",
					"archived_at": "2026-04-01T00:00:00Z",
					"deliverables": map[string]any{
						"existing-deliverable": map[string]any{
							"status": "completed",
						},
					},
				})
			},
			wantExit: 0,
			check: func(t *testing.T, root string) {
				statePath := statePathForRow(root, "partial-row")
				state := readJSONFile(t, statePath)
				deliverables := state["deliverables"].(map[string]any)
				for _, name := range []string{"existing-deliverable", "new-one", "new-two"} {
					if _, ok := deliverables[name]; !ok {
						t.Errorf("deliverable %q missing from state after partial repair", name)
					}
				}
				entries := readAuditFile(t, root, "partial-row")
				if len(entries) != 1 {
					t.Fatalf("expected 1 audit entry, got %d", len(entries))
				}
				added, _, err := auditStringSlices(entries[0])
				if err != nil {
					t.Fatal(err)
				}
				if len(added) != 2 {
					t.Errorf("expected 2 entries_added, got %v", added)
				}
				skipped := auditSkipped(entries[0])
				if len(skipped) != 1 || skipped[0] != "existing-deliverable" {
					t.Errorf("expected entries_skipped=[existing-deliverable], got %v", skipped)
				}
			},
		},
		{
			name:     "non-archived row without --force-active is rejected",
			manifest: validRepairManifestYAML("some-deliverable"),
			rowName:  "active-row",
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "active-row", map[string]any{
					"name":        "active-row",
					"archived_at": nil,
					"updated_at":  "2026-04-01T00:00:00Z",
				})
			},
			wantExit: 1,
			check:    func(t *testing.T, root string) {},
		},
		{
			name:     "non-archived row with --force-active is accepted",
			manifest: validRepairManifestYAML("some-deliverable"),
			rowName:  "active-row",
			args:     []string{"--force-active"},
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "active-row", map[string]any{
					"name":        "active-row",
					"archived_at": nil,
					"updated_at":  "2026-04-01T00:00:00Z",
				})
			},
			wantExit: 0,
			check:    func(t *testing.T, root string) {},
		},
		// Fix 1 regression test: state write failure must not leave orphan audit entry.
		{
			name:     "state write failure does not leave orphan audit entry",
			manifest: validRepairManifestYAML("some-deliverable"),
			rowName:  "perm-row",
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "perm-row", map[string]any{
					"name":        "perm-row",
					"archived_at": "2026-04-01T00:00:00Z",
				})
				// Make the row directory unwritable so writeJSONMapAtomic (CreateTemp) fails.
				rowDir := filepath.Join(root, ".furrow", "rows", "perm-row")
				if err := os.Chmod(rowDir, 0o555); err != nil {
					t.Fatalf("chmod row dir: %v", err)
				}
				t.Cleanup(func() {
					// Restore so t.TempDir cleanup can remove the directory.
					_ = os.Chmod(rowDir, 0o755)
				})
			},
			wantExit: 6,
			check: func(t *testing.T, root string) {
				// Audit file must not exist or have zero entries (no orphan entry).
				entries := readAuditFile(t, root, "perm-row")
				if len(entries) != 0 {
					t.Errorf("expected 0 audit entries after failed state write, got %d", len(entries))
				}
			},
		},
		// Fix 2 schema strictness tests: unknown fields are rejected.
		{
			name: "rejects unknown top-level field",
			manifest: `version: "1"
commit: abc1234
unexpected: still-here
deliverables:
  - name: my-deliverable
    status: completed
    commit: abc1234
    evidence_paths:
      - path: some/file.md
`,
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "test-row", map[string]any{
					"name":        "test-row",
					"archived_at": "2026-04-01T00:00:00Z",
				})
			},
			wantExit: 4,
			check:    func(t *testing.T, root string) {},
		},
		{
			name: "rejects unknown deliverable field",
			manifest: `version: "1"
commit: abc1234
deliverables:
  - name: my-deliverable
    status: completed
    commit: abc1234
    bogus_field: oops
    evidence_paths:
      - path: some/file.md
`,
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "test-row", map[string]any{
					"name":        "test-row",
					"archived_at": "2026-04-01T00:00:00Z",
				})
			},
			wantExit: 4,
			check:    func(t *testing.T, root string) {},
		},
		{
			name: "rejects unknown evidence_paths field",
			manifest: `version: "1"
commit: abc1234
deliverables:
  - name: my-deliverable
    status: completed
    commit: abc1234
    evidence_paths:
      - path: some/file.md
        unknown_key: bad
`,
			setup: func(t *testing.T, root string) {
				writeRowState(t, root, "test-row", map[string]any{
					"name":        "test-row",
					"archived_at": "2026-04-01T00:00:00Z",
				})
			},
			wantExit: 4,
			check:    func(t *testing.T, root string) {},
		},
		// Fix 5: --help exits 0 and prints usage.
		{
			name:     "--help exits 0",
			setup:    func(t *testing.T, root string) {},
			fullArgs: []string{"--help"},
			wantExit: 0,
			check:    func(t *testing.T, root string) {},
		},
		{
			name:     "-h exits 0",
			setup:    func(t *testing.T, root string) {},
			fullArgs: []string{"-h"},
			wantExit: 0,
			check:    func(t *testing.T, root string) {},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			root := setupFurrowRoot(t)

			// Determine row name.
			rowName := tc.rowName
			if rowName == "" {
				rowName = "test-row"
			}

			// Run setup.
			if tc.setup != nil {
				tc.setup(t, root)
			}

			// Build the args list.
			var cmdArgs []string
			if tc.fullArgs != nil {
				cmdArgs = tc.fullArgs
			} else {
				// Write manifest to temp file.
				manifestPath := filepath.Join(t.TempDir(), "manifest.yaml")
				if tc.manifest != "" {
					mustWrite(t, manifestPath, tc.manifest)
				}
				cmdArgs = append([]string{rowName, "--manifest", manifestPath}, tc.args...)
			}

			code, _ := runRepairCommand(t, root, cmdArgs)
			if code != tc.wantExit {
				// Re-run to capture stderr for the error message.
				var stderr bytes.Buffer
				var stdout bytes.Buffer
				oldwd, err := os.Getwd()
				if err != nil {
					t.Fatal(err)
				}
				defer func() { _ = os.Chdir(oldwd) }()
				_ = os.Chdir(root)
				app := New(&stdout, &stderr)
				app.Run(append([]string{"row", "repair-deliverables"}, cmdArgs...))
				t.Fatalf("expected exit %d, got %d; stderr=%s stdout=%s", tc.wantExit, code, stderr.String(), stdout.String())
			}

			if tc.check != nil {
				tc.check(t, root)
			}
		})
	}
}
