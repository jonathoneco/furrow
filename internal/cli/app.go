package cli

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const contractVersion = "v1alpha1"

type App struct {
	stdout io.Writer
	stderr io.Writer
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
	return &App{stdout: stdout, stderr: stderr}
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
		return a.runStubGroup("furrow review", args[1:], []string{"run", "cross-model", "status", "validate"})
	case "almanac":
		return a.runStubGroup("furrow almanac", args[1:], []string{"validate", "todos", "roadmap", "rationale"})
	case "seeds":
		return a.runStubGroup("furrow seeds", args[1:], []string{"create", "update", "show", "list", "close"})
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
	case "transition":
		return a.runRowTransition(args[1:])
	case "init", "checkpoint", "archive", "summary", "validate", "list":
		return a.runStubLeaf("furrow row "+args[0], args[1:])
	case "help", "-h", "--help":
		a.printRowHelp()
		return 0
	default:
		return a.fail("furrow row", &cliError{exit: 1, code: "usage", message: fmt.Sprintf("unknown row command %q", args[0])}, false)
	}
}

func (a *App) runRowStatus(args []string) int {
	positionals, flags, err := parseArgs(args, map[string]bool{})
	if err != nil {
		return a.fail("furrow row status", err, false)
	}
	if len(positionals) > 1 {
		return a.fail("furrow row status", &cliError{exit: 1, code: "usage", message: "usage: furrow row status [row-name] [--json]"}, flags.json)
	}

	root, err2 := findFurrowRoot()
	if err2 != nil {
		return a.fail("furrow row status", &cliError{exit: 5, code: "not_found", message: ".furrow root not found"}, flags.json)
	}

	rowName := ""
	if len(positionals) == 1 {
		rowName = positionals[0]
	} else {
		rowName, err2 = readFocusedRow(root)
		if err2 != nil {
			return a.fail("furrow row status", &cliError{exit: 5, code: "not_found", message: err2.Error()}, flags.json)
		}
	}

	statePath := filepath.Join(root, ".furrow", "rows", rowName, "state.json")
	payload, err2 := os.ReadFile(statePath)
	if err2 != nil {
		return a.fail("furrow row status", &cliError{exit: 5, code: "not_found", message: fmt.Sprintf("state file not found for row %q", rowName)}, flags.json)
	}

	var state map[string]any
	if err := json.Unmarshal(payload, &state); err != nil {
		return a.fail("furrow row status", &cliError{exit: 3, code: "validation_failed", message: fmt.Sprintf("invalid JSON in %s", statePath)}, flags.json)
	}

	data := map[string]any{
		"row": state,
		"paths": map[string]any{
			"root":        root,
			"state":       statePath,
			"row_dir":     filepath.Dir(statePath),
			"focused_row": rowName,
		},
	}

	if flags.json {
		return a.okJSON("furrow row status", data)
	}

	_, _ = fmt.Fprintf(a.stdout, "row: %s\nstep: %v\nstatus: %v\nstate: %s\n", rowName, state["step"], state["step_status"], statePath)
	return 0
}

func (a *App) runRowTransition(args []string) int {
	positionals, flags, err := parseArgs(args, map[string]bool{"step": true})
	if err != nil {
		return a.fail("furrow row transition", err, false)
	}
	if len(positionals) != 1 {
		return a.fail("furrow row transition", &cliError{exit: 1, code: "usage", message: "usage: furrow row transition <row-name> --step <step> [--json]"}, flags.json)
	}
	step := flags.values["step"]
	if step == "" {
		return a.fail("furrow row transition", &cliError{exit: 1, code: "usage", message: "missing required flag --step"}, flags.json)
	}

	data := map[string]any{
		"row":            positionals[0],
		"requested_step": step,
		"note":           "backend contract draft only; transition execution not implemented yet",
	}
	return a.fail("furrow row transition", &cliError{exit: 4, code: "not_implemented", message: "row transition is not implemented in the Go CLI draft yet", details: data}, flags.json)
}

