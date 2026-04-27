package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// driverDefinitionYAML mirrors the driver-definition.schema.json shape.
type driverDefinitionYAML struct {
	Name           string   `yaml:"name"`
	Step           string   `yaml:"step"`
	ToolsAllowlist []string `yaml:"tools_allowlist"`
	Model          string   `yaml:"model"`
}

// driverViolation records a single validation error for a driver definition file.
type driverViolation struct {
	Path   string
	Step   string
	Code   string
	Detail string
}

// runValidateDriverDefinitions implements `furrow validate driver-definitions`.
//
// Scans .furrow/drivers/driver-{step}.yaml for all 7 steps, validating each
// against the required fields (name, step, tools_allowlist, model).
// Emits driver_definition_invalid for any missing or malformed definition.
//
// Exit codes:
//   - 0: all driver definitions are valid.
//   - 3: one or more definitions are missing or invalid.
func (a *App) runValidateDriverDefinitions(args []string) int {
	_, flags, err := parseArgs(args, map[string]bool{"drivers-dir": true}, nil)
	if err != nil {
		return a.fail("furrow validate driver-definitions", err, false)
	}

	driversDir := flags.values["drivers-dir"]
	if driversDir == "" {
		driversDir = filepath.Join(".furrow", "drivers")
	}

	steps := []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}

	var violations []driverViolation

	for _, step := range steps {
		path := filepath.Join(driversDir, fmt.Sprintf("driver-%s.yaml", step))

		data, readErr := os.ReadFile(path)
		if readErr != nil {
			violations = append(violations, driverViolation{
				Path:   path,
				Step:   step,
				Code:   "driver_definition_invalid",
				Detail: fmt.Sprintf("file not found: %v", readErr),
			})
			continue
		}

		var def driverDefinitionYAML
		if parseErr := yaml.Unmarshal(data, &def); parseErr != nil {
			violations = append(violations, driverViolation{
				Path:   path,
				Step:   step,
				Code:   "driver_definition_invalid",
				Detail: fmt.Sprintf("YAML parse error: %v", parseErr),
			})
			continue
		}

		violations = append(violations, validateDriverDef(path, step, def)...)
	}

	if len(violations) == 0 {
		if flags.json {
			return a.okJSON("furrow validate driver-definitions", map[string]any{
				"valid":       true,
				"drivers_dir": driversDir,
				"steps":       steps,
			})
		}
		_, _ = fmt.Fprintf(a.stdout, "driver-definitions: all valid (%s)\n", driversDir)
		return 0
	}

	if flags.json {
		blockers := make([]map[string]any, 0, len(violations))
		for _, v := range violations {
			blockers = append(blockers, map[string]any{
				"code":   v.Code,
				"path":   v.Path,
				"step":   v.Step,
				"detail": v.Detail,
			})
		}
		return a.fail("furrow validate driver-definitions", &cliError{
			exit:    3,
			code:    "driver_definition_invalid",
			message: fmt.Sprintf("%d driver definition(s) failed validation", len(violations)),
			details: map[string]any{"blockers": blockers},
		}, true)
	}

	for _, v := range violations {
		_, _ = fmt.Fprintf(a.stderr, "driver_definition_invalid: %s: %s\n", v.Path, v.Detail)
	}
	return 3
}

func validateDriverDef(path, step string, def driverDefinitionYAML) []driverViolation {
	var vs []driverViolation
	add := func(detail string) {
		vs = append(vs, driverViolation{
			Path:   path,
			Step:   step,
			Code:   "driver_definition_invalid",
			Detail: detail,
		})
	}

	if def.Name == "" {
		add("missing required field 'name'")
	} else if !strings.HasPrefix(def.Name, "driver:") {
		add(fmt.Sprintf("name %q should have 'driver:' prefix", def.Name))
	}

	if def.Step == "" {
		add("missing required field 'step'")
	} else if def.Step != step {
		add(fmt.Sprintf("step field %q does not match expected %q from filename", def.Step, step))
	}

	if len(def.ToolsAllowlist) == 0 {
		add("missing or empty required field 'tools_allowlist'")
	}

	if def.Model == "" {
		add("missing required field 'model'")
	}

	return vs
}
