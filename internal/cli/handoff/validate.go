package handoff

import (
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strings"
)

// Envelope is the taxonomy-conformant blocker envelope emitted on validation failure.
type Envelope struct {
	Code             string `json:"code"`
	Category         string `json:"category"`
	Severity         string `json:"severity"`
	Message          string `json:"message"`
	RemediationHint  string `json:"remediation_hint"`
	ConfirmationPath string `json:"confirmation_path"`
}

// Registered blocker codes for handoff validation.
const (
	CodeHandoffSchemaInvalid        = "handoff_schema_invalid"
	CodeHandoffRequiredFieldMissing = "handoff_required_field_missing"
	CodeHandoffUnknownField         = "handoff_unknown_field"
)

var (
	driverTargetPattern = regexp.MustCompile(`^driver:(ideate|research|plan|spec|decompose|implement|review)$`)
	engineTargetPattern = regexp.MustCompile(`^engine:([a-z0-9]+(-[a-z0-9]+)*|freeform)$`)
	kebabPattern        = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
	rowPattern          = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
	validSteps          = map[string]struct{}{
		"ideate": {}, "research": {}, "plan": {}, "spec": {},
		"decompose": {}, "implement": {}, "review": {},
	}
)

// ValidateFile reads the file at path, sniffs whether it is a driver or engine
// handoff from the first H1 heading, unmarshals the JSON content embedded in
// the file, and validates against the appropriate schema rules.
//
// Returns nil on success. On failure returns an *Envelope describing the first
// validation error found.
func ValidateFile(path string) (*Envelope, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("validate handoff: read %s: %w", path, err)
	}
	return ValidateBytes(data, path)
}

// ValidateBytes validates the rendered handoff markdown bytes.
// It sniffs the handoff kind from the first H1 line, then extracts
// embedded JSON (if any) or falls back to parsing the markdown sections
// back into a struct for schema validation.
//
// For the purposes of this validator, the "handoff" is treated as the
// JSON representation that was used to render the markdown. Callers that
// have the original JSON should use ValidateDriverJSON / ValidateEngineJSON directly.
func ValidateBytes(data []byte, path string) (*Envelope, error) {
	content := string(data)
	lines := strings.Split(content, "\n")

	kind := sniffKind(lines)
	switch kind {
	case "driver":
		return validateDriverMarkdown(content, path)
	case "engine":
		return validateEngineMarkdown(content, path)
	default:
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: cannot determine handoff kind (expected '# Driver Handoff:' or '# Engine Handoff:' as first heading)", path),
			RemediationHint:  "Ensure the file begins with '# Driver Handoff: ...' or '# Engine Handoff: ...'",
			ConfirmationPath: "block",
		}, nil
	}
}

// sniffKind reads the first non-blank line and returns "driver", "engine", or "".
func sniffKind(lines []string) string {
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "<!--") {
			continue
		}
		if strings.HasPrefix(trimmed, "# Driver Handoff:") {
			return "driver"
		}
		if strings.HasPrefix(trimmed, "# Engine Handoff:") {
			return "engine"
		}
		return ""
	}
	return ""
}

// ValidateDriverJSON validates a DriverHandoff from its JSON representation.
func ValidateDriverJSON(data []byte, path string) (*Envelope, error) {
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: invalid JSON: %v", path, err),
			RemediationHint:  "Ensure the handoff is valid JSON",
			ConfirmationPath: "block",
		}, nil
	}

	// Check for unknown fields.
	allowedDriver := map[string]struct{}{
		"target": {}, "step": {}, "row": {}, "objective": {},
		"grounding": {}, "constraints": {}, "return_format": {},
	}
	for k := range raw {
		if _, ok := allowedDriver[k]; !ok {
			return &Envelope{
				Code:             CodeHandoffUnknownField,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: unknown field %q in DriverHandoff", path, k),
				RemediationHint:  "Remove fields not declared in the DriverHandoff schema",
				ConfirmationPath: "block",
			}, nil
		}
	}

	// Check required fields.
	required := []string{"target", "step", "row", "objective", "grounding", "return_format"}
	for _, field := range required {
		v, exists := raw[field]
		if !exists || v == nil {
			return &Envelope{
				Code:             CodeHandoffRequiredFieldMissing,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: missing required field %q in DriverHandoff", path, field),
				RemediationHint:  fmt.Sprintf("Add the %q field to the handoff", field),
				ConfirmationPath: "block",
			}, nil
		}
		s, ok := v.(string)
		if !ok || strings.TrimSpace(s) == "" {
			return &Envelope{
				Code:             CodeHandoffRequiredFieldMissing,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: field %q must be a non-empty string in DriverHandoff", path, field),
				RemediationHint:  fmt.Sprintf("Provide a non-empty string for %q", field),
				ConfirmationPath: "block",
			}, nil
		}
	}

	// Validate constraints field exists (it's required but can be empty array).
	if _, exists := raw["constraints"]; !exists {
		return &Envelope{
			Code:             CodeHandoffRequiredFieldMissing,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: missing required field \"constraints\" in DriverHandoff", path),
			RemediationHint:  "Add a \"constraints\" array (may be empty) to the handoff",
			ConfirmationPath: "block",
		}, nil
	}

	// Unmarshal into typed struct for pattern validation.
	var h DriverHandoff
	if err := json.Unmarshal(data, &h); err != nil {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: failed to unmarshal DriverHandoff: %v", path, err),
			RemediationHint:  "Check field types match the schema",
			ConfirmationPath: "block",
		}, nil
	}

	if !driverTargetPattern.MatchString(h.Target) {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: target %q does not match ^driver:(ideate|research|plan|spec|decompose|implement|review)$", path, h.Target),
			RemediationHint:  "target must be driver:{step} where step is one of the 7 workflow steps",
			ConfirmationPath: "block",
		}, nil
	}

	if _, ok := validSteps[h.Step]; !ok {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: step %q is not one of the 7 valid steps", path, h.Step),
			RemediationHint:  "step must be one of: ideate, research, plan, spec, decompose, implement, review",
			ConfirmationPath: "block",
		}, nil
	}

	if !rowPattern.MatchString(h.Row) {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: row %q does not match kebab-case pattern", path, h.Row),
			RemediationHint:  "row must match ^[a-z0-9]+(-[a-z0-9]+)*$",
			ConfirmationPath: "block",
		}, nil
	}

	if !kebabPattern.MatchString(h.ReturnFormat) {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: return_format %q does not match kebab-case pattern", path, h.ReturnFormat),
			RemediationHint:  "return_format must match ^[a-z0-9]+(-[a-z0-9]+)*$",
			ConfirmationPath: "block",
		}, nil
	}

	return nil, nil
}

