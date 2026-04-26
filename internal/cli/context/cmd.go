// Package context provides the `furrow context` command group.
// This file (cmd.go) wires the CLI surface (for-step subcommand) using the
// same manual flag-parsing pattern as the rest of the internal/cli package.
//
// Strategy registration: each strategy file in the strategies/ sub-package
// self-registers via init(). The binary entry point (or app.go) must blank-
// import the strategies package to trigger those registrations:
//
//	import _ "github.com/jonathoneco/furrow/internal/cli/context/strategies"
package context

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// Handler is the top-level dispatcher for `furrow context`.
type Handler struct {
	stdout io.Writer
	stderr io.Writer
}

// New returns a Handler.
func New(stdout, stderr io.Writer) *Handler {
	return &Handler{stdout: stdout, stderr: stderr}
}

// Run dispatches `furrow context <subcommand> [args...]`.
// Exit codes: 0 success; 1 internal error; 2 usage; 3 blocker emitted.
func (h *Handler) Run(args []string) int {
	if len(args) == 0 {
		h.printHelp()
		return 0
	}
	switch args[0] {
	case "for-step":
		return h.runForStep(args[1:])
	case "help", "-h", "--help":
		h.printHelp()
		return 0
	default:
		_, _ = fmt.Fprintf(h.stderr, "unknown context subcommand %q\n", args[0])
		return 2
	}
}

func (h *Handler) printHelp() {
	_, _ = fmt.Fprintln(h.stdout, `furrow context

Usage:
  furrow context for-step <step> [--row <name>] [--target <t>] [--json] [--no-cache]

Subcommands:
  for-step  Assemble a context bundle for the given workflow step

Targets: operator | driver (default) | engine | specialist:<id>
Steps:   ideate | research | plan | spec | decompose | implement | review`)
}

// runForStep implements `furrow context for-step <step> [flags]`.
func (h *Handler) runForStep(args []string) int {
	// Parse flags.
	var positionals []string
	row := ""
	target := "driver"
	noCache := false

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--json":
			// --json is the default; accepted but no-op in strict mode.
		case arg == "--no-cache":
			noCache = true
		case arg == "--row":
			if i+1 >= len(args) {
				_, _ = fmt.Fprintln(h.stderr, "furrow context for-step: --row requires a value")
				return 2
			}
			i++
			row = args[i]
		case strings.HasPrefix(arg, "--row="):
			row = strings.TrimPrefix(arg, "--row=")
		case arg == "--target":
			if i+1 >= len(args) {
				_, _ = fmt.Fprintln(h.stderr, "furrow context for-step: --target requires a value")
				return 2
			}
			i++
			target = args[i]
		case strings.HasPrefix(arg, "--target="):
			target = strings.TrimPrefix(arg, "--target=")
		case strings.HasPrefix(arg, "--"):
			_, _ = fmt.Fprintf(h.stderr, "furrow context for-step: unknown flag %q\n", arg)
			return 2
		default:
			positionals = append(positionals, arg)
		}
	}

	if len(positionals) == 0 {
		_, _ = fmt.Fprintln(h.stderr, "furrow context for-step: step argument is required")
		return 2
	}
	step := positionals[0]

	// Validate target format.
	if !validTarget(target) {
		_, _ = fmt.Fprintf(h.stderr, "furrow context for-step: invalid --target %q (must be operator|driver|engine|specialist:<id>)\n", target)
		return 2
	}

	// Validate step.
	if !validStep(step) {
		_, _ = fmt.Fprintf(h.stderr, "furrow context for-step: invalid step %q (must be ideate|research|plan|spec|decompose|implement|review)\n", step)
		return 2
	}

	// Find furrow root.
	furrowRoot, err := findFurrowRoot()
	if err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow context for-step: %v\n", err)
		return 1
	}

	// Resolve row (default: focused row).
	if row == "" {
		row, err = readFocusedRow(furrowRoot)
		if err != nil {
			h.emitBlocker("context_input_missing", "no row specified and no focused row found: "+err.Error(), nil)
			return 3
		}
	}

	// Verify row exists.
	rowDir := filepath.Join(furrowRoot, ".furrow", "rows", row)
	if _, statErr := os.Stat(rowDir); os.IsNotExist(statErr) {
		h.emitBlocker("context_input_missing", fmt.Sprintf("row %q not found at %s", row, rowDir), map[string]any{"row": row})
		return 3
	}

	// Validate specialist brief if target is specialist:{id}.
	if strings.HasPrefix(target, "specialist:") {
		id := strings.TrimPrefix(target, "specialist:")
		briefPath := filepath.Join(furrowRoot, "specialists", id+".md")
		if _, err := os.Stat(briefPath); os.IsNotExist(err) {
			h.emitBlocker("context_input_missing",
				fmt.Sprintf("specialist brief not found: specialists/%s.md", id),
				map[string]any{"specialist_id": id, "expected_path": briefPath})
			return 3
		}
	}

	// Look up strategy.
	strategy, err := LookupStrategy(step)
	if err != nil {
		h.emitBlocker("context_strategy_unregistered",
			fmt.Sprintf("no strategy registered for step %q", step),
			map[string]any{"step": step})
		return 3
	}

	src := NewFileContextSource(furrowRoot, row, step, target)
	cache := NewCache(furrowRoot)

	// Enumerate input paths for cache key.
	inputPaths := enumerateInputPaths(furrowRoot, row)

	var cacheKey string
	if !noCache {
		cacheKey, err = Key(row, step, target, inputPaths)
		if err != nil {
			// Non-fatal: proceed without cache.
			cacheKey = ""
		}
	}

	// Check cache.
	if cacheKey != "" && !noCache {
		if cached, _ := cache.Load(cacheKey, row, inputPaths); cached != nil {
			return h.emitBundle(cached)
		}
	}

	// Assemble bundle.
	builder := NewBundleBuilder(row, step, target)

	// Walk the chain (defaults → artifacts → target-filter).
	chain := BuildChain()
	if err := WalkChain(chain, builder, src); err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow context for-step: chain: %v\n", err)
		return 1
	}

	// Apply strategy.
	if err := strategy.Apply(builder, src); err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow context for-step: strategy: %v\n", err)
		return 1
	}

	// Check for skills with missing layer tag.
	// We need to peek at builder skills before Build() consumes it.
	// Re-list skills to check for MISSING layer.
	if exitCode := h.checkSkillLayers(src, builder); exitCode != 0 {
		return exitCode
	}

	// Extract decisions from summary.md.
	summaryPath := filepath.Join(furrowRoot, ".furrow", "rows", row, "summary.md")
	if summaryData, readErr := os.ReadFile(summaryPath); readErr == nil {
		decisions := ExtractDecisions(string(summaryData), step)
		for _, d := range decisions {
			builder.AddDecision(d)
		}
	}

	// Store metadata about cache inputs.
	builder.SetMetadata("cache_inputs", inputPaths)

	bundle, err := builder.Build()
	if err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow context for-step: build: %v\n", err)
		return 1
	}

	// Store in cache (non-fatal on error).
	if cacheKey != "" && !noCache {
		_ = cache.Store(cacheKey, row, &bundle)
	}

	return h.emitBundle(&bundle)
}

