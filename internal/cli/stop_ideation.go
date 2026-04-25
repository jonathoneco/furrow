package cli

import (
	"os"
	"path/filepath"
	"sort"
	"strings"

	yaml "gopkg.in/yaml.v3"
)

// handleStopIdeationCompleteness implements the Go port of stop-ideation.sh
// (research/hook-audit.md §2.8). The hook fires on the Stop boundary and
// emits `ideation_incomplete_definition_fields` when the row's
// definition.yaml is missing one or more required fields.
//
// Skip conditions (clean pass — return nil, nil):
//   - No row name supplied (caller couldn't resolve a focused row).
//   - definition.yaml is absent (ideation still in progress).
//   - gate_policy is "autonomous" (evaluator validates instead).
//
// The handler does NOT enforce step == ideate; the shim is responsible
// for only invoking guard during the ideate step. This matches the
// shared-contracts §C5 "translation only" boundary for shell shims.
func handleStopIdeationCompleteness(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	row, err := requireString(evt.Payload, "row")
	if err != nil {
		// The schema requires `row` for this event. Treat absence as an
		// invocation error so misrouted shims fail loudly.
		return nil, err
	}

	gatePolicy := asString(evt.Payload["gate_policy"])
	if gatePolicy == "autonomous" {
		return nil, nil
	}

	defPath := asString(evt.Payload["definition_path"])
	if defPath == "" {
		// Try to resolve via FURROW_ROOT or working directory; the shim
		// SHOULD supply definition_path but a graceful fallback keeps the
		// handler usable from tests with t.Setenv("FURROW_ROOT", ...).
		root, rootErr := correctionLimitRoot()
		if rootErr != nil {
			return nil, nil
		}
		defPath = filepath.Join(root, ".furrow", "rows", row, "definition.yaml")
	}
	if _, err := os.Stat(defPath); err != nil {
		// Definition not yet written — ideation still in progress.
		return nil, nil
	}

	missing, err := ideationMissingFields(defPath)
	if err != nil {
		// Malformed YAML is its own issue — but stop-ideation.sh's prior
		// behavior was to fail-open. Preserve that: log via slog at the
		// caller's level (omitted here for pure-handler purity).
		return nil, nil
	}
	if len(missing) == 0 {
		return nil, nil
	}

	return []BlockerEnvelope{
		tx.EmitBlocker("ideation_incomplete_definition_fields", map[string]string{
			"missing": strings.Join(missing, ", "),
		}),
	}, nil
}

// ideationMissingFields parses the definition.yaml at path and returns
// the names of required fields that are absent or empty. Required fields
// match stop-ideation.sh:69-88:
//
//   - objective         (string, non-empty)
//   - gate_policy       (string, non-empty)
//   - deliverables      (array, len >= 1)
//   - context_pointers  (array, len >= 1)
//   - constraints       (any, present and non-empty)
//
// The returned slice is sorted for deterministic output (the shell hook
// emits in field-iteration order; sorting keeps Go test golden-output
// stable).
func ideationMissingFields(path string) ([]string, error) {
	payload, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var doc map[string]any
	if err := yaml.Unmarshal(payload, &doc); err != nil {
		return nil, err
	}
	missing := make([]string, 0, 5)
	for _, scalar := range []string{"objective", "gate_policy"} {
		s, _ := doc[scalar].(string)
		if strings.TrimSpace(s) == "" {
			missing = append(missing, scalar)
		}
	}
	for _, list := range []string{"deliverables", "context_pointers"} {
		arr, _ := doc[list].([]any)
		if len(arr) < 1 {
			missing = append(missing, list)
		}
	}
	if v, ok := doc["constraints"]; !ok || v == nil {
		missing = append(missing, "constraints")
	} else if s, isStr := v.(string); isStr && strings.TrimSpace(s) == "" {
		missing = append(missing, "constraints")
	} else if arr, isArr := v.([]any); isArr && len(arr) == 0 {
		missing = append(missing, "constraints")
	}
	sort.Strings(missing)
	return missing, nil
}
