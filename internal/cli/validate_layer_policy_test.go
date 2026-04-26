package cli_test

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jonathoneco/furrow/internal/cli"
)

const validLayerPolicyYAML = `
version: "1"
agent_type_map:
  operator: operator
  driver:plan: driver
  engine:freeform: engine
layers:
  operator:
    tools_allow: ["*"]
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []
  driver:
    tools_allow: ["Read", "Bash"]
    tools_deny: ["Edit", "Write"]
    path_deny: []
    bash_allow_prefixes: ["rws "]
    bash_deny_substrings: ["rm -"]
  engine:
    tools_allow: ["Read", "Edit", "Write", "Bash"]
    tools_deny: ["SendMessage"]
    path_deny: [".furrow/"]
    bash_allow_prefixes: []
    bash_deny_substrings: ["furrow "]
`

func setupLayerPolicyFixture(t *testing.T, content string) (string, func()) {
	t.Helper()
	dir := t.TempDir()
	furrowDir := filepath.Join(dir, ".furrow")
	if err := os.MkdirAll(furrowDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	policyPath := filepath.Join(furrowDir, "layer-policy.yaml")
	if err := os.WriteFile(policyPath, []byte(content), 0o600); err != nil {
		t.Fatalf("write policy: %v", err)
	}
	orig, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	return policyPath, func() { _ = os.Chdir(orig) }
}

func TestRunValidateLayerPolicy_Valid(t *testing.T) {
	policyPath, cleanup := setupLayerPolicyFixture(t, validLayerPolicyYAML)
	defer cleanup()

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "layer-policy", "--policy", policyPath})
	if exit != 0 {
		t.Errorf("exit = %d; want 0\nstderr: %s", exit, stderr.String())
	}
	if !strings.Contains(stdout.String(), "valid") {
		t.Errorf("expected 'valid' in stdout; got: %s", stdout.String())
	}
}

func TestRunValidateLayerPolicy_ValidJSON(t *testing.T) {
	policyPath, cleanup := setupLayerPolicyFixture(t, validLayerPolicyYAML)
	defer cleanup()

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "layer-policy", "--policy", policyPath, "--json"})
	if exit != 0 {
		t.Errorf("exit = %d; want 0\nstderr: %s", exit, stderr.String())
	}
	if !strings.Contains(stdout.String(), `"ok": true`) {
		t.Errorf("expected ok:true in JSON; got: %s", stdout.String())
	}
}

func TestRunValidateLayerPolicy_InvalidPolicy(t *testing.T) {
	policyPath, cleanup := setupLayerPolicyFixture(t, "version: []  # wrong type")
	defer cleanup()

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "layer-policy", "--policy", policyPath})
	if exit == 0 {
		t.Errorf("expected non-zero exit for invalid policy; got 0\nstdout: %s", stdout.String())
	}
}

func TestRunValidateLayerPolicy_MissingFile(t *testing.T) {
	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "layer-policy", "--policy", "/nonexistent/layer-policy.yaml"})
	if exit == 0 {
		t.Error("expected non-zero exit for missing file")
	}
}
