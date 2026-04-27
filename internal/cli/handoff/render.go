package handoff

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"fmt"
	"strings"
	"text/template"
)

//go:embed templates/handoff-driver.md.tmpl
var driverTmplSrc string

//go:embed templates/handoff-engine.md.tmpl
var engineTmplSrc string

var (
	driverTmpl = template.Must(template.New("driver").Parse(driverTmplSrc))
	engineTmpl = template.Must(template.New("engine").Parse(engineTmplSrc))
)

// driverRenderCtx wraps DriverHandoff with the inlined schema content so the
// template can render the actual EOS-report shape rather than just an identifier.
type driverRenderCtx struct {
	DriverHandoff
	ReturnFormatSchema string
}

// engineRenderCtx wraps EngineHandoff similarly.
type engineRenderCtx struct {
	EngineHandoff
	ReturnFormatSchema string
}

// RenderDriver renders a DriverHandoff to its canonical markdown representation.
// The section order is stable and driven by the embedded template.
// R3: return_format is resolved and the schema content is INLINED into the
// rendered handoff so the receiving driver LLM gets the actual EOS-report shape
// (not just an identifier requiring a separate file read).
func RenderDriver(h DriverHandoff) (string, error) {
	if h.Target == "" {
		return "", fmt.Errorf("render driver: target is required")
	}
	if h.Objective == "" {
		return "", fmt.Errorf("render driver: objective is required")
	}
	if h.Constraints == nil {
		h.Constraints = []string{}
	}
	// Resolve and load the schema content (R3 + prompt-scaffolding wiring).
	var schemaContent string
	if h.ReturnFormat != "" {
		content, err := LoadReturnFormatSchema(h.ReturnFormat)
		if err != nil {
			return "", fmt.Errorf("render driver: %w", err)
		}
		schemaContent = content
	}
	ctx := driverRenderCtx{DriverHandoff: h, ReturnFormatSchema: schemaContent}
	var buf bytes.Buffer
	if err := driverTmpl.Execute(&buf, ctx); err != nil {
		return "", fmt.Errorf("render driver: template execution: %w", err)
	}
	return buf.String(), nil
}

// RenderEngine renders an EngineHandoff to its canonical markdown representation.
// The section order is stable and driven by the embedded template.
// R3: return_format schema content is inlined into the rendered handoff so the
// receiving engine LLM gets the actual EOS-report shape.
func RenderEngine(h EngineHandoff) (string, error) {
	if h.Target == "" {
		return "", fmt.Errorf("render engine: target is required")
	}
	if h.Objective == "" {
		return "", fmt.Errorf("render engine: objective is required")
	}
	if h.Deliverables == nil {
		h.Deliverables = []EngineDeliverable{}
	}
	if h.Constraints == nil {
		h.Constraints = []string{}
	}
	if h.Grounding == nil {
		h.Grounding = []EngineGroundingItem{}
	}
	// Resolve and load the schema content (R3 + prompt-scaffolding wiring).
	var schemaContent string
	if h.ReturnFormat != "" {
		content, err := LoadReturnFormatSchema(h.ReturnFormat)
		if err != nil {
			return "", fmt.Errorf("render engine: %w", err)
		}
		schemaContent = content
	}
	ctx := engineRenderCtx{EngineHandoff: h, ReturnFormatSchema: schemaContent}
	var buf bytes.Buffer
	if err := engineTmpl.Execute(&buf, ctx); err != nil {
		return "", fmt.Errorf("render engine: template execution: %w", err)
	}
	return buf.String(), nil
}

