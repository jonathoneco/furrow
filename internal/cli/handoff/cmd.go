package handoff

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/jonathoneco/furrow/internal/cli/project"
)

// Handler is the top-level dispatcher for the `furrow handoff` command group.
// It is constructed via New and exposes a single Run(args) int entry point,
// mirroring the shape of other command groups in the CLI.
type Handler struct {
	stdout io.Writer
	stderr io.Writer
}

// New returns a Handler that writes output to stdout/stderr.
func New(stdout, stderr io.Writer) *Handler {
	return &Handler{stdout: stdout, stderr: stderr}
}

// Run dispatches `furrow handoff <subcommand> [args...]`.
// Returns an exit code: 0 success, 1 usage error, 2 validation failure.
func (h *Handler) Run(args []string) int {
	if len(args) == 0 {
		h.printHelp()
		return 0
	}
	switch args[0] {
	case "render":
		return h.runRender(args[1:])
	case "validate":
		return h.runValidate(args[1:])
	case "help", "-h", "--help":
		h.printHelp()
		return 0
	default:
		_, _ = fmt.Fprintf(h.stderr, "unknown handoff subcommand %q\n", args[0])
		return 1
	}
}

func (h *Handler) printHelp() {
	_, _ = fmt.Fprintln(h.stdout, `furrow handoff

Usage:
  furrow handoff render --target driver:{step}|engine:{id} --row <row> --step <step> [--write] [--json]
  furrow handoff validate <path> [--json]

Subcommands:
  render    Render a handoff artifact to markdown (or JSON with --json)
  validate  Validate a handoff artifact file against its schema`)
}

func (h *Handler) printRenderHelp() {
	_, _ = fmt.Fprintln(h.stdout, `furrow handoff render

Usage:
  furrow handoff render --target driver:{step} --row <row> --step <step> [--write] [--json]
  furrow handoff render --target engine:{id} [--row <row> --step <step> --write] [--json] < engine-handoff.json

Driver targets synthesize the handoff from flags.
Engine targets read an EngineHandoff JSON document from stdin before rendering.

Flags:
  --target         driver:{step} | engine:{specialist-id} | engine:freeform
  --row            Row name; required for driver targets and engine --write
  --step           Workflow step; required for driver targets and engine --write
  --write          Write rendered markdown under .furrow/rows/{row}/handoffs/
  --json           Emit JSON instead of markdown
  --objective      Optional driver objective override
  --grounding      Optional driver grounding override
  --return-format  Optional driver return format override`)
}

// runRender implements `furrow handoff render`.
//
// Flags:
//
//	--target  driver:{step} | engine:{specialist-id} | engine:freeform (required)
//	--row     row name (required for driver targets)
//	--step    step name (required for driver targets)
//	--write   write to .furrow/rows/{row}/handoffs/{step}-to-{target-slug}.md
//	--json    emit JSON instead of markdown
func (h *Handler) runRender(args []string) int {
	if len(args) > 0 {
		switch args[0] {
		case "help", "-h", "--help":
			h.printRenderHelp()
			return 0
		}
	}
	flags, remaining, err := parseRenderFlags(args)
	if err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow handoff render: %v\n", err)
		return 1
	}
	if len(remaining) > 0 {
		_, _ = fmt.Fprintf(h.stderr, "furrow handoff render: unexpected positional argument %q\n", remaining[0])
		return 1
	}

	target := flags["target"]
	if target == "" {
		_, _ = fmt.Fprintln(h.stderr, "furrow handoff render: --target is required")
		return 1
	}

	if strings.HasPrefix(target, "driver:") {
		return h.runRenderDriver(flags)
	}
	if strings.HasPrefix(target, "engine:") {
		return h.runRenderEngine(flags)
	}
	_, _ = fmt.Fprintf(h.stderr, "furrow handoff render: --target must be driver:{step} or engine:{id}, got %q\n", target)
	return 1
}

