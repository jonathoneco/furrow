package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

// runValidate dispatches `furrow validate <subcommand>`. D1 ships the
// `definition` subcommand; D2 (wave 3) adds `ownership`.
func (a *App) runValidate(args []string) int {
	if len(args) == 0 {
		_, _ = fmt.Fprintln(a.stdout, "furrow validate\n\nAvailable subcommands: definition")
		return 0
	}
	switch args[0] {
	case "definition":
		return a.runValidateDefinition(args[1:])
	case "help", "-h", "--help":
		_, _ = fmt.Fprintln(a.stdout, "furrow validate\n\nAvailable subcommands: definition")
		return 0
	default:
		return a.fail("furrow validate", &cliError{
			exit: 1, code: "usage",
			message: fmt.Sprintf("unknown validate subcommand %q", args[0]),
		}, false)
	}
}

// runValidateDefinition implements `furrow validate definition`.
//
// Usage: furrow validate definition --path <file> [--json]
//
// Exit codes (per spec/validate-definition-go.md):
//
//	0 — definition.yaml valid
//	1 — usage error (missing/invalid --path, file not found)
//	3 — validation failed (one or more errors)
//
// JSON envelope (with --json):
//
//	{ "ok": true,  "verdict": "valid" }                                                         exit 0
//	{ "ok": false, "verdict": "invalid", "errors": [ ...BlockerEnvelope ] }                     exit 3
//	{ "ok": false, "code": "usage", ... }                                                        exit 1
func (a *App) runValidateDefinition(args []string) int {
	positionals, flags, err := parseArgs(args, map[string]bool{"path": true}, nil)
	if err != nil {
		return a.fail("furrow validate definition", err, false)
	}
	if len(positionals) > 0 {
		return a.fail("furrow validate definition", &cliError{
			exit: 1, code: "usage",
			message: fmt.Sprintf("unexpected positional argument %q (use --path)", positionals[0]),
		}, flags.json)
	}

	path := flags.values["path"]
	if path == "" {
		return a.fail("furrow validate definition", &cliError{
			exit: 1, code: "usage",
			message: "missing required flag --path",
		}, flags.json)
	}

	if _, err := os.Stat(path); err != nil {
		return a.fail("furrow validate definition", &cliError{
			exit: 1, code: "usage",
			message: fmt.Sprintf("file not found: %s", path),
		}, flags.json)
	}

	tx, err := LoadTaxonomy()
	if err != nil {
		return a.fail("furrow validate definition", &cliError{
			exit: 4, code: "internal",
			message: fmt.Sprintf("blocker taxonomy unavailable: %v", err),
		}, flags.json)
	}

	envs := validateDefinition(path, tx)

	if flags.json {
		if len(envs) == 0 {
			return a.okJSON("furrow validate definition", map[string]any{"verdict": "valid"})
		}
		return a.writeJSON(envelope{
			OK:      false,
			Command: "furrow validate definition",
			Version: contractVersion,
			Data:    map[string]any{"verdict": "invalid", "errors": envs},
		}, 3)
	}

	if len(envs) == 0 {
		_, _ = fmt.Fprintln(a.stdout, "definition.yaml is valid")
		return 0
	}
	for _, env := range envs {
		_, _ = fmt.Fprintf(a.stderr, "[%s] %s\n", env.Code, env.Message)
		if env.RemediationHint != "" {
			_, _ = fmt.Fprintf(a.stderr, "  hint: %s\n", env.RemediationHint)
		}
	}
	return 3
}

var deliverableNamePattern = regexp.MustCompile(`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`)

// gatePolicies and modes mirror schemas/definition.schema.json enums.
var (
	validGatePolicies = map[string]struct{}{"supervised": {}, "delegated": {}, "autonomous": {}}
	validModes        = map[string]struct{}{"code": {}, "research": {}}
	placeholderTokens = []string{"todo", "tbd", "xxx", "placeholder"}
	// allowedTopLevelKeys mirrors schemas/definition.schema.json properties +
	// additionalProperties:false. Kept in sync manually because the project
	// has no JSON Schema runtime library (per go.mod).
	allowedTopLevelKeys = map[string]struct{}{
		"objective":        {},
		"deliverables":     {},
		"context_pointers": {},
		"constraints":      {},
		"gate_policy":      {},
		"mode":             {},
		"source_todo":      {},
		"source_todos":     {},
		"supersedes":       {},
	}
)

