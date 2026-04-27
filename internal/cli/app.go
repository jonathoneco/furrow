package cli

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
	"github.com/jonathoneco/furrow/internal/cli/handoff"
	"github.com/jonathoneco/furrow/internal/cli/hook"
	"github.com/jonathoneco/furrow/internal/cli/render"

	// Blank-import triggers init() registration of all 7 step strategies.
	_ "github.com/jonathoneco/furrow/internal/cli/context/strategies"
)

const contractVersion = "v1alpha1"

type App struct {
	stdout io.Writer
	stderr io.Writer
	stdin  io.Reader
}

type envelope struct {
	OK      bool     `json:"ok"`
	Command string   `json:"command"`
	Version string   `json:"version"`
	Data    any      `json:"data,omitempty"`
	Error   *errBody `json:"error,omitempty"`
}

type errBody struct {
	Code    string         `json:"code"`
	Message string         `json:"message"`
	Details map[string]any `json:"details,omitempty"`
}

type cliError struct {
	exit    int
	code    string
	message string
	details map[string]any
}

func (e *cliError) Error() string { return e.message }

func New(stdout, stderr io.Writer) *App {
	return &App{stdout: stdout, stderr: stderr, stdin: os.Stdin}
}

// NewWithStdin creates an App with an explicit stdin (used in tests).
func NewWithStdin(stdout, stderr io.Writer, stdin io.Reader) *App {
	return &App{stdout: stdout, stderr: stderr, stdin: stdin}
}

func (a *App) Run(args []string) int {
	if len(args) == 0 {
		a.printRootHelp()
		return 0
	}

	switch args[0] {
	case "help", "-h", "--help":
		a.printRootHelp()
		return 0
	case "version":
		_, _ = fmt.Fprintln(a.stdout, contractVersion)
		return 0
	case "row":
		return a.runRow(args[1:])
	case "gate":
		return a.runStubGroup("furrow gate", args[1:], []string{"run", "evaluate", "status", "list"})
	case "review":
		return a.runReview(args[1:])
	case "almanac":
		return a.runAlmanac(args[1:])
	case "seeds":
		return a.runStubGroup("furrow seeds", args[1:], []string{"create", "update", "show", "list", "close"})
	case "validate":
		return a.runValidate(args[1:])
	case "context":
		return a.runContext(args[1:])
	case "handoff":
		return a.runHandoff(args[1:])
	case "render":
		return a.runRender(args[1:])
	case "hook":
		return a.runHook(args[1:])
	case "merge":
		return a.runStubGroup("furrow merge", args[1:], []string{"plan", "run", "validate"})
	case "doctor":
		return a.runDoctor(args[1:])
	case "init":
		return a.runInit(args[1:])
	default:
		return a.fail("furrow", &cliError{exit: 1, code: "usage", message: fmt.Sprintf("unknown command %q", args[0])}, false)
	}
}

func (a *App) runRow(args []string) int {
	if len(args) == 0 {
		a.printRowHelp()
		return 0
	}

	switch args[0] {
	case "status":
		return a.runRowStatus(args[1:])
	case "list":
		return a.runRowList(args[1:])
	case "transition":
		return a.runRowTransition(args[1:])
	case "complete":
		return a.runRowComplete(args[1:])
	case "archive":
		return a.runRowArchive(args[1:])
	case "repair-deliverables":
		return a.runRowRepairDeliverables(args[1:])
	case "init":
		return a.runRowInit(args[1:])
	case "focus":
		return a.runRowFocus(args[1:])
	case "scaffold":
		return a.runRowScaffold(args[1:])
	case "checkpoint", "summary", "validate":
		return a.runStubLeaf("furrow row "+args[0], args[1:])
	case "help", "-h", "--help":
		a.printRowHelp()
		return 0
	default:
		return a.fail("furrow row", &cliError{exit: 1, code: "usage", message: fmt.Sprintf("unknown row command %q", args[0])}, false)
	}
}