func (h *Handler) runRenderDriver(flags map[string]string) int {
	target := flags["target"]
	row := flags["row"]
	step := flags["step"]
	doWrite := flags["write"] == "true"
	doJSON := flags["json"] == "true"

	if row == "" {
		_, _ = fmt.Fprintln(h.stderr, "furrow handoff render: --row is required for driver targets")
		return 1
	}
	if step == "" {
		_, _ = fmt.Fprintln(h.stderr, "furrow handoff render: --step is required for driver targets")
		return 1
	}

	objective := flags["objective"]
	if objective == "" {
		objective = fmt.Sprintf("Driver handoff for step %s of row %s", step, row)
	}

	grounding := flags["grounding"]
	if grounding == "" {
		grounding = fmt.Sprintf(".furrow/rows/%s/context/bundle.json", row)
	}

	returnFormat := flags["return-format"]
	if returnFormat == "" {
		returnFormat = "phase-eos-report"
	}

	hd := DriverHandoff{
		Target:       target,
		Step:         step,
		Row:          row,
		Objective:    objective,
		Grounding:    grounding,
		Constraints:  []string{},
		ReturnFormat: returnFormat,
	}

	if doJSON {
		enc := json.NewEncoder(h.stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(hd)
		return 0
	}

	rendered, err := RenderDriver(hd)
	if err != nil {
		env := &Envelope{
			Code:     CodeHandoffSchemaInvalid,
			Category: "handoff",
			Severity: "error",
			Message:  fmt.Sprintf("render driver: %v", err),
		}
		return h.failEnvelope(env, doJSON)
	}

	if doWrite {
		root, rerr := project.FindFurrowRoot()
		if rerr != nil {
			_, _ = fmt.Fprintf(h.stderr, "furrow handoff render: %v\n", rerr)
			return 1
		}
		targetSlug := strings.ReplaceAll(target, ":", "-")
		outPath := filepath.Join(root, ".furrow", "rows", row, "handoffs",
			fmt.Sprintf("%s-to-%s.md", step, targetSlug))
		if werr := writeFileIdempotent(outPath, []byte(rendered)); werr != nil {
			_, _ = fmt.Fprintf(h.stderr, "furrow handoff render: write: %v\n", werr)
			return 1
		}
		_, _ = fmt.Fprintf(h.stdout, "wrote %s\n", outPath)
		return 0
	}

	_, _ = fmt.Fprint(h.stdout, rendered)
	return 0
}

func (h *Handler) runRenderEngine(flags map[string]string) int {
	target := flags["target"]
	doWrite := flags["write"] == "true"
	doJSON := flags["json"] == "true"

	// For engine targets, read EngineHandoff JSON from stdin.
	data, err := io.ReadAll(os.Stdin)
	if err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow handoff render: read stdin: %v\n", err)
		return 1
	}

	// Validate before rendering.
	env, err := ValidateEngineJSON(data, "<stdin>")
	if err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow handoff render: %v\n", err)
		return 1
	}
	if env != nil {
		return h.failEnvelope(env, doJSON)
	}

	var he EngineHandoff
	if err := json.Unmarshal(data, &he); err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow handoff render: unmarshal: %v\n", err)
		return 1
	}

	if doJSON {
		enc := json.NewEncoder(h.stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(he)
		return 0
	}

	rendered, rerr := RenderEngine(he)
	if rerr != nil {
		env := &Envelope{
			Code:     CodeHandoffSchemaInvalid,
			Category: "handoff",
			Severity: "error",
			Message:  fmt.Sprintf("render engine: %v", rerr),
		}
		return h.failEnvelope(env, doJSON)
	}

	if doWrite {
		row := flags["row"]
		step := flags["step"]
		if row == "" || step == "" {
			_, _ = fmt.Fprintln(h.stderr, "furrow handoff render: --row and --step required with --write for engine targets")
			return 1
		}
		root, findErr := project.FindFurrowRoot()
		if findErr != nil {
			_, _ = fmt.Fprintf(h.stderr, "furrow handoff render: %v\n", findErr)
			return 1
		}
		targetSlug := strings.ReplaceAll(target, ":", "-")
		outPath := filepath.Join(root, ".furrow", "rows", row, "handoffs",
			fmt.Sprintf("%s-to-%s.md", step, targetSlug))
		if werr := writeFileIdempotent(outPath, []byte(rendered)); werr != nil {
			_, _ = fmt.Fprintf(h.stderr, "furrow handoff render: write: %v\n", werr)
			return 1
		}
		_, _ = fmt.Fprintf(h.stdout, "wrote %s\n", outPath)
		return 0
	}

	_, _ = fmt.Fprint(h.stdout, rendered)
	return 0
}

