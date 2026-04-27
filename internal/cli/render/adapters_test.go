package render_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jonathoneco/furrow/internal/cli/render"
)

// buildFixtureDir creates a minimal project tree sufficient for RenderAdapters tests.
func buildFixtureDir(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()

	// commands/work.md.tmpl
	if err := os.MkdirAll(filepath.Join(dir, "commands"), 0o755); err != nil {
		t.Fatal(err)
	}
	tmpl := `# /work{{if eq .Runtime "claude"}}
Claude block: Agent(name="driver:{step}")
{{- else if eq .Runtime "pi"}}
Pi block: pi-subagents
{{- end}}`
	mustWrite(t, filepath.Join(dir, "commands", "work.md.tmpl"), tmpl)

	// .furrow/drivers/driver-{step}.yaml
	steps := []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}
	if err := os.MkdirAll(filepath.Join(dir, ".furrow", "drivers"), 0o755); err != nil {
		t.Fatal(err)
	}
	for _, step := range steps {
		content := "name: driver:" + step + "\nstep: " + step + "\ntools_allowlist:\n  - Read\nmodel: sonnet\n"
		mustWrite(t, filepath.Join(dir, ".furrow", "drivers", "driver-"+step+".yaml"), content)
	}

	// skills/{step}.md
	if err := os.MkdirAll(filepath.Join(dir, "skills"), 0o755); err != nil {
		t.Fatal(err)
	}
	for _, step := range steps {
		mustWrite(t, filepath.Join(dir, "skills", step+".md"), "# Phase Driver Brief: "+step+"\n\nYou are the "+step+" phase driver.\n")
	}

	return dir
}

func mustWrite(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestRenderAdapters_Claude_WorkMd(t *testing.T) {
	dir := buildFixtureDir(t)
	ctx := render.RenderCtx{Runtime: render.RuntimeClaude, RowName: "test-row", ProjectDir: dir}

	files, err := render.RenderAdapters(ctx, dir)
	if err != nil {
		t.Fatalf("RenderAdapters: %v", err)
	}

	var workMd *render.RenderedFile
	for i := range files {
		if files[i].Path == "commands/work.md" {
			workMd = &files[i]
			break
		}
	}
	if workMd == nil {
		t.Fatal("commands/work.md not found in rendered output")
	}

	content := string(workMd.Content)
	if !strings.Contains(content, `Agent(name="driver:{step}")`) {
		t.Errorf("Claude work.md missing Claude block; got:\n%s", content)
	}
	if strings.Contains(content, "pi-subagents") {
		t.Errorf("Claude work.md should not contain pi-subagents; got:\n%s", content)
	}
}

func TestRenderAdapters_Pi_WorkMd(t *testing.T) {
	dir := buildFixtureDir(t)
	ctx := render.RenderCtx{Runtime: render.RuntimePi, RowName: "test-row", ProjectDir: dir}

	files, err := render.RenderAdapters(ctx, dir)
	if err != nil {
		t.Fatalf("RenderAdapters: %v", err)
	}

	var workMd *render.RenderedFile
	for i := range files {
		if files[i].Path == "commands/work.md" {
			workMd = &files[i]
			break
		}
	}
	if workMd == nil {
		t.Fatal("commands/work.md not found in rendered output")
	}

	content := string(workMd.Content)
	if !strings.Contains(content, "pi-subagents") {
		t.Errorf("Pi work.md missing pi-subagents block; got:\n%s", content)
	}
	if strings.Contains(content, `Agent(name="driver:{step}")`) {
		t.Errorf("Pi work.md should not contain Claude Agent block; got:\n%s", content)
	}
}

func TestRenderAdapters_Claude_AgentFiles(t *testing.T) {
	dir := buildFixtureDir(t)
	ctx := render.RenderCtx{Runtime: render.RuntimeClaude, RowName: "test-row", ProjectDir: dir}

	files, err := render.RenderAdapters(ctx, dir)
	if err != nil {
		t.Fatalf("RenderAdapters: %v", err)
	}

	steps := []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}
	agentPaths := make(map[string]bool)
	for _, f := range files {
		agentPaths[f.Path] = true
	}

	for _, step := range steps {
		path := ".claude/agents/driver-" + step + ".md"
		if !agentPaths[path] {
			t.Errorf("missing expected agent file: %s", path)
			continue
		}

		var agent *render.RenderedFile
		for i := range files {
			if files[i].Path == path {
				agent = &files[i]
				break
			}
		}
		content := string(agent.Content)

		// Must contain YAML frontmatter fields.
		if !strings.Contains(content, `"driver:`+step+`"`) {
			t.Errorf("%s: missing name field in frontmatter", path)
		}
		if !strings.Contains(content, "model:") {
			t.Errorf("%s: missing model field in frontmatter", path)
		}
		if !strings.Contains(content, "tools:") {
			t.Errorf("%s: missing tools field in frontmatter", path)
		}

		// Body must contain the skill content.
		if !strings.Contains(content, "phase driver") {
			t.Errorf("%s: skill body not embedded (missing 'phase driver')", path)
		}
	}
}

