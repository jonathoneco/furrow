package context

import (
	"os"
	"path/filepath"
	"testing"
)

// TestReadFocusedRow_CanonicalFilename is a regression for a bug found
// during the pi-dogfood walkthrough on 2026-04-28: this package's
// readFocusedRow was reading `.furrow/focus` (no leading dot), but the
// canonical focused-row file is `.furrow/.focused` (with the leading dot)
// per internal/cli/util.go readFocusedRowName, internal/cli/row_workflow.go,
// and adapters/pi/furrow.ts isCanonicalStatePath. The bug made every
// focused-row resolution fail silently with "no such file or directory",
// forcing callers to always pass --row.
func TestReadFocusedRow_CanonicalFilename(t *testing.T) {
	root := t.TempDir()
	furrowDir := filepath.Join(root, ".furrow")
	if err := os.MkdirAll(furrowDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}

	// Write to the canonical filename (.focused with leading dot).
	if err := os.WriteFile(filepath.Join(furrowDir, ".focused"), []byte("my-row\n"), 0o600); err != nil {
		t.Fatalf("write: %v", err)
	}

	got, err := readFocusedRow(root)
	if err != nil {
		t.Fatalf("readFocusedRow: %v", err)
	}
	if got != "my-row" {
		t.Fatalf("readFocusedRow = %q, want %q", got, "my-row")
	}
}

// TestReadFocusedRow_RejectsLegacyFilename confirms the bug doesn't
// reappear: a `.furrow/focus` file (no leading dot) MUST NOT be picked up.
func TestReadFocusedRow_RejectsLegacyFilename(t *testing.T) {
	root := t.TempDir()
	furrowDir := filepath.Join(root, ".furrow")
	if err := os.MkdirAll(furrowDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}

	// Write to the WRONG filename — readFocusedRow must NOT find this.
	if err := os.WriteFile(filepath.Join(furrowDir, "focus"), []byte("legacy-name\n"), 0o600); err != nil {
		t.Fatalf("write: %v", err)
	}

	got, err := readFocusedRow(root)
	if err == nil {
		t.Fatalf("expected error reading focused-row from missing .focused, got %q", got)
	}
}

// TestReadFocusedRow_EmptyFile surfaces an empty-file error rather than
// silently returning "".
func TestReadFocusedRow_EmptyFile(t *testing.T) {
	root := t.TempDir()
	furrowDir := filepath.Join(root, ".furrow")
	if err := os.MkdirAll(furrowDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}

	if err := os.WriteFile(filepath.Join(furrowDir, ".focused"), []byte("   \n"), 0o600); err != nil {
		t.Fatalf("write: %v", err)
	}

	_, err := readFocusedRow(root)
	if err == nil {
		t.Fatal("expected error for empty .focused file")
	}
}