// ParseDriverMarkdown parses the rendered markdown back into a DriverHandoff.
//
// The template layout is:
//
//	<!-- driver-handoff:section:target -->
//	# Driver Handoff: {target}
//	Step: {step}    Row: {row}
//	<!-- driver-handoff:section:objective --> ... <!-- driver-handoff:section:grounding -->
//	Bundle: {grounding}
//	<!-- driver-handoff:section:constraints --> ... - {constraint}
//	<!-- driver-handoff:section:return-format -->
//	`{return_format}` ...
//
// This is the inverse of RenderDriver. It is used by validateDriverMarkdown
// to enable the same ValidateDriverJSON path for both JSON and markdown inputs
// (single-source-of-truth for validation rules).
func ParseDriverMarkdown(content string) (DriverHandoff, error) {
	lines := strings.Split(content, "\n")

	var h DriverHandoff

	// Extract target, step, row from the H1 line: "# Driver Handoff: {target}"
	// and the next line: "Step: {step}    Row: {row}"
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "# Driver Handoff:") {
			h.Target = strings.TrimSpace(strings.TrimPrefix(trimmed, "# Driver Handoff:"))
			// Next non-blank line: "Step: X    Row: Y"
			for j := i + 1; j < len(lines); j++ {
				next := strings.TrimSpace(lines[j])
				if next == "" {
					continue
				}
				h.Step, h.Row = parseStepRow(next)
				break
			}
			break
		}
	}

	// Extract objective: content between section:objective and section:grounding markers.
	h.Objective = strings.TrimSpace(extractBetweenMarkers(content,
		"<!-- driver-handoff:section:objective -->",
		"<!-- driver-handoff:section:grounding -->"))
	// Strip leading "## Objective" heading if present.
	h.Objective = strings.TrimSpace(strings.TrimPrefix(h.Objective, "## Objective"))
	h.Objective = strings.TrimSpace(h.Objective)

	// Extract grounding: content between section:grounding and section:constraints markers.
	groundingBlock := strings.TrimSpace(extractBetweenMarkers(content,
		"<!-- driver-handoff:section:grounding -->",
		"<!-- driver-handoff:section:constraints -->"))
	groundingBlock = strings.TrimSpace(strings.TrimPrefix(groundingBlock, "## Grounding"))
	// Line: "Bundle: {path}"
	for _, line := range strings.Split(groundingBlock, "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "Bundle:") {
			h.Grounding = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(line), "Bundle:"))
			break
		}
	}

	// Extract constraints: content between section:constraints and section:return-format markers.
	constraintsBlock := strings.TrimSpace(extractBetweenMarkers(content,
		"<!-- driver-handoff:section:constraints -->",
		"<!-- driver-handoff:section:return-format -->"))
	constraintsBlock = strings.TrimSpace(strings.TrimPrefix(constraintsBlock, "## Constraints"))
	h.Constraints = []string{}
	for _, line := range strings.Split(constraintsBlock, "\n") {
		stripped := strings.TrimSpace(line)
		if strings.HasPrefix(stripped, "- ") {
			h.Constraints = append(h.Constraints, strings.TrimPrefix(stripped, "- "))
		}
	}

	// Extract return_format: content after section:return-format marker.
	// New format: "Identifier: `{id}`"   (followed by inlined schema in fenced block)
	rfBlock := strings.TrimSpace(extractAfterMarker(content, "<!-- driver-handoff:section:return-format -->"))
	rfBlock = strings.TrimSpace(strings.TrimPrefix(rfBlock, "## Return Format"))
	h.ReturnFormat = extractReturnFormatID(rfBlock)

	if h.Target == "" {
		return DriverHandoff{}, fmt.Errorf("parse driver markdown: could not extract target")
	}
	return h, nil
}

// ParseEngineMarkdown parses the rendered engine handoff markdown back into an EngineHandoff.
// This is the inverse of RenderEngine, used by validateEngineMarkdown for unified validation.
func ParseEngineMarkdown(content string) (EngineHandoff, error) {
	var h EngineHandoff

	// Extract target from H1: "# Engine Handoff: {target}"
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "# Engine Handoff:") {
			h.Target = strings.TrimSpace(strings.TrimPrefix(trimmed, "# Engine Handoff:"))
			break
		}
	}

	// Extract objective.
	h.Objective = strings.TrimSpace(extractBetweenMarkers(content,
		"<!-- engine-handoff:section:objective -->",
		"<!-- engine-handoff:section:deliverables -->"))
	h.Objective = strings.TrimSpace(strings.TrimPrefix(h.Objective, "## Objective"))
	h.Objective = strings.TrimSpace(h.Objective)

	// Extract deliverables: each "### {name}" block.
	deliverablesBlock := strings.TrimSpace(extractBetweenMarkers(content,
		"<!-- engine-handoff:section:deliverables -->",
		"<!-- engine-handoff:section:constraints -->"))
	deliverablesBlock = strings.TrimSpace(strings.TrimPrefix(deliverablesBlock, "## Deliverables"))
	h.Deliverables = parseEngineDeliverables(deliverablesBlock)

	// Extract constraints.
	constraintsBlock := strings.TrimSpace(extractBetweenMarkers(content,
		"<!-- engine-handoff:section:constraints -->",
		"<!-- engine-handoff:section:grounding -->"))
	constraintsBlock = strings.TrimSpace(strings.TrimPrefix(constraintsBlock, "## Constraints"))
	h.Constraints = []string{}
	for _, line := range strings.Split(constraintsBlock, "\n") {
		stripped := strings.TrimSpace(line)
		if strings.HasPrefix(stripped, "- ") {
			h.Constraints = append(h.Constraints, strings.TrimPrefix(stripped, "- "))
		}
	}

	// Extract grounding.
	groundingBlock := strings.TrimSpace(extractBetweenMarkers(content,
		"<!-- engine-handoff:section:grounding -->",
		"<!-- engine-handoff:section:return-format -->"))
	groundingBlock = strings.TrimSpace(strings.TrimPrefix(groundingBlock, "## Grounding"))
	h.Grounding = []EngineGroundingItem{}
	for _, line := range strings.Split(groundingBlock, "\n") {
		stripped := strings.TrimSpace(line)
		// Format: "- `{path}` — {why_relevant}"
		if !strings.HasPrefix(stripped, "- `") {
			continue
		}
		inner := strings.TrimPrefix(stripped, "- `")
		closeBacktick := strings.Index(inner, "`")
		if closeBacktick < 0 {
			continue
		}
		path := inner[:closeBacktick]
		rest := strings.TrimSpace(inner[closeBacktick+1:])
		rest = strings.TrimPrefix(rest, "—")
		rest = strings.TrimPrefix(rest, "—") // em-dash
		rest = strings.TrimSpace(rest)
		h.Grounding = append(h.Grounding, EngineGroundingItem{Path: path, WhyRelevant: rest})
	}

	// Extract return_format. New format: "Identifier: `{id}`" followed by inlined schema.
	rfBlock := strings.TrimSpace(extractAfterMarker(content, "<!-- engine-handoff:section:return-format -->"))
	rfBlock = strings.TrimSpace(strings.TrimPrefix(rfBlock, "## Return Format"))
	h.ReturnFormat = extractReturnFormatID(rfBlock)

	if h.Target == "" {
		return EngineHandoff{}, fmt.Errorf("parse engine markdown: could not extract target")
	}
	return h, nil
}