func (h *Handler) emitBundle(b *Bundle) int {
	enc := json.NewEncoder(h.stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(b); err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow context for-step: encode: %v\n", err)
		return 1
	}
	return 0
}

// checkSkillLayers re-lists skills and checks for MISSING layer tag.
// Emits a blocker envelope if any skill lacks a layer tag.
func (h *Handler) checkSkillLayers(src ContextSource, _ *BundleBuilder) int {
	skills, err := src.ListSkills()
	if err != nil {
		return 0 // non-fatal
	}
	for _, sk := range skills {
		if sk.Layer == "MISSING" {
			h.emitBlocker("skill_layer_unset",
				fmt.Sprintf("skill %q is missing a layer: front-matter tag", sk.Path),
				map[string]any{
					"skill_path": sk.Path,
					"note":       "D3 will register this blocker code in schemas/blocker-taxonomy.yaml (W5); verdict is pre-emptively enforced here",
				})
			return 3
		}
	}
	return 0
}

// emitBlocker writes a blocker envelope to stdout (per spec: exit 3, envelope on stdout, code on stderr).
func (h *Handler) emitBlocker(code, message string, context map[string]any) {
	_, _ = fmt.Fprintf(h.stderr, "blocker: %s\n", code)
	enc := json.NewEncoder(h.stdout)
	enc.SetIndent("", "  ")
	_ = enc.Encode(map[string]any{
		"blocker": map[string]any{
			"code":              code,
			"message":           message,
			"context":           context,
			"confirmation_path": ".furrow/blockers/" + code + ".json",
		},
	})
}

// findFurrowRoot walks up from cwd looking for .furrow/.
func findFurrowRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	current := cwd
	for {
		candidate := filepath.Join(current, ".furrow")
		if info, err := os.Stat(candidate); err == nil && info.IsDir() {
			return current, nil
		}
		next := filepath.Dir(current)
		if next == current {
			return "", fmt.Errorf(".furrow root not found")
		}
		current = next
	}
}

// readFocusedRow reads .furrow/focus to get the currently focused row name.
func readFocusedRow(root string) (string, error) {
	focusPath := filepath.Join(root, ".furrow", "focus")
	data, err := os.ReadFile(focusPath)
	if err != nil {
		return "", fmt.Errorf("read focus file: %w", err)
	}
	name := strings.TrimSpace(string(data))
	if name == "" {
		return "", fmt.Errorf("focus file is empty")
	}
	return name, nil
}

// enumerateInputPaths returns the set of files that contribute to the bundle.
func enumerateInputPaths(root, row string) []string {
	rowDir := filepath.Join(root, ".furrow", "rows", row)
	var paths []string

	// Core row files.
	for _, rel := range []string{"state.json", "summary.md", "learnings.jsonl", "plan.json", "research.md"} {
		paths = append(paths, filepath.Join(rowDir, rel))
	}

	// Specs directory.
	specsDir := filepath.Join(rowDir, "specs")
	if entries, err := os.ReadDir(specsDir); err == nil {
		for _, e := range entries {
			if !e.IsDir() {
				paths = append(paths, filepath.Join(specsDir, e.Name()))
			}
		}
	}

	// Skills directory.
	skillsDir := filepath.Join(root, "skills")
	if entries, err := os.ReadDir(skillsDir); err == nil {
		for _, e := range entries {
			if !e.IsDir() && strings.HasSuffix(e.Name(), ".md") {
				paths = append(paths, filepath.Join(skillsDir, e.Name()))
			}
		}
	}

	return paths
}

// validTarget returns true if target is a valid --target value.
func validTarget(t string) bool {
	switch t {
	case "operator", "driver", "engine":
		return true
	}
	if strings.HasPrefix(t, "specialist:") {
		id := strings.TrimPrefix(t, "specialist:")
		return id != ""
	}
	return false
}

// validStep returns true if step is one of the 7 workflow steps.
func validStep(s string) bool {
	switch s {
	case "ideate", "research", "plan", "spec", "decompose", "implement", "review":
		return true
	}
	return false
}