func TestRenderAdapters_Pi_NoAgentFiles(t *testing.T) {
	dir := buildFixtureDir(t)
	ctx := render.RenderCtx{Runtime: render.RuntimePi, RowName: "test-row", ProjectDir: dir}

	files, err := render.RenderAdapters(ctx, dir)
	if err != nil {
		t.Fatalf("RenderAdapters: %v", err)
	}

	for _, f := range files {
		if strings.HasPrefix(f.Path, ".claude/agents/") {
			t.Errorf("Pi render should not produce .claude/agents files, got: %s", f.Path)
		}
	}
}

func TestRenderAdapters_Idempotent(t *testing.T) {
	dir := buildFixtureDir(t)
	ctx := render.RenderCtx{Runtime: render.RuntimeClaude, RowName: "test-row", ProjectDir: dir}

	files1, err := render.RenderAdapters(ctx, dir)
	if err != nil {
		t.Fatalf("first RenderAdapters: %v", err)
	}
	files2, err := render.RenderAdapters(ctx, dir)
	if err != nil {
		t.Fatalf("second RenderAdapters: %v", err)
	}

	if len(files1) != len(files2) {
		t.Fatalf("idempotency: file count differs: %d vs %d", len(files1), len(files2))
	}
	for i := range files1 {
		if files1[i].Path != files2[i].Path {
			t.Errorf("idempotency: path[%d] differs: %q vs %q", i, files1[i].Path, files2[i].Path)
		}
		if string(files1[i].Content) != string(files2[i].Content) {
			t.Errorf("idempotency: content differs for %s", files1[i].Path)
		}
	}
}

func TestRenderAdapters_StableOrder(t *testing.T) {
	dir := buildFixtureDir(t)
	ctx := render.RenderCtx{Runtime: render.RuntimeClaude, RowName: "test-row", ProjectDir: dir}

	files, err := render.RenderAdapters(ctx, dir)
	if err != nil {
		t.Fatalf("RenderAdapters: %v", err)
	}

	for i := 1; i < len(files); i++ {
		if files[i].Path < files[i-1].Path {
			t.Errorf("output not sorted: files[%d]=%q < files[%d]=%q", i, files[i].Path, i-1, files[i-1].Path)
		}
	}
}

func TestHandler_Run_NoArgs(t *testing.T) {
	var out, errOut strings.Builder
	h := render.New(&out, &errOut)
	code := h.Run(nil)
	if code != 0 {
		t.Errorf("expected exit 0, got %d (stderr: %s)", code, errOut.String())
	}
}

func TestHandler_Run_UnknownRuntime(t *testing.T) {
	var out, errOut strings.Builder
	h := render.New(&out, &errOut)
	code := h.Run([]string{"adapters", "--runtime=bogus"})
	if code == 0 {
		t.Error("expected non-zero exit for unknown runtime")
	}
}

func TestHandler_Run_MissingRuntime(t *testing.T) {
	var out, errOut strings.Builder
	h := render.New(&out, &errOut)
	code := h.Run([]string{"adapters"})
	if code == 0 {
		t.Error("expected non-zero exit for missing --runtime")
	}
}