// validateDefinition runs all D1 checks and returns the list of envelopes for
// any violations. An empty result means the file passed validation.
func validateDefinition(path string, tx *Taxonomy) []BlockerEnvelope {
	payload, err := os.ReadFile(path)
	if err != nil {
		return []BlockerEnvelope{tx.EmitBlocker("definition_yaml_invalid", map[string]string{
			"path":   path,
			"detail": err.Error(),
		})}
	}

	var raw map[string]any
	if err := yaml.Unmarshal(payload, &raw); err != nil {
		return []BlockerEnvelope{tx.EmitBlocker("definition_yaml_invalid", map[string]string{
			"path":   path,
			"detail": err.Error(),
		})}
	}
	if raw == nil {
		return []BlockerEnvelope{tx.EmitBlocker("definition_yaml_invalid", map[string]string{
			"path":   path,
			"detail": "file is empty or contains only null",
		})}
	}

	displayPath := path
	if abs, err := filepath.Abs(path); err == nil {
		displayPath = abs
	}

	var envs []BlockerEnvelope

	// objective
	if !nonEmptyString(raw["objective"]) {
		envs = append(envs, tx.EmitBlocker("definition_objective_missing", map[string]string{
			"path": displayPath,
		}))
	}

	// gate_policy
	gatePolicy, hasGatePolicy := raw["gate_policy"].(string)
	if !hasGatePolicy || strings.TrimSpace(gatePolicy) == "" {
		envs = append(envs, tx.EmitBlocker("definition_gate_policy_missing", map[string]string{
			"path": displayPath,
		}))
	} else if _, ok := validGatePolicies[gatePolicy]; !ok {
		envs = append(envs, tx.EmitBlocker("definition_gate_policy_invalid", map[string]string{
			"path":  displayPath,
			"value": gatePolicy,
		}))
	}

	// mode (optional, but if present must be valid)
	if mode, present := raw["mode"]; present {
		modeStr, ok := mode.(string)
		if !ok || (strings.TrimSpace(modeStr) != "" && validModeMissing(modeStr)) {
			value := fmt.Sprintf("%v", mode)
			envs = append(envs, tx.EmitBlocker("definition_mode_invalid", map[string]string{
				"path":  displayPath,
				"value": value,
			}))
		}
	}

	// deliverables
	rawDeliverables, _ := raw["deliverables"].([]any)
	if len(rawDeliverables) == 0 {
		envs = append(envs, tx.EmitBlocker("definition_deliverables_empty", map[string]string{
			"path": displayPath,
		}))
	} else {
		for i, item := range rawDeliverables {
			d, ok := item.(map[string]any)
			if !ok {
				envs = append(envs, tx.EmitBlocker("definition_deliverable_name_missing", map[string]string{
					"path":  displayPath,
					"index": fmt.Sprintf("%d", i),
				}))
				continue
			}
			name, hasName := d["name"].(string)
			if !hasName || strings.TrimSpace(name) == "" {
				envs = append(envs, tx.EmitBlocker("definition_deliverable_name_missing", map[string]string{
					"path":  displayPath,
					"index": fmt.Sprintf("%d", i),
				}))
			} else if !deliverableNamePattern.MatchString(name) {
				envs = append(envs, tx.EmitBlocker("definition_deliverable_name_invalid_pattern", map[string]string{
					"path": displayPath,
					"name": name,
				}))
			}
			// acceptance_criteria placeholder check
			if criteria, ok := d["acceptance_criteria"].([]any); ok {
				for _, c := range criteria {
					cs, ok := c.(string)
					if !ok {
						continue
					}
					if hasPlaceholderText(cs) {
						envs = append(envs, tx.EmitBlocker("definition_acceptance_criteria_placeholder", map[string]string{
							"path":  displayPath,
							"name":  name,
							"value": cs,
						}))
					}
				}
			}
		}
	}

	// unknown top-level keys (additionalProperties:false from schema)
	var unknown []string
	for k := range raw {
		if _, ok := allowedTopLevelKeys[k]; !ok {
			unknown = append(unknown, k)
		}
	}
	if len(unknown) > 0 {
		sort.Strings(unknown)
		envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
			"path": displayPath,
			"keys": strings.Join(unknown, ", "),
		}))
	}

	return envs
}

func nonEmptyString(v any) bool {
	s, ok := v.(string)
	return ok && strings.TrimSpace(s) != ""
}

func validModeMissing(s string) bool {
	_, ok := validModes[s]
	return !ok
}

// hasPlaceholderText reports whether s appears to be a placeholder acceptance
// criterion — not whether it merely mentions one. The heuristic flags strings
// where the first non-whitespace token (lowercased) is one of the placeholder
// tokens, or where the entire string is a placeholder token. That catches
// "TODO write me" / "TBD" / "  XXX: refine later" but not descriptive prose
// that happens to quote the placeholder words ("...e.g., 'TODO', 'tbd'...").
func hasPlaceholderText(s string) bool {
	trimmed := strings.TrimSpace(s)
	if trimmed == "" {
		return false
	}
	lower := strings.ToLower(trimmed)
	// First-token check: read up to the first non-letter/digit boundary.
	end := 0
	for end < len(lower) {
		c := lower[end]
		if !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
			break
		}
		end++
	}
	firstToken := lower[:end]
	for _, token := range placeholderTokens {
		if firstToken == token {
			return true
		}
	}
	return false
}