// runValidate implements `furrow handoff validate <path> [--json]`.
func (h *Handler) runValidate(args []string) int {
	jsonOut := false
	var path string
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--json":
			jsonOut = true
		default:
			if !strings.HasPrefix(args[i], "--") {
				path = args[i]
			} else {
				_, _ = fmt.Fprintf(h.stderr, "furrow handoff validate: unknown flag %q\n", args[i])
				return 1
			}
		}
	}

	if path == "" {
		_, _ = fmt.Fprintln(h.stderr, "furrow handoff validate: path argument is required")
		return 1
	}

	env, err := ValidateFile(path)
	if err != nil {
		_, _ = fmt.Fprintf(h.stderr, "furrow handoff validate: %v\n", err)
		return 1
	}
	if env != nil {
		return h.failEnvelope(env, jsonOut)
	}

	if jsonOut {
		enc := json.NewEncoder(h.stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(map[string]any{"ok": true, "verdict": "valid"})
		return 0
	}
	_, _ = fmt.Fprintln(h.stdout, "handoff is valid")
	return 0
}

func (h *Handler) failEnvelope(env *Envelope, jsonOut bool) int {
	if jsonOut {
		enc := json.NewEncoder(h.stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(map[string]any{
			"ok":      false,
			"verdict": "invalid",
			"error":   env,
		})
		return 2
	}
	_, _ = fmt.Fprintf(h.stderr, "[%s] %s\n", env.Code, env.Message)
	if env.RemediationHint != "" {
		_, _ = fmt.Fprintf(h.stderr, "  hint: %s\n", env.RemediationHint)
	}
	return 2
}

// parseRenderFlags parses --key value flags for the render subcommand.
// Returns a map of flag values, positional args, and any error.
func parseRenderFlags(args []string) (map[string]string, []string, error) {
	flags := map[string]string{}
	var positionals []string

	valueFlags := map[string]bool{
		"target": true, "row": true, "step": true,
		"objective": true, "grounding": true, "return-format": true,
	}
	boolFlags := map[string]bool{"write": true, "json": true}

	for i := 0; i < len(args); i++ {
		arg := args[i]
		if !strings.HasPrefix(arg, "--") {
			positionals = append(positionals, arg)
			continue
		}
		name := strings.TrimPrefix(arg, "--")
		if strings.Contains(name, "=") {
			parts := strings.SplitN(name, "=", 2)
			if valueFlags[parts[0]] {
				flags[parts[0]] = parts[1]
				continue
			}
			if boolFlags[parts[0]] {
				flags[parts[0]] = "true"
				continue
			}
			return nil, nil, fmt.Errorf("unknown flag --%s", parts[0])
		}
		if valueFlags[name] {
			if i+1 >= len(args) {
				return nil, nil, fmt.Errorf("missing value for --%s", name)
			}
			flags[name] = args[i+1]
			i++
			continue
		}
		if boolFlags[name] {
			flags[name] = "true"
			continue
		}
		return nil, nil, fmt.Errorf("unknown flag %s", arg)
	}
	return flags, positionals, nil
}

// writeFileIdempotent writes data to path, creating parent directories as needed.
// Idempotent: if the file already contains the exact same bytes, it is not rewritten.
func writeFileIdempotent(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("mkdir: %w", err)
	}
	// Check if content is identical (idempotency).
	existing, err := os.ReadFile(path)
	if err == nil && string(existing) == string(data) {
		return nil // already identical
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".handoff-*.tmp")
	if err != nil {
		return fmt.Errorf("create temp: %w", err)
	}
	tmpPath := tmp.Name()
	defer func() { _ = os.Remove(tmpPath) }()
	if _, werr := tmp.Write(data); werr != nil {
		_ = tmp.Close()
		return fmt.Errorf("write temp: %w", werr)
	}
	if cerr := tmp.Close(); cerr != nil {
		return fmt.Errorf("close temp: %w", cerr)
	}
	return os.Rename(tmpPath, path)
}
