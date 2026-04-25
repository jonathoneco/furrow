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
	// allowedDeliverableKeys mirrors deliverables[].properties +
	// additionalProperties:false in schemas/definition.schema.json.
	allowedDeliverableKeys = map[string]struct{}{
		"name":                {},
		"acceptance_criteria": {},
		"specialist":          {},
		"depends_on":          {},
		"file_ownership":      {},
		"gate":                {},
	}
	// allowedContextPointerKeys mirrors context_pointers[].properties +
	// additionalProperties:false.
	allowedContextPointerKeys = map[string]struct{}{
		"path":    {},
		"symbols": {},
		"note":    {},
	}
	// allowedSupersedesKeys mirrors supersedes.properties + additionalProperties:false.
	allowedSupersedesKeys = map[string]struct{}{
		"commit": {},
		"row":    {},
	}
	// validDeliverableGates mirrors deliverables[].gate enum.
	validDeliverableGates = map[string]struct{}{"human": {}, "automated": {}}
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

			// acceptance_criteria: required + must be an array + minItems:1 + per-item placeholder check
			rawCriteria, hasCriteria := d["acceptance_criteria"]
			criteria, criteriaIsArray := rawCriteria.([]any)
			if !hasCriteria {
				envs = append(envs, tx.EmitBlocker("definition_acceptance_criteria_placeholder", map[string]string{
					"path":  displayPath,
					"name":  name,
					"value": "(missing)",
				}))
			} else if !criteriaIsArray {
				envs = append(envs, tx.EmitBlocker("definition_acceptance_criteria_placeholder", map[string]string{
					"path":  displayPath,
					"name":  name,
					"value": fmt.Sprintf("(wrong type: %T, must be array)", rawCriteria),
				}))
			} else {
				if len(criteria) == 0 {
					envs = append(envs, tx.EmitBlocker("definition_acceptance_criteria_placeholder", map[string]string{
						"path":  displayPath,
						"name":  name,
						"value": "(empty)",
					}))
				}
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

			// file_ownership: optional but if present must be array of strings
			if rawFO, present := d["file_ownership"]; present {
				if foArr, isArr := rawFO.([]any); !isArr {
					envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
						"path": displayPath,
						"keys": fmt.Sprintf("deliverables[%d].file_ownership: type is %T, must be an array", i, rawFO),
					}))
				} else {
					for k, item := range foArr {
						if _, isStr := item.(string); !isStr {
							envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
								"path": displayPath,
								"keys": fmt.Sprintf("deliverables[%d].file_ownership[%d]: type is %T, must be a string", i, k, item),
							}))
						}
					}
				}
			}

			// depends_on: optional but if present must be array of strings
			if rawDO, present := d["depends_on"]; present {
				if doArr, isArr := rawDO.([]any); !isArr {
					envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
						"path": displayPath,
						"keys": fmt.Sprintf("deliverables[%d].depends_on: type is %T, must be an array", i, rawDO),
					}))
				} else {
					for k, item := range doArr {
						if _, isStr := item.(string); !isStr {
							envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
								"path": displayPath,
								"keys": fmt.Sprintf("deliverables[%d].depends_on[%d]: type is %T, must be a string", i, k, item),
							}))
						}
					}
				}
			}

			// nested additionalProperties:false — flag any keys not in the schema
			var unknownNested []string
			for k := range d {
				if _, ok := allowedDeliverableKeys[k]; !ok {
					unknownNested = append(unknownNested, k)
				}
			}
			if len(unknownNested) > 0 {
				sort.Strings(unknownNested)
				envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
					"path": displayPath,
					"keys": fmt.Sprintf("deliverables[%d]: %s", i, strings.Join(unknownNested, ", ")),
				}))
			}

			// gate enum check (optional field; if present must be valid)
			if gate, present := d["gate"]; present {
				gs, _ := gate.(string)
				if _, ok := validDeliverableGates[gs]; !ok {
					envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
						"path": displayPath,
						"keys": fmt.Sprintf("deliverables[%d].gate: %v (must be human|automated)", i, gate),
					}))
				}
			}
		}
	}

	// context_pointers: required + must be an array + minItems:1 + per-item required path/note + additionalProperties:false
	rawCP, hasCP := raw["context_pointers"]
	cpArr, cpIsArray := rawCP.([]any)
	switch {
	case !hasCP:
		envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
			"path": displayPath,
			"keys": "(missing required field) context_pointers",
		}))
	case !cpIsArray:
		envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
			"path": displayPath,
			"keys": fmt.Sprintf("context_pointers: type is %T, must be an array", rawCP),
		}))
	default:
		if len(cpArr) == 0 {
			envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
				"path": displayPath,
				"keys": "context_pointers: minItems:1 violated (array is empty)",
			}))
		}
		for j, item := range cpArr {
			cp, ok := item.(map[string]any)
			if !ok {
				continue
			}
			if !nonEmptyString(cp["path"]) {
				envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
					"path": displayPath,
					"keys": fmt.Sprintf("context_pointers[%d]: missing required field 'path'", j),
				}))
			}
			if !nonEmptyString(cp["note"]) {
				envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
					"path": displayPath,
					"keys": fmt.Sprintf("context_pointers[%d]: missing required field 'note'", j),
				}))
			}
			// symbols: optional, but if present must be array of strings
			if rawSym, present := cp["symbols"]; present {
				if symArr, isArr := rawSym.([]any); !isArr {
					envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
						"path": displayPath,
						"keys": fmt.Sprintf("context_pointers[%d].symbols: type is %T, must be an array", j, rawSym),
					}))
				} else {
					for k, item := range symArr {
						if _, isStr := item.(string); !isStr {
							envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
								"path": displayPath,
								"keys": fmt.Sprintf("context_pointers[%d].symbols[%d]: type is %T, must be a string", j, k, item),
							}))
						}
					}
				}
			}
			var unknown []string
			for k := range cp {
				if _, ok := allowedContextPointerKeys[k]; !ok {
					unknown = append(unknown, k)
				}
			}
			if len(unknown) > 0 {
				sort.Strings(unknown)
				envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
					"path": displayPath,
					"keys": fmt.Sprintf("context_pointers[%d]: %s", j, strings.Join(unknown, ", ")),
				}))
			}
		}
	}

	// constraints: required + must be an array of strings
	rawConstraints, hasConstraints := raw["constraints"]
	if !hasConstraints {
		envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
			"path": displayPath,
			"keys": "(missing required field) constraints",
		}))
	} else if cArr, ok := rawConstraints.([]any); !ok {
		envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
			"path": displayPath,
			"keys": fmt.Sprintf("constraints: type is %T, must be an array", rawConstraints),
		}))
	} else {
		for i, item := range cArr {
			if _, isStr := item.(string); !isStr {
				envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
					"path": displayPath,
					"keys": fmt.Sprintf("constraints[%d]: type is %T, must be a string", i, item),
				}))
			}
		}
	}

	// source_todos (optional array): if present must have minItems:1 + uniqueItems
	if rawST, hasST := raw["source_todos"]; hasST {
		stArr, isArr := rawST.([]any)
		if !isArr {
			envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
				"path": displayPath,
				"keys": fmt.Sprintf("source_todos: type is %T, must be an array", rawST),
			}))
		} else {
			if len(stArr) == 0 {
				envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
					"path": displayPath,
					"keys": "source_todos: minItems:1 violated (array is empty)",
				}))
			}
			seen := make(map[string]struct{})
			var dupes, badPatterns []string
			for i, item := range stArr {
				s, isStr := item.(string)
				if !isStr {
					envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
						"path": displayPath,
						"keys": fmt.Sprintf("source_todos[%d]: type is %T, must be a string", i, item),
					}))
					continue
				}
				if !slugPattern.MatchString(s) {
					badPatterns = append(badPatterns, s)
				}
				if _, exists := seen[s]; exists {
					dupes = append(dupes, s)
				}
				seen[s] = struct{}{}
			}
			if len(badPatterns) > 0 {
				sort.Strings(badPatterns)
				envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
					"path": displayPath,
					"keys": fmt.Sprintf("source_todos: entries do not match kebab-case pattern: %s", strings.Join(badPatterns, ", ")),
				}))
			}
			if len(dupes) > 0 {
				sort.Strings(dupes)
				envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
					"path": displayPath,
					"keys": fmt.Sprintf("source_todos: duplicate entries violate uniqueItems: %s", strings.Join(dupes, ", ")),
				}))
			}
		}
	}

	// supersedes (optional block; if present, requires commit AND row;
	// row must match kebab-case slug pattern)
	if rawSup, ok := raw["supersedes"].(map[string]any); ok {
		if !nonEmptyString(rawSup["commit"]) {
			envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
				"path": displayPath,
				"keys": "supersedes: missing required field 'commit'",
			}))
		}
		row, hasRow := rawSup["row"].(string)
		if !hasRow || strings.TrimSpace(row) == "" {
			envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
				"path": displayPath,
				"keys": "supersedes: missing required field 'row'",
			}))
		} else if !slugPattern.MatchString(row) {
			envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
				"path": displayPath,
				"keys": fmt.Sprintf("supersedes.row '%s' does not match kebab-case pattern ^[a-z][a-z0-9]*(-[a-z0-9]+)*$", row),
			}))
		}
	}

	// supersedes additionalProperties:false (optional block)
	if rawSup, ok := raw["supersedes"].(map[string]any); ok {
		var unknown []string
		for k := range rawSup {
			if _, ok := allowedSupersedesKeys[k]; !ok {
				unknown = append(unknown, k)
			}
		}
		if len(unknown) > 0 {
			sort.Strings(unknown)
			envs = append(envs, tx.EmitBlocker("definition_unknown_keys", map[string]string{
				"path": displayPath,
				"keys": fmt.Sprintf("supersedes: %s", strings.Join(unknown, ", ")),
			}))
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
