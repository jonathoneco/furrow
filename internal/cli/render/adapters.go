// Package render implements the `furrow render` command group. It renders
// runtime-specific files from the runtime-agnostic Furrow definitions:
//   - commands/work.md.tmpl → commands/work.md (per runtime)
//   - .furrow/drivers/driver-{step}.yaml → .claude/agents/driver-{step}.md (Claude only)
//
// Rendering is idempotent: same inputs produce identical bytes.
// Without --write, all rendered output is emitted to stdout as a manifest.
package render

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"text/template"

	"gopkg.in/yaml.v3"
)

// Runtime identifies the adapter target for template rendering.
// D3 and D6 extend RenderCtx additively (new fields only).
type Runtime string

const (
	// RuntimeClaude targets Claude Code's subagent/Agent dispatch model.
	RuntimeClaude Runtime = "claude"
	// RuntimePi targets the Pi @tintinweb/pi-subagents extension model.
	RuntimePi Runtime = "pi"
)

// RenderCtx is the template execution context. Templates compare
// {{ if eq .Runtime "claude" }} against the underlying string value.
// The typed enum gives compile-time safety in Go callers while keeping
// template syntax simple.
type RenderCtx struct {
	Runtime    Runtime
	RowName    string
	ProjectDir string
}

// driverDef is the in-memory representation of a .furrow/drivers/driver-{step}.yaml.
type driverDef struct {
	Name           string   `yaml:"name"`
	Step           string   `yaml:"step"`
	ToolsAllowlist []string `yaml:"tools_allowlist"`
	Model          string   `yaml:"model"`
}

// RenderedFile is one item in the render manifest.
type RenderedFile struct {
	// Path is the project-relative output path.
	Path string
	// Content is the rendered bytes.
	Content []byte
}

// Handler implements `furrow render adapters`.
type Handler struct {
	stdout io.Writer
	stderr io.Writer
}

// New returns a Handler writing to stdout/stderr.
func New(stdout, stderr io.Writer) *Handler {
	return &Handler{stdout: stdout, stderr: stderr}
}

// Run dispatches `furrow render <subcommand> [args...]`.
func (h *Handler) Run(args []string) int {
	if len(args) == 0 {
		h.printHelp()
		return 0
	}
	switch args[0] {
	case "adapters":
		return h.runAdapters(args[1:])
	case "help", "-h", "--help":
		h.printHelp()
		return 0
	default:
		_, _ = fmt.Fprintf(h.stderr, "unknown render subcommand %q\n", args[0])
		return 1
	}
}

func (h *Handler) printHelp() {
	_, _ = fmt.Fprintln(h.stdout, `furrow render

Usage:
  furrow render adapters --runtime=<claude|pi> [--write]

Subcommands:
  adapters   Render runtime-specific files from runtime-agnostic definitions

Use "furrow render <subcommand> --help" for subcommand-specific help.`)
}

func (h *Handler) runAdapters(args []string) int {
	var runtime, projectDir string
	write := false

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case strings.HasPrefix(arg, "--runtime="):
			runtime = strings.TrimPrefix(arg, "--runtime=")
		case arg == "--runtime":
			if i+1 >= len(args) {
				_, _ = fmt.Fprintln(h.stderr, "missing value for --runtime")
				return 1
			}
			i++
			runtime = args[i]
		case strings.HasPrefix(arg, "--project-dir="):
			projectDir = strings.TrimPrefix(arg, "--project-dir=")
		case arg == "--project-dir":
			if i+1 >= len(args) {
				_, _ = fmt.Fprintln(h.stderr, "missing value for --project-dir")
				return 1
			}
			i++
			projectDir = args[i]
		case arg == "--write":
			write = true
		case arg == "--help", arg == "-h":
			h.printAdaptersHelp()
			return 0
		default:
			_, _ = fmt.Fprintf(h.stderr, "unknown flag %q\n", arg)
			return 1
		}
	}

	if runtime == "" {
		_, _ = fmt.Fprintln(h.stderr, "required flag --runtime is missing (claude|pi)")
		return 1
	}

	var rt Runtime
	switch runtime {
	case string(RuntimeClaude):
		rt = RuntimeClaude
	case string(RuntimePi):
		rt = RuntimePi
	default:
		_, _ = fmt.Fprintf(h.stderr, "unknown runtime %q (valid: claude, pi)\n", runtime)
		return 1
	}

	if projectDir == "" {
		// Default: find .furrow root relative to cwd.
		cwd, err := os.Getwd()
		if err != nil {
			_, _ = fmt.Fprintln(h.stderr, "cannot determine working directory: "+err.Error())
			return 1
		}
		projectDir = cwd
	}

	ctx := RenderCtx{
		Runtime:    rt,
		RowName:    "{{ROW_NAME}}",
		ProjectDir: projectDir,
	}

	files, err := RenderAdapters(ctx, projectDir)
	if err != nil {
		_, _ = fmt.Fprintln(h.stderr, "render error: "+err.Error())
		return 1
	}

	if write {
		for _, f := range files {
			outPath := filepath.Join(projectDir, f.Path)
			if err := os.MkdirAll(filepath.Dir(outPath), 0o755); err != nil {
				_, _ = fmt.Fprintf(h.stderr, "mkdir %s: %v\n", filepath.Dir(outPath), err)
				return 1
			}
			if err := os.WriteFile(outPath, f.Content, 0o644); err != nil {
				_, _ = fmt.Fprintf(h.stderr, "write %s: %v\n", outPath, err)
				return 1
			}
			_, _ = fmt.Fprintf(h.stdout, "wrote %s\n", f.Path)
		}
		return 0
	}

	// Stdout manifest: path → content blocks.
	for _, f := range files {
		_, _ = fmt.Fprintf(h.stdout, "=== %s ===\n%s\n", f.Path, f.Content)
	}
	return 0
}

