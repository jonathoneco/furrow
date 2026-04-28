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

	"github.com/jonathoneco/furrow/internal/cli/project"
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
  furrow context for-step <step> [--row <name>] [--target <t>] [--json]

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

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--json":
			// --json is the default; accepted but no-op in strict mode.
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
	furrowRoot, err := project.FindFurrowRoot()
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

	// Assemble bundle.
	builder := NewBundleBuilder(row, step, target)

	// Walk the chain: defaults → artifacts → strategy → target-filter.
	// Spec-required order: strategy.Apply must run AFTER artifacts are loaded
	// and BEFORE TargetFilterNode so skills added by the strategy are filtered.
	chain := BuildChainWithStrategy(strategy)
	if err := WalkChain(chain, builder, src); err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow context for-step: chain: %v\n", err)
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

	bundle, err := builder.Build()
	if err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow context for-step: build: %v\n", err)
		return 1
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

// readFocusedRow reads .furrow/.focused to get the currently focused row
// name. The canonical filename is `.focused` (with the leading dot) — see
// internal/cli/util.go readFocusedRowName, internal/cli/row_workflow.go,
// and adapters/pi/furrow.ts isCanonicalStatePath. This helper previously
// looked at `.furrow/focus` (no dot) and silently failed on every focused
// invocation; the bug was caught during dogfood walkthrough 2026-04-28.
func readFocusedRow(root string) (string, error) {
	focusPath := filepath.Join(root, ".furrow", ".focused")
	data, err := os.ReadFile(focusPath)
	if err != nil {
		return "", fmt.Errorf("read focused-row file: %w", err)
	}
	name := strings.TrimSpace(string(data))
	if name == "" {
		return "", fmt.Errorf(".focused file is empty")
	}
	return name, nil
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
