package cli

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// validSkillLayers is the set of layer values accepted in skill front-matter.
var validSkillLayers = map[string]bool{
	"operator": true,
	"driver":   true,
	"engine":   true,
	"shared":   true,
}

// runValidateSkillLayers implements `furrow validate skill-layers`.
//
// Scans all *.md files under skills/ for the required YAML front-matter
// `layer:` field. Emits skill_layer_unset for any file missing the field.
//
// Exit codes:
//   - 0: all skill files have valid layer: front-matter.
//   - 3: one or more files are missing or have invalid layer: values.
func (a *App) runValidateSkillLayers(args []string) int {
	_, flags, err := parseArgs(args, map[string]bool{"skills-dir": true}, nil)
	if err != nil {
		return a.fail("furrow validate skill-layers", err, false)
	}

	skillsDir := flags.values["skills-dir"]
	if skillsDir == "" {
		skillsDir = "skills"
	}

	type violation struct {
		Path   string `json:"path"`
		Code   string `json:"code"`
		Detail string `json:"detail"`
	}

	var violations []violation

	err = filepath.Walk(skillsDir, func(path string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if info.IsDir() || !strings.HasSuffix(path, ".md") {
			return nil
		}

		lyr, found, parseErr := extractLayerFrontMatter(path)
		if parseErr != nil {
			violations = append(violations, violation{
				Path:   path,
				Code:   "skill_layer_unset",
				Detail: fmt.Sprintf("error reading file: %v", parseErr),
			})
			return nil
		}
		if !found {
			violations = append(violations, violation{
				Path:   path,
				Code:   "skill_layer_unset",
				Detail: "skill missing required 'layer:' front-matter field",
			})
			return nil
		}
		if !validSkillLayers[lyr] {
			violations = append(violations, violation{
				Path:   path,
				Code:   "skill_layer_unset",
				Detail: fmt.Sprintf("invalid layer value %q; must be one of: operator, driver, engine, shared", lyr),
			})
		}
		return nil
	})

	if err != nil {
		return a.fail("furrow validate skill-layers", &cliError{
			exit:    3,
			code:    "skill_layer_unset",
			message: fmt.Sprintf("walking skills dir %q: %v", skillsDir, err),
		}, flags.json)
	}

	if len(violations) == 0 {
		if flags.json {
			return a.okJSON("furrow validate skill-layers", map[string]any{
				"valid":   true,
				"checked": skillsDir,
			})
		}
		_, _ = fmt.Fprintf(a.stdout, "skill-layers: all valid (%s)\n", skillsDir)
		return 0
	}

	if flags.json {
		blockers := make([]map[string]any, 0, len(violations))
		for _, v := range violations {
			blockers = append(blockers, map[string]any{
				"code":   v.Code,
				"path":   v.Path,
				"detail": v.Detail,
			})
		}
		return a.fail("furrow validate skill-layers", &cliError{
			exit:    3,
			code:    "skill_layer_unset",
			message: fmt.Sprintf("%d skill(s) missing valid layer: front-matter", len(violations)),
			details: map[string]any{"blockers": blockers},
		}, true)
	}

	for _, v := range violations {
		_, _ = fmt.Fprintf(a.stderr, "skill_layer_unset: %s: %s\n", v.Path, v.Detail)
	}
	return 3
}

// extractLayerFrontMatter opens the file at path and attempts to parse YAML
// front-matter (delimited by ---). Returns (value, found, err).
//
// Front-matter is the block between the first two --- delimiters at the start
// of the file. We perform a minimal scan — just enough to find `layer: <value>`.
func extractLayerFrontMatter(path string) (string, bool, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", false, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)

	// Check first non-empty line for opening ---.
	var firstLine string
	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) != "" {
			firstLine = line
			break
		}
	}
	if strings.TrimSpace(firstLine) != "---" {
		// No front-matter block.
		return "", false, nil
	}

	// Scan front-matter lines until closing ---.
	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) == "---" {
			// End of front-matter block — field not found.
			break
		}
		// Parse `layer: <value>`.
		if strings.HasPrefix(strings.TrimSpace(line), "layer:") {
			parts := strings.SplitN(line, ":", 2)
			if len(parts) == 2 {
				val := strings.TrimSpace(parts[1])
				// Strip inline quotes.
				val = strings.Trim(val, `"'`)
				return val, true, nil
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return "", false, err
	}

	return "", false, nil
}
