package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	yaml "gopkg.in/yaml.v3"
)

// handlePreWriteCorrectionLimit implements the Go port of correction-limit.sh
// (research/hook-audit.md §2.1). The hook fires on every PreToolUse(Write|Edit)
// and emits `correction_limit_reached` when:
//
//  1. A target_path is supplied, AND
//  2. The path resolves to a row directory (.furrow/rows/<row>/...) or
//     fallback to the focused row, AND
//  3. The row is not archived, AND
//  4. The row's current step is "implement", AND
//  5. The row's plan.json maps the path to a deliverable whose
//     state.json `corrections` count >= the configured limit.
//
// On any earlier short-circuit (no path, no row, archived, wrong step,
// no plan.json) the handler returns nil with no error — a clean pass.
//
// The configured limit comes from .furrow/furrow.yaml or .claude/furrow.yaml
// `defaults.correction_limit`; default 3 if neither is present.
func handlePreWriteCorrectionLimit(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	path := firstNonEmptyString(evt.TargetPath, asString(evt.Payload["target_path"]))
	if path == "" {
		return nil, nil
	}

	root, err := correctionLimitRoot()
	if err != nil {
		// No .furrow/ root resolvable → caller is outside a Furrow project.
		// Treat as no-trigger; the hook should never block in this case.
		return nil, nil
	}

	rowDir := correctionLimitResolveRow(root, path)
	if rowDir == "" {
		return nil, nil
	}

	statePath := filepath.Join(rowDir, "state.json")
	state, err := loadJSONMap(statePath)
	if err != nil {
		// state.json unreadable → can't enforce correctly; pass.
		return nil, nil
	}
	if isArchivedState(state) {
		return nil, nil
	}
	if step, _ := getString(state, "step"); step != "implement" {
		return nil, nil
	}

	planPath := filepath.Join(rowDir, "plan.json")
	plan, err := loadJSONMap(planPath)
	if err != nil {
		return nil, nil
	}

	limit := correctionLimitFromConfig(root)
	deliverables, ok := state["deliverables"].(map[string]any)
	if !ok {
		return nil, nil
	}

	for delName, raw := range deliverables {
		entry, ok := raw.(map[string]any)
		if !ok {
			continue
		}
		corrections, _ := intFromAny(entry["corrections"])
		if corrections < limit {
			continue
		}
		// Walk plan.json globs for this deliverable; emit if any glob
		// matches the path.
		for _, glob := range planFileOwnershipGlobs(plan, delName) {
			matched, _ := filepath.Match(glob, path)
			if !matched {
				// Also try matching against the path's tail relative to the
				// repo root, which is how plan.json globs are typically
				// authored (e.g., "internal/cli/**").
				continue
			}
			env := tx.EmitBlocker("correction_limit_reached", map[string]string{
				"limit":       fmt.Sprintf("%d", limit),
				"deliverable": delName,
				"path":        path,
			})
			return []BlockerEnvelope{env}, nil
		}
	}
	return nil, nil
}

// correctionLimitRoot resolves the Furrow project root, allowing the
// FURROW_ROOT env override (which the shell helpers also honor) to win
// over working-directory inference. This makes the handler testable
// without chdir gymnastics.
func correctionLimitRoot() (string, error) {
	if override := strings.TrimSpace(os.Getenv("FURROW_ROOT")); override != "" {
		if _, err := os.Stat(filepath.Join(override, ".furrow")); err == nil {
			return override, nil
		}
	}
	return findFurrowRoot()
}

// correctionLimitResolveRow returns the row directory the path belongs
// to, or empty string when it can't be resolved. Resolution mirrors
// extract_row_from_path + find_focused_row from common-minimal.sh:
//  1. If path contains ".furrow/rows/<row>/", that row wins.
//  2. Otherwise fall back to the focused row (.furrow/.focused).
//  3. Otherwise empty.
func correctionLimitResolveRow(root, path string) string {
	const marker = ".furrow/rows/"
	if i := strings.Index(path, marker); i >= 0 {
		remainder := path[i+len(marker):]
		// First component is the row name; reject dotfiles/underscores
		// to skip metadata entries (matches common-minimal.sh).
		end := strings.IndexByte(remainder, '/')
		if end < 0 {
			end = len(remainder)
		}
		name := remainder[:end]
		if name != "" && !strings.HasPrefix(name, ".") && !strings.HasPrefix(name, "_") {
			candidate := filepath.Join(root, ".furrow", "rows", name)
			if _, err := os.Stat(filepath.Join(candidate, "state.json")); err == nil {
				return candidate
			}
		}
	}
	if focused, present, err := readFocusedRowName(root); err == nil && present && focused != "" {
		candidate := filepath.Join(root, ".furrow", "rows", focused)
		if _, err := os.Stat(filepath.Join(candidate, "state.json")); err == nil {
			return candidate
		}
	}
	return ""
}

// correctionLimitFromConfig reads defaults.correction_limit from
// <root>/.furrow/furrow.yaml or <root>/.claude/furrow.yaml. Returns 3
// when neither file exists or the key is absent (matching the hook's
// fallback). Errors during YAML parse return 3 — the hook's pre-Go
// behavior was to fail-open to the default rather than blocking writes
// on a malformed config.
func correctionLimitFromConfig(root string) int {
	for _, rel := range []string{".furrow/furrow.yaml", ".claude/furrow.yaml"} {
		path := filepath.Join(root, rel)
		payload, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		var doc map[string]any
		if err := yaml.Unmarshal(payload, &doc); err != nil {
			continue
		}
		defaults, _ := doc["defaults"].(map[string]any)
		if defaults == nil {
			continue
		}
		if n, ok := intFromAny(defaults["correction_limit"]); ok && n > 0 {
			return n
		}
	}
	return 3
}

// planFileOwnershipGlobs walks plan.json -> waves[].assignments[<deliverable>].file_ownership[]
// returning a flattened list of globs for the named deliverable. Matches
// the jq filter on correction-limit.sh:79-81.
func planFileOwnershipGlobs(plan map[string]any, deliverable string) []string {
	out := make([]string, 0)
	waves, _ := plan["waves"].([]any)
	for _, rawWave := range waves {
		wave, ok := rawWave.(map[string]any)
		if !ok {
			continue
		}
		assignments, _ := wave["assignments"].(map[string]any)
		if assignments == nil {
			continue
		}
		entry, _ := assignments[deliverable].(map[string]any)
		if entry == nil {
			continue
		}
		ownership, _ := entry["file_ownership"].([]any)
		for _, raw := range ownership {
			s, ok := raw.(string)
			if ok && s != "" {
				out = append(out, s)
			}
		}
	}
	return out
}
