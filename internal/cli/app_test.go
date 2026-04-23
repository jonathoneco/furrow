package cli

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestRootHelp(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	app := New(&stdout, &stderr)
	code := app.Run(nil)
	if code != 0 {
		t.Fatalf("expected exit 0, got %d", code)
	}
	if !bytes.Contains(stdout.Bytes(), []byte("furrow — Go CLI surface draft")) {
		t.Fatalf("expected root help output, got %s", stdout.String())
	}
}

func TestRowStatusJSON(t *testing.T) {
	temp := t.TempDir()
	mustMkdirAll(t, filepath.Join(temp, ".furrow", "rows", "demo-row"))
	mustWrite(t, filepath.Join(temp, ".furrow", ".focused"), "demo-row\n")
	mustWrite(t, filepath.Join(temp, ".furrow", "rows", "demo-row", "state.json"), `{"name":"demo-row","step":"implement","step_status":"in_progress"}`)

	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(temp); err != nil {
		t.Fatal(err)
	}

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	app := New(&stdout, &stderr)
	code := app.Run([]string{"row", "status", "--json"})
	if code != 0 {
		t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr.String())
	}

	var payload map[string]any
	if err := json.Unmarshal(stdout.Bytes(), &payload); err != nil {
		t.Fatalf("invalid json output: %v\n%s", err, stdout.String())
	}
	if payload["ok"] != true {
		t.Fatalf("expected ok=true, got %#v", payload["ok"])
	}
}

func TestDoctorJSONWhenMissingRoot(t *testing.T) {
	temp := t.TempDir()
	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(temp); err != nil {
		t.Fatal(err)
	}

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	app := New(&stdout, &stderr)
	code := app.Run([]string{"doctor", "--json"})
	if code != 5 {
		t.Fatalf("expected exit 5, got %d", code)
	}
	if !bytes.Contains(stdout.Bytes(), []byte(`"ok": false`)) {
		t.Fatalf("expected json error output, got %s", stdout.String())
	}
}

func mustMkdirAll(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(path, 0o755); err != nil {
		t.Fatal(err)
	}
}

func mustWrite(t *testing.T, path string, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