func (a *App) runAlmanac(args []string) int {
	if len(args) == 0 {
		_, _ = fmt.Fprintf(a.stdout, "furrow almanac\n\nAvailable subcommands: %s\n", strings.Join([]string{"validate", "todos", "roadmap", "rationale"}, ", "))
		return 0
	}

	switch args[0] {
	case "validate":
		return a.runAlmanacValidate(args[1:])
	case "help", "-h", "--help":
		_, _ = fmt.Fprintf(a.stdout, "furrow almanac\n\nAvailable subcommands: %s\n", strings.Join([]string{"validate", "todos", "roadmap", "rationale"}, ", "))
		return 0
	default:
		return a.runStubLeaf("furrow almanac "+args[0], args[1:])
	}
}

func (a *App) runInit(args []string) int {
	_, flags, err := parseArgs(args, map[string]bool{"host": true}, nil)
	if err != nil {
		return a.fail("furrow init", err, false)
	}

	host := flags.values["host"]
	if host == "" {
		host = "auto"
	}

	details := map[string]any{
		"host": host,
		"note": "init contract reserved; implementation should eventually own repo bootstrap and migration",
	}
	return a.fail("furrow init", &cliError{exit: 4, code: "not_implemented", message: "init is not implemented in the Go CLI draft yet", details: details}, flags.json)
}

func (a *App) runContext(args []string) int {
	h := ctx.New(a.stdout, a.stderr)
	return h.Run(args)
}

func (a *App) runHandoff(args []string) int {
	h := handoff.New(a.stdout, a.stderr)
	return h.Run(args)
}

func (a *App) runRender(args []string) int {
	h := render.New(a.stdout, a.stderr)
	return h.Run(args)
}

func (a *App) runStubGroup(command string, args []string, children []string) int {
	if len(args) == 0 {
		_, _ = fmt.Fprintf(a.stdout, "%s\n\nAvailable subcommands: %s\n", command, strings.Join(children, ", "))
		return 0
	}
	return a.runStubLeaf(command+" "+args[0], args[1:])
}

func (a *App) runStubLeaf(command string, args []string) int {
	_, flags, err := parseArgs(args, map[string]bool{"host": true, "step": true}, nil)
	if err != nil {
		return a.fail(command, err, false)
	}
	return a.fail(command, &cliError{exit: 4, code: "not_implemented", message: command + " is not implemented in the Go CLI draft yet"}, flags.json)
}

// runHook dispatches `furrow hook <subcommand>` — runtime adapter hooks.
//
// D3 ships: layer-guard (PreToolUse boundary enforcement).
// D6 ships: presentation-check (Stop hook advisory scan).
func (a *App) runHook(args []string) int {
	if len(args) == 0 {
		_, _ = fmt.Fprintln(a.stdout, "furrow hook\n\nAvailable subcommands: layer-guard, presentation-check")
		return 0
	}
	switch args[0] {
	case "layer-guard":
		policyPath := filepath.Join(".furrow", "layer-policy.yaml")
		// Allow override via env for testing.
		if override := os.Getenv("FURROW_LAYER_POLICY_PATH"); override != "" {
			policyPath = override
		}
		return hook.RunLayerGuard(context.Background(), policyPath, a.stdin, a.stdout)
	case "presentation-check":
		return hook.RunPresentationCheck(context.Background(), a.stdin, a.stdout)
	case "help", "-h", "--help":
		_, _ = fmt.Fprintln(a.stdout, "furrow hook\n\nAvailable subcommands: layer-guard, presentation-check")
		return 0
	default:
		return a.fail("furrow hook", &cliError{
			exit:    1,
			code:    "usage",
			message: fmt.Sprintf("unknown hook subcommand %q", args[0]),
		}, false)
	}
}

func (a *App) okJSON(command string, data any) int {
	return a.writeJSON(envelope{OK: true, Command: command, Version: contractVersion, Data: data}, 0)
}

