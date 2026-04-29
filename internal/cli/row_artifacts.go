package cli

import (
	"bytes"
	"embed"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
)

const scaffoldMarker = "FURROW-SCAFFOLD-INCOMPLETE"

//go:embed scaffolds/*.tmpl
var scaffoldTemplates embed.FS

type rowArtifactSpec struct {
	ID                    string
	Label                 string
	Path                  string
	Role                  string
	Required              bool
	ScaffoldSupported     bool
	CheckBeforeCompletion bool
	CheckBeforeArchive    bool
}

func artifactSpec(rowDir, id, label string, required, scaffoldSupported bool) rowArtifactSpec {
	return artifactSpecWithRole(rowDir, id, label, "current_step_output", required, scaffoldSupported)
}

func artifactSpecWithRole(rowDir, id, label, role string, required, scaffoldSupported bool) rowArtifactSpec {
	return rowArtifactSpec{
		ID:                    id,
		Label:                 label,
		Path:                  filepath.Join(rowDir, label),
		Role:                  role,
		Required:              required,
		ScaffoldSupported:     scaffoldSupported,
		CheckBeforeCompletion: role != "optional_context",
		CheckBeforeArchive:    role != "optional_context",
	}
}

func materializeRowArtifacts(state map[string]any, specs []rowArtifactSpec) []map[string]any {
	result := make([]map[string]any, 0, len(specs))
	for _, spec := range specs {
		exists := fileExists(spec.Path)
		entry := map[string]any{
			"id":                 spec.ID,
			"label":              spec.Label,
			"path":               spec.Path,
			"role":               spec.Role,
			"required":           spec.Required,
			"exists":             exists,
			"scaffold_supported": spec.ScaffoldSupported,
			"checks": map[string]any{
				"before_completion": spec.CheckBeforeCompletion,
				"before_archive":    spec.CheckBeforeArchive,
			},
			"incomplete": exists && fileContains(spec.Path, scaffoldMarker),
		}
		entry["validation"] = validateArtifact(state, entry)
		result = append(result, entry)
	}
	return result
}

func scaffoldTemplateForArtifact(state map[string]any, artifact map[string]any) (string, bool) {
	id, _ := artifact["id"].(string)
	if id == "plan" {
		payload := map[string]any{
			"_furrow_scaffold": scaffoldMarker,
			"notes": []string{
				"Replace this incomplete scaffold with real waves, assignments, and rationale before completing decompose.",
			},
			"waves":       []any{},
			"assignments": map[string]any{},
		}
		blob, _ := json.MarshalIndent(payload, "", "  ")
		return string(blob) + "\n", true
	}
	data := map[string]any{
		"ScaffoldMarker": scaffoldMarker,
		"GatePolicy":     getStringDefault(state, "gate_policy_init", "supervised"),
	}
	return renderScaffoldTemplate(id, data)
}

func renderScaffoldTemplate(id string, data map[string]any) (string, bool) {
	ext := "md"
	if id == "definition" || id == "claim-surfaces" || id == "follow-ups" {
		ext = "yaml"
	}
	tmplPath := filepath.Join("scaffolds", id+"."+ext+".tmpl")
	tmpl, err := template.ParseFS(scaffoldTemplates, tmplPath)
	if err != nil {
		return "", false
	}
	var out bytes.Buffer
	if err := tmpl.Execute(&out, data); err != nil {
		return "", false
	}
	return out.String(), true
}

func fileContains(path, needle string) bool {
	payload, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	return strings.Contains(string(payload), needle)
}

func gitOutputAt(root string, args ...string) string {
	if !fileExists(filepath.Join(root, ".git")) {
		return ""
	}
	cmd := exec.Command("git", args...)
	cmd.Dir = root
	payload, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(payload))
}
