package cli_test

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jonathoneco/furrow/internal/cli"
)

var validDriverSteps = []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}

func writeDriverDef(t *testing.T, dir, step, content string) {
	t.Helper()
	path := filepath.Join(dir, fmt.Sprintf("driver-%s.yaml", step))
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatalf("write driver def: %v", err)
	}
}

func validDriverContent(step string) string {
	return fmt.Sprintf(`name: driver:%s
step: %s
tools_allowlist:
  - Read
  - Bash
  - Grep
model: claude-sonnet-4-5
`, step, step)
}

func setupDriversDir(t *testing.T) (driversDir string, cleanup func()) {
	t.Helper()
	dir := t.TempDir()
	driversDir = filepath.Join(dir, ".furrow", "drivers")
	if err := os.MkdirAll(driversDir, 0o755); err != nil {
		t.Fatalf("mkdir drivers: %v", err)
	}
	return driversDir, func() {}
}

func TestValidateDriverDefinitions_AllValid(t *testing.T) {
	driversDir, _ := setupDriversDir(t)

	for _, step := range validDriverSteps {
		writeDriverDef(t, driversDir, step, validDriverContent(step))
	}

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "driver-definitions", "--drivers-dir", driversDir})
	if exit != 0 {
		t.Errorf("exit = %d; want 0\nstderr: %s", exit, stderr.String())
	}
}

func TestValidateDriverDefinitions_MissingFile(t *testing.T) {
	driversDir, _ := setupDriversDir(t)
	// Write only 6 of 7 drivers (missing "review").
	for _, step := range validDriverSteps[:6] {
		writeDriverDef(t, driversDir, step, validDriverContent(step))
	}

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "driver-definitions", "--drivers-dir", driversDir})
	if exit == 0 {
		t.Error("expected non-zero exit for missing driver definition; got 0")
	}
	if !strings.Contains(stderr.String(), "driver_definition_invalid") {
		t.Errorf("expected driver_definition_invalid in stderr; got: %s", stderr.String())
	}
}

func TestValidateDriverDefinitions_MissingName(t *testing.T) {
	driversDir, _ := setupDriversDir(t)
	for _, step := range validDriverSteps {
		content := validDriverContent(step)
		if step == "plan" {
			content = fmt.Sprintf(`step: %s
tools_allowlist:
  - Read
model: claude-sonnet-4-5
`, step)
		}
		writeDriverDef(t, driversDir, step, content)
	}

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "driver-definitions", "--drivers-dir", driversDir})
	if exit == 0 {
		t.Error("expected non-zero exit for missing name field; got 0")
	}
}

func TestValidateDriverDefinitions_MissingModel(t *testing.T) {
	driversDir, _ := setupDriversDir(t)
	for _, step := range validDriverSteps {
		content := validDriverContent(step)
		if step == "ideate" {
			content = fmt.Sprintf(`name: driver:%s
step: %s
tools_allowlist:
  - Read
`, step, step)
		}
		writeDriverDef(t, driversDir, step, content)
	}

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "driver-definitions", "--drivers-dir", driversDir})
	if exit == 0 {
		t.Error("expected non-zero exit for missing model field; got 0")
	}
}

func TestValidateDriverDefinitions_JSONOutput(t *testing.T) {
	driversDir, _ := setupDriversDir(t)
	for _, step := range validDriverSteps {
		writeDriverDef(t, driversDir, step, validDriverContent(step))
	}

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "driver-definitions", "--drivers-dir", driversDir, "--json"})
	if exit != 0 {
		t.Errorf("exit = %d; want 0\nstderr: %s\nstdout: %s", exit, stderr.String(), stdout.String())
	}
	if !strings.Contains(stdout.String(), `"ok": true`) {
		t.Errorf("expected ok:true in JSON; got: %s", stdout.String())
	}
}