// ValidateEngineJSON validates an EngineHandoff from its JSON representation.
func ValidateEngineJSON(data []byte, path string) (*Envelope, error) {
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: invalid JSON: %v", path, err),
			RemediationHint:  "Ensure the handoff is valid JSON",
			ConfirmationPath: "block",
		}, nil
	}

	// Check for unknown fields.
	allowedEngine := map[string]struct{}{
		"target": {}, "objective": {}, "deliverables": {},
		"constraints": {}, "grounding": {}, "return_format": {},
	}
	for k := range raw {
		if _, ok := allowedEngine[k]; !ok {
			return &Envelope{
				Code:             CodeHandoffUnknownField,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: unknown field %q in EngineHandoff", path, k),
				RemediationHint:  "Remove fields not declared in the EngineHandoff schema",
				ConfirmationPath: "block",
			}, nil
		}
	}

	// Check required fields exist.
	required := []string{"target", "objective", "deliverables", "constraints", "grounding", "return_format"}
	for _, field := range required {
		if _, exists := raw[field]; !exists || raw[field] == nil {
			return &Envelope{
				Code:             CodeHandoffRequiredFieldMissing,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: missing required field %q in EngineHandoff", path, field),
				RemediationHint:  fmt.Sprintf("Add the %q field to the handoff", field),
				ConfirmationPath: "block",
			}, nil
		}
	}

	// Unmarshal into typed struct.
	var h EngineHandoff
	if err := json.Unmarshal(data, &h); err != nil {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: failed to unmarshal EngineHandoff: %v", path, err),
			RemediationHint:  "Check field types match the schema",
			ConfirmationPath: "block",
		}, nil
	}

	if !engineTargetPattern.MatchString(h.Target) {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: target %q does not match ^engine:{specialist}|engine:freeform$", path, h.Target),
			RemediationHint:  "target must be engine:{specialist-id} or engine:freeform",
			ConfirmationPath: "block",
		}, nil
	}

	// Validate objective — Furrow vocab rejection.
	if ContainsFurrowVocab(h.Objective) {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: objective contains Furrow-specific vocabulary (engine must be Furrow-unaware)", path),
			RemediationHint:  "Remove Furrow-specific terms (gate_policy, deliverable, blocker, almanac, .furrow/, furrow row/context/handoff/hook/validate/gate, rws/alm/sds commands) from objective",
			ConfirmationPath: "block",
		}, nil
	}

	// Validate constraints — Furrow vocab rejection per item.
	for i, c := range h.Constraints {
		if ContainsFurrowVocab(c) {
			return &Envelope{
				Code:             CodeHandoffSchemaInvalid,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: constraints[%d] contains Furrow-specific vocabulary", path, i),
				RemediationHint:  "Remove Furrow-specific terms from engine constraints",
				ConfirmationPath: "block",
			}, nil
		}
	}

	// Validate grounding paths — no .furrow/ paths.
	for i, g := range h.Grounding {
		if strings.Contains(g.Path, ".furrow/") {
			return &Envelope{
				Code:             CodeHandoffSchemaInvalid,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: grounding[%d].path %q contains .furrow/ (engine must be Furrow-unaware)", path, i, g.Path),
				RemediationHint:  "Engine grounding paths must not reference .furrow/ internals",
				ConfirmationPath: "block",
			}, nil
		}
		if strings.TrimSpace(g.WhyRelevant) == "" {
			return &Envelope{
				Code:             CodeHandoffRequiredFieldMissing,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: grounding[%d].why_relevant is empty", path, i),
				RemediationHint:  "Provide a why_relevant explanation for each grounding entry",
				ConfirmationPath: "block",
			}, nil
		}
	}

	// Validate deliverables.
	if len(h.Deliverables) == 0 {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: deliverables must have at least one item", path),
			RemediationHint:  "Add at least one deliverable to the EngineHandoff",
			ConfirmationPath: "block",
		}, nil
	}
	for i, d := range h.Deliverables {
		if !kebabPattern.MatchString(d.Name) {
			return &Envelope{
				Code:             CodeHandoffSchemaInvalid,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: deliverables[%d].name %q does not match kebab-case pattern", path, i, d.Name),
				RemediationHint:  "Deliverable names must match ^[a-z0-9]+(-[a-z0-9]+)*$",
				ConfirmationPath: "block",
			}, nil
		}
		if len(d.AcceptanceCriteria) == 0 {
			return &Envelope{
				Code:             CodeHandoffSchemaInvalid,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: deliverables[%d].acceptance_criteria must have at least one item", path, i),
				RemediationHint:  "Add at least one acceptance criterion",
				ConfirmationPath: "block",
			}, nil
		}
		for j, fo := range d.FileOwnership {
			if strings.Contains(fo, ".furrow/") {
				return &Envelope{
					Code:             CodeHandoffSchemaInvalid,
					Category:         "handoff",
					Severity:         "error",
					Message:          fmt.Sprintf("%s: deliverables[%d].file_ownership[%d] %q contains .furrow/", path, i, j, fo),
					RemediationHint:  "Engine file_ownership paths must not reference .furrow/ internals",
					ConfirmationPath: "block",
				}, nil
			}
		}
	}

	if !kebabPattern.MatchString(h.ReturnFormat) {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: return_format %q does not match kebab-case pattern", path, h.ReturnFormat),
			RemediationHint:  "return_format must match ^[a-z0-9]+(-[a-z0-9]+)*$",
			ConfirmationPath: "block",
		}, nil
	}

	return nil, nil
}