// extractReturnFormatID extracts the return-format identifier from the rendered
// "Identifier: `{id}`" line in the return-format section. Falls back to a bare
// "`{id}`" line for backwards compatibility with the older template format.
func extractReturnFormatID(block string) string {
	for _, line := range strings.Split(block, "\n") {
		stripped := strings.TrimSpace(line)
		// New format: "Identifier: `{id}`"
		if rest, ok := strings.CutPrefix(stripped, "Identifier:"); ok {
			rest = strings.TrimSpace(rest)
			rest = strings.TrimPrefix(rest, "`")
			if end := strings.Index(rest, "`"); end >= 0 {
				return rest[:end]
			}
		}
		// Stop scanning once we hit the schema fenced code block.
		if strings.HasPrefix(stripped, "```") {
			break
		}
	}
	return ""
}

// parseStepRow parses "Step: X    Row: Y" into step, row strings.
func parseStepRow(line string) (step, row string) {
	// Handle both "Step: X    Row: Y" and "Step: X\tRow: Y" formats.
	parts := strings.Fields(line)
	// Find "Step:" and "Row:" tokens.
	for i := 0; i < len(parts)-1; i++ {
		if parts[i] == "Step:" {
			step = parts[i+1]
		}
		if parts[i] == "Row:" {
			row = parts[i+1]
		}
	}
	return step, row
}

// extractBetweenMarkers returns the content between two marker strings (exclusive).
func extractBetweenMarkers(content, startMarker, endMarker string) string {
	start := strings.Index(content, startMarker)
	if start < 0 {
		return ""
	}
	start += len(startMarker)
	end := strings.Index(content[start:], endMarker)
	if end < 0 {
		return content[start:]
	}
	return content[start : start+end]
}

// extractAfterMarker returns all content after the given marker.
func extractAfterMarker(content, marker string) string {
	idx := strings.Index(content, marker)
	if idx < 0 {
		return ""
	}
	return content[idx+len(marker):]
}

// parseEngineDeliverables parses the deliverables block from rendered engine markdown.
// Each deliverable is a "### {name}" section with acceptance criteria and file ownership.
func parseEngineDeliverables(block string) []EngineDeliverable {
	var deliverables []EngineDeliverable
	sections := strings.Split(block, "### ")
	for _, section := range sections {
		section = strings.TrimSpace(section)
		if section == "" {
			continue
		}
		lines := strings.Split(section, "\n")
		if len(lines) == 0 {
			continue
		}
		name := strings.TrimSpace(lines[0])
		if name == "" {
			continue
		}

		var ac []string
		var fo []string
		inAC := false
		inFO := false

		for _, line := range lines[1:] {
			stripped := strings.TrimSpace(line)
			if strings.Contains(stripped, "Acceptance criteria:") || strings.Contains(stripped, "**Acceptance criteria:**") {
				inAC = true
				inFO = false
				continue
			}
			if strings.Contains(stripped, "File ownership:") || strings.Contains(stripped, "**File ownership:**") {
				inAC = false
				inFO = true
				continue
			}
			if strings.HasPrefix(stripped, "- ") {
				item := strings.TrimPrefix(stripped, "- ")
				// File ownership items are backtick-wrapped.
				item = strings.Trim(item, "`")
				if inAC {
					ac = append(ac, item)
				} else if inFO {
					fo = append(fo, item)
				}
			}
		}
		if ac == nil {
			ac = []string{}
		}
		if fo == nil {
			fo = []string{}
		}
		deliverables = append(deliverables, EngineDeliverable{
			Name:               name,
			AcceptanceCriteria: ac,
			FileOwnership:      fo,
		})
	}
	return deliverables
}

// marshalDriverHandoff converts a DriverHandoff to JSON bytes for passing
// to ValidateDriverJSON. This avoids duplicating validation logic.
func marshalDriverHandoff(h DriverHandoff) ([]byte, error) {
	return json.Marshal(h)
}

// marshalEngineHandoff converts an EngineHandoff to JSON bytes for passing
// to ValidateEngineJSON.
func marshalEngineHandoff(h EngineHandoff) ([]byte, error) {
	return json.Marshal(h)
}