func (a *App) fail(command string, err error, jsonOut bool) int {
	var cliErr *cliError
	if !errors.As(err, &cliErr) {
		cliErr = &cliError{exit: 4, code: "error", message: err.Error()}
	}
	if jsonOut {
		return a.writeJSON(envelope{
			OK:      false,
			Command: command,
			Version: contractVersion,
			Error: &errBody{
				Code:    cliErr.code,
				Message: cliErr.message,
				Details: cliErr.details,
			},
		}, cliErr.exit)
	}
	_, _ = fmt.Fprintln(a.stderr, cliErr.message)
	return cliErr.exit
}

func (a *App) writeJSON(v envelope, exit int) int {
	enc := json.NewEncoder(a.stdout)
	enc.SetIndent("", "  ")
	_ = enc.Encode(v)
	return exit
}

func (a *App) printRootHelp() {
	_, _ = fmt.Fprintln(a.stdout, `furrow — Go CLI surface draft

Usage:
  furrow <command> [args...]

Commands:
  row       Row lifecycle contract surface
  gate      Gate orchestration contract surface
  review    Review orchestration contract surface
  almanac   Planning and knowledge contract surface
  seeds     Seed/task primitive contract surface
  validate  Schema and policy validation (definition, layer-policy, skill-layers, driver-definitions)
  context   Context bundle assembly (for-step)
  handoff   Handoff render and validate contract surface
  render    Render runtime-specific files from definitions
  hook      Runtime adapter hooks (layer-guard, presentation-check)
  merge     Merge pipeline contract surface
  doctor    Environment and adapter readiness checks
  init      Repo bootstrap and migration entrypoint
  version   Print CLI contract version
  help      Show this help

Use "furrow <command> help" for command-specific help.`)
}

func (a *App) printRowHelp() {
	_, _ = fmt.Fprintln(a.stdout, `furrow row

Usage:
  furrow row list [--active|--archived|--all] [--json]
  furrow row status [row-name] [--json]
  furrow row transition <row-name> --step <step> [--json]
  furrow row complete <row-name> [--json]
  furrow row archive <row-name> [--json]
  furrow row init <row-name> [--title <title>] [--mode <code|research>] [--gate-policy <policy>] [--source-todo <id>] [--seed-id <id>] [--json]
  furrow row focus [row-name|--clear] [--json]
  furrow row scaffold <row-name> [--current-step] [--json]
  furrow row checkpoint ...
  furrow row summary ...
  furrow row validate ...`)
}

func (a *App) printReviewHelp() {
	_, _ = fmt.Fprintln(a.stdout, `furrow review

Usage:
  furrow review status [row-name] [--json]
  furrow review validate [row-name] [--json]
  furrow review run ...
  furrow review cross-model ...`)
}

type parsedFlags struct {
	json   bool
	values map[string]string
	bools  map[string]bool
}

func parseArgs(args []string, valueFlags map[string]bool, boolFlags map[string]bool) ([]string, parsedFlags, error) {
	out := parsedFlags{values: map[string]string{}, bools: map[string]bool{}}
	positionals := make([]string, 0, len(args))

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--json":
			out.json = true
		case strings.HasPrefix(arg, "--"):
			name := strings.TrimPrefix(arg, "--")
			if strings.Contains(name, "=") {
				parts := strings.SplitN(name, "=", 2)
				if valueFlags[parts[0]] {
					out.values[parts[0]] = parts[1]
					continue
				}
				return nil, out, &cliError{exit: 1, code: "usage", message: fmt.Sprintf("unknown flag --%s", parts[0])}
			}
			if valueFlags[name] {
				if i+1 >= len(args) {
					return nil, out, &cliError{exit: 1, code: "usage", message: fmt.Sprintf("missing value for --%s", name)}
				}
				out.values[name] = args[i+1]
				i++
				continue
			}
			if boolFlags[name] {
				out.bools[name] = true
				continue
			}
			return nil, out, &cliError{exit: 1, code: "usage", message: fmt.Sprintf("unknown flag %s", arg)}
		default:
			positionals = append(positionals, arg)
		}
	}

	return positionals, out, nil
}
