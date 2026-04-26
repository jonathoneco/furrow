package handoff

import (
	"bytes"
	_ "embed"
	"fmt"
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

// RenderDriver renders a DriverHandoff to its canonical markdown representation.
// The section order is stable and driven by the embedded template.
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
	var buf bytes.Buffer
	if err := driverTmpl.Execute(&buf, h); err != nil {
		return "", fmt.Errorf("render driver: template execution: %w", err)
	}
	return buf.String(), nil
}

// RenderEngine renders an EngineHandoff to its canonical markdown representation.
// The section order is stable and driven by the embedded template.
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
	var buf bytes.Buffer
	if err := engineTmpl.Execute(&buf, h); err != nil {
		return "", fmt.Errorf("render engine: template execution: %w", err)
	}
	return buf.String(), nil
}