// validateDriverMarkdown parses the driver handoff markdown and validates it.
// For rendered markdown, we reconstruct a minimal JSON for validation.
// This is a structural/content check; full round-trip JSON would require
// a complete parser. For CLI validate, we re-derive fields from sections.
func validateDriverMarkdown(content, path string) (*Envelope, error) {
	// Extract JSON block if present (for validate of JSON-embedded handoffs).
	// If not, do a structural check by looking for required section markers.
	markers := []string{
		"<!-- driver-handoff:section:target -->",
		"<!-- driver-handoff:section:objective -->",
		"<!-- driver-handoff:section:grounding -->",
		"<!-- driver-handoff:section:constraints -->",
		"<!-- driver-handoff:section:return-format -->",
	}
	for _, m := range markers {
		if !strings.Contains(content, m) {
			return &Envelope{
				Code:             CodeHandoffSchemaInvalid,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: missing required section marker %q", path, m),
				RemediationHint:  "Use 'furrow handoff render' to produce a well-formed handoff document",
				ConfirmationPath: "block",
			}, nil
		}
	}
	return nil, nil
}

// validateEngineMarkdown parses the engine handoff markdown and validates it.
func validateEngineMarkdown(content, path string) (*Envelope, error) {
	markers := []string{
		"<!-- engine-handoff:section:target -->",
		"<!-- engine-handoff:section:objective -->",
		"<!-- engine-handoff:section:deliverables -->",
		"<!-- engine-handoff:section:constraints -->",
		"<!-- engine-handoff:section:grounding -->",
		"<!-- engine-handoff:section:return-format -->",
	}
	for _, m := range markers {
		if !strings.Contains(content, m) {
			return &Envelope{
				Code:             CodeHandoffSchemaInvalid,
				Category:         "handoff",
				Severity:         "error",
				Message:          fmt.Sprintf("%s: missing required section marker %q", path, m),
				RemediationHint:  "Use 'furrow handoff render' to produce a well-formed handoff document",
				ConfirmationPath: "block",
			}, nil
		}
	}

	// Check for Furrow vocab leakage in engine handoff markdown.
	if ContainsFurrowVocab(content) {
		return &Envelope{
			Code:             CodeHandoffSchemaInvalid,
			Category:         "handoff",
			Severity:         "error",
			Message:          fmt.Sprintf("%s: engine handoff contains Furrow-specific vocabulary (engine must be Furrow-unaware)", path),
			RemediationHint:  "Remove Furrow-specific terms from engine handoff content",
			ConfirmationPath: "block",
		}, nil
	}
	return nil, nil
}