func (a *App) runDoctor(args []string) int {
	_, flags, err := parseArgs(args, map[string]bool{"host": true})
	if err != nil {
		return a.fail("furrow doctor", err, false)
	}

	host := flags.values["host"]
	if host == "" {
		host = "auto"
	}

	root, rootErr := findFurrowRoot()
	cwd, _ := os.Getwd()
	data := map[string]any{
		"host":       host,
		"cwd":        cwd,
		"furrowRoot": root,
		"checks": []map[string]any{
			{
				"name":   "furrow_root_present",
				"status": ternary(rootErr == nil, "pass", "fail"),
			},
		},
	}

	if flags.json {
		if rootErr != nil {
			return a.fail("furrow doctor", &cliError{exit: 5, code: "not_found", message: ".furrow root not found", details: data}, true)
		}
		return a.okJSON("furrow doctor", data)
	}

	if rootErr != nil {
		_, _ = fmt.Fprintln(a.stderr, "furrow doctor: .furrow root not found")
		return 5
	}
	_, _ = fmt.Fprintf(a.stdout, "furrow root: %s\nhost: %s\nstatus: draft-surface\n", root, host)
	return 0
}

func (a *App) runInit(args []string) int {
	_, flags, err := parseArgs(args, map[string]bool{"host": true})
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

func (a *App) runStubGroup(command string, args []string, children []string) int {
	if len(args) == 0 {
		_, _ = fmt.Fprintf(a.stdout, "%s\n\nAvailable subcommands: %s\n", command, strings.Join(children, ", "))
		return 0
	}
	return a.runStubLeaf(command+" "+args[0], args[1:])
}

func (a *App) runStubLeaf(command string, args []string) int {
	_, flags, err := parseArgs(args, map[string]bool{"host": true, "step": true})
	if err != nil {
		return a.fail(command, err, false)
	}
	return a.fail(command, &cliError{exit: 4, code: "not_implemented", message: command + " is not implemented in the Go CLI draft yet"}, flags.json)
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
  furrow row status [row-name] [--json]
  furrow row transition <row-name> --step <step> [--json]
  furrow row init ...
  furrow row checkpoint ...
  furrow row archive ...
  furrow row summary ...
  furrow row validate ...
  furrow row list ...`)
}

type parsedFlags struct {
	json   bool
	values map[string]string
}

func parseArgs(args []string, valueFlags map[string]bool) ([]string, parsedFlags, error) {
	out := parsedFlags{values: map[string]string{}}
	positionals := make([]string, 0, len(args))

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--json":
			out.json = true
		case strings.HasPrefix(arg, "--"):
			name := strings.TrimPrefix(arg, "--")
			if valueFlags[name] {
				if i+1 >= len(args) {
					return nil, out, &cliError{exit: 1, code: "usage", message: fmt.Sprintf("missing value for --%s", name)}
				}
				out.values[name] = args[i+1]
				i++
				continue
			}
			if strings.Contains(name, "=") {
				parts := strings.SplitN(name, "=", 2)
				if valueFlags[parts[0]] {
					out.values[parts[0]] = parts[1]
					continue
				}
			}
			return nil, out, &cliError{exit: 1, code: "usage", message: fmt.Sprintf("unknown flag %s", arg)}
		default:
			positionals = append(positionals, arg)
		}
	}

	return positionals, out, nil
}

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
			return "", errors.New(".furrow root not found")
		}
		current = next
	}
}

func readFocusedRow(root string) (string, error) {
	payload, err := os.ReadFile(filepath.Join(root, ".furrow", ".focused"))
	if err != nil {
		return "", errors.New("no row name provided and .furrow/.focused is unavailable")
	}
	row := strings.TrimSpace(string(payload))
	if row == "" {
		return "", errors.New(".furrow/.focused is empty")
	}
	return row, nil
}

func ternary[T any](cond bool, a, b T) T {
	if cond {
		return a
	}
	return b
}
