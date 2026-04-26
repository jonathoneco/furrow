package cli_test

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jonathoneco/furrow/internal/cli"
)

func setupSkillsFixture(t *testing.T) (dir string, cleanup func()) {
	t.Helper()
	dir = t.TempDir()
	skillsDir := filepath.Join(dir, "skills")
	if err := os.MkdirAll(filepath.Join(skillsDir, "shared"), 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	return dir, func() {}
}

func writeSkillFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir for skill: %v", err)
	}
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatalf("write skill: %v", err)
	}
}

func TestValidateSkillLayers_AllValid(t *testing.T) {
	dir, _ := setupSkillsFixture(t)
	skillsDir := filepath.Join(dir, "skills")

	writeSkillFile(t, filepath.Join(skillsDir, "ideate.md"),
		"---\nlayer: driver\n---\n# Ideate\n")
	writeSkillFile(t, filepath.Join(skillsDir, "work-context.md"),
		"---\nlayer: operator\n---\n# Work Context\n")
	writeSkillFile(t, filepath.Join(skillsDir, "shared", "layer-protocol.md"),
		"---\nlayer: shared\n---\n# Layer Protocol\n")

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "skill-layers", "--skills-dir", skillsDir})
	if exit != 0 {
		t.Errorf("exit = %d; want 0\nstderr: %s\nstdout: %s", exit, stderr.String(), stdout.String())
	}
}

func TestValidateSkillLayers_MissingLayer(t *testing.T) {
	dir, _ := setupSkillsFixture(t)
	skillsDir := filepath.Join(dir, "skills")

	writeSkillFile(t, filepath.Join(skillsDir, "ideate.md"),
		"# Ideate\n\nNo front-matter here.\n")

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "skill-layers", "--skills-dir", skillsDir})
	if exit == 0 {
		t.Error("expected non-zero exit for missing layer front-matter; got 0")
	}
	if !strings.Contains(stderr.String(), "skill_layer_unset") {
		t.Errorf("expected skill_layer_unset in stderr; got: %s", stderr.String())
	}
}

func TestValidateSkillLayers_MissingLayerJSON(t *testing.T) {
	dir, _ := setupSkillsFixture(t)
	skillsDir := filepath.Join(dir, "skills")

	writeSkillFile(t, filepath.Join(skillsDir, "plan.md"),
		"# Plan\n\nNo front-matter.\n")

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "skill-layers", "--skills-dir", skillsDir, "--json"})
	if exit == 0 {
		t.Error("expected non-zero exit for missing layer front-matter (JSON mode)")
	}
	if !strings.Contains(stdout.String(), "skill_layer_unset") {
		t.Errorf("expected skill_layer_unset in JSON stdout; got: %s", stdout.String())
	}
}

func TestValidateSkillLayers_InvalidLayerValue(t *testing.T) {
	dir, _ := setupSkillsFixture(t)
	skillsDir := filepath.Join(dir, "skills")

	writeSkillFile(t, filepath.Join(skillsDir, "spec.md"),
		"---\nlayer: invalid-layer\n---\n# Spec\n")

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "skill-layers", "--skills-dir", skillsDir})
	if exit == 0 {
		t.Error("expected non-zero exit for invalid layer value; got 0")
	}
}

func TestValidateSkillLayers_FrontMatterMixed(t *testing.T) {
	dir, _ := setupSkillsFixture(t)
	skillsDir := filepath.Join(dir, "skills")

	// Two valid, one missing.
	writeSkillFile(t, filepath.Join(skillsDir, "research.md"),
		"---\nlayer: driver\n---\n# Research\n")
	writeSkillFile(t, filepath.Join(skillsDir, "review.md"),
		"---\nlayer: driver\n---\n# Review\n")
	writeSkillFile(t, filepath.Join(skillsDir, "orphan.md"),
		"# No front-matter\n")

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "skill-layers", "--skills-dir", skillsDir})
	if exit == 0 {
		t.Error("expected non-zero exit when some skills lack layer front-matter")
	}
}

func TestValidateSkillLayers_EmptyDir(t *testing.T) {
	dir, _ := setupSkillsFixture(t)
	skillsDir := filepath.Join(dir, "skills")
	// No .md files written — dir is empty.

	var stdout, stderr bytes.Buffer
	app := cli.New(&stdout, &stderr)
	exit := app.Run([]string{"validate", "skill-layers", "--skills-dir", skillsDir})
	if exit != 0 {
		t.Errorf("empty skills dir should pass (nothing to check); got exit %d\nstderr: %s", exit, stderr.String())
	}
}