func (h *Handler) printAdaptersHelp() {
	_, _ = fmt.Fprintln(h.stdout, `furrow render adapters

Renders runtime-specific files from runtime-agnostic Furrow definitions.

Usage:
  furrow render adapters --runtime=<claude|pi> [--write] [--project-dir=<dir>]

Flags:
  --runtime=<claude|pi>   Target adapter runtime (required)
  --write                 Write rendered files to disk (default: emit to stdout)
  --project-dir=<dir>     Project root directory (default: cwd)

Outputs (Claude):
  commands/work.md              Rendered operator skill
  .claude/agents/driver-{step}.md   Subagent definitions (×7)

Outputs (Pi):
  commands/work.md              Rendered operator skill (Pi block)`)
}

// RenderAdapters renders all runtime-specific files for the given ctx and
// returns them as a stable-ordered slice of RenderedFile. It does NOT write
// to disk; callers that need writing use --write via the CLI.
//
// Idempotent: same inputs → identical bytes.
func RenderAdapters(ctx RenderCtx, projectDir string) ([]RenderedFile, error) {
	var files []RenderedFile

	// 1. Render commands/work.md.tmpl → commands/work.md
	workMd, err := renderWorkTemplate(ctx, projectDir)
	if err != nil {
		return nil, fmt.Errorf("render work.md.tmpl: %w", err)
	}
	files = append(files, RenderedFile{Path: "commands/work.md", Content: workMd})

	// 2. Claude-specific: render driver YAMLs → .claude/agents/driver-{step}.md
	if ctx.Runtime == RuntimeClaude {
		agentFiles, err := renderClaudeAgents(ctx, projectDir)
		if err != nil {
			return nil, fmt.Errorf("render claude agents: %w", err)
		}
		files = append(files, agentFiles...)
	}

	// Sort for stable output order.
	sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
	return files, nil
}

// renderWorkTemplate reads commands/work.md.tmpl and executes it with ctx.
func renderWorkTemplate(ctx RenderCtx, projectDir string) ([]byte, error) {
	tmplPath := filepath.Join(projectDir, "commands", "work.md.tmpl")
	tmplBytes, err := os.ReadFile(tmplPath)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", tmplPath, err)
	}

	tmpl, err := template.New("work.md.tmpl").Parse(string(tmplBytes))
	if err != nil {
		return nil, fmt.Errorf("parse template: %w", err)
	}

	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, ctx); err != nil {
		return nil, fmt.Errorf("execute template: %w", err)
	}
	return buf.Bytes(), nil
}

// renderClaudeAgents reads each .furrow/drivers/driver-{step}.yaml and renders
// a .claude/agents/driver-{step}.md subagent definition. The output format is:
//
//	---
//	name: driver:{step}
//	description: Phase driver for the {step} step
//	tools: [...]
//	model: {model}
//	---
//	{contents of skills/{step}.md}
func renderClaudeAgents(ctx RenderCtx, projectDir string) ([]RenderedFile, error) {
	steps := []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}
	var files []RenderedFile

	for _, step := range steps {
		driverPath := filepath.Join(projectDir, ".furrow", "drivers", fmt.Sprintf("driver-%s.yaml", step))
		driverBytes, err := os.ReadFile(driverPath)
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", driverPath, err)
		}

		var def driverDef
		if err := yaml.Unmarshal(driverBytes, &def); err != nil {
			return nil, fmt.Errorf("parse %s: %w", driverPath, err)
		}

		skillPath := filepath.Join(projectDir, "skills", fmt.Sprintf("%s.md", step))
		skillBytes, err := os.ReadFile(skillPath)
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", skillPath, err)
		}

		// Build YAML frontmatter. Tools list is sorted for stable output.
		tools := make([]string, len(def.ToolsAllowlist))
		copy(tools, def.ToolsAllowlist)
		sort.Strings(tools)

		var toolLines []string
		for _, t := range tools {
			toolLines = append(toolLines, fmt.Sprintf("  - %q", t))
		}

		frontmatter := fmt.Sprintf(`---
name: %q
description: "Phase driver for the %s step — runs step ceremony, dispatches engine teams, assembles EOS-report"
tools:
%s
model: %q
---
`, def.Name, step, strings.Join(toolLines, "\n"), def.Model)

		content := []byte(frontmatter + string(skillBytes))
		outPath := fmt.Sprintf(".claude/agents/driver-%s.md", step)
		files = append(files, RenderedFile{Path: outPath, Content: content})
	}

	return files, nil
}
