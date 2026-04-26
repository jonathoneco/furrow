// Package layer provides the canonical layer-policy loader and enforcement
// logic for Furrow's 3-layer orchestration model (operator → driver → engine).
//
// The policy file lives at .furrow/layer-policy.yaml (relative to the repo
// root) and is the single source of truth consumed by both the Claude
// (furrow hook layer-guard PreToolUse) and Pi (tool_call extension) adapters.
package layer

import (
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

// Layer is the canonical 3-tier label.
type Layer string

const (
	LayerOperator Layer = "operator"
	LayerDriver   Layer = "driver"
	LayerEngine   Layer = "engine"
	LayerShared   Layer = "shared"
)

// LayerRules encodes the allow/deny matrix for a single layer.
// Both tool-level and bash-level rules are applied in Decide.
type LayerRules struct {
	// ToolsAllow is the tool whitelist. ["*"] means all tools permitted.
	// An empty list combined with non-empty ToolsDeny is deny-list mode.
	ToolsAllow []string `yaml:"tools_allow" json:"tools_allow"`
	// ToolsDeny is the explicit deny list. Takes precedence over ToolsAllow.
	ToolsDeny []string `yaml:"tools_deny" json:"tools_deny"`
	// PathDeny is the list of path prefixes engines must not read or write.
	PathDeny []string `yaml:"path_deny" json:"path_deny"`
	// BashAllowPrefixes is a whitelist of allowed Bash command prefixes.
	// Empty means no prefix whitelist (fall through to deny-substring check).
	BashAllowPrefixes []string `yaml:"bash_allow_prefixes" json:"bash_allow_prefixes"`
	// BashDenySubstrings is a list of forbidden substrings in Bash commands.
	BashDenySubstrings []string `yaml:"bash_deny_substrings" json:"bash_deny_substrings"`
}

// Policy is the parsed, validated content of .furrow/layer-policy.yaml.
type Policy struct {
	Version      string               `yaml:"version"`
	AgentTypeMap map[string]Layer     `yaml:"agent_type_map"`
	Layers       map[Layer]LayerRules `yaml:"layers"`
}

// Load reads the policy file at path, validates the structure, and returns the
// parsed Policy. Validation failures return a non-nil error whose message
// should be wrapped in blocker code layer_policy_invalid by the caller.
func Load(path string) (*Policy, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("layer_policy_invalid: read %q: %w", path, err)
	}

	var pol Policy
	if err := yaml.Unmarshal(data, &pol); err != nil {
		return nil, fmt.Errorf("layer_policy_invalid: parse %q: %w", path, err)
	}

	if err := pol.validate(); err != nil {
		return nil, fmt.Errorf("layer_policy_invalid: %w", err)
	}

	return &pol, nil
}

// validate checks structural integrity of the parsed policy.
func (p *Policy) validate() error {
	if p.Version == "" {
		return fmt.Errorf("missing required field 'version'")
	}
	if p.Layers == nil {
		return fmt.Errorf("missing required field 'layers'")
	}
	for _, required := range []Layer{LayerOperator, LayerDriver, LayerEngine} {
		if _, ok := p.Layers[required]; !ok {
			return fmt.Errorf("layers must include %q", string(required))
		}
	}
	if p.AgentTypeMap == nil {
		return fmt.Errorf("missing required field 'agent_type_map'")
	}
	return nil
}

// LookupLayer maps an agent_type string to its layer label.
//
// Fail-closed semantics:
//   - Empty/missing agent_type (Claude main-thread, no subagent context) → operator.
//   - Known exact key in agent_type_map → the mapped layer.
//   - Unknown type with "engine:" prefix → engine.
//   - Unknown type with "driver:" prefix → driver.
//   - Anything else → engine (most-restricted default).
func (p *Policy) LookupLayer(agentType string) Layer {
	if agentType == "" {
		return LayerOperator
	}

	// Exact match first.
	if lyr, ok := p.AgentTypeMap[agentType]; ok {
		return lyr
	}

	// Prefix fallback: engine:specialist:{id} and similar.
	if strings.HasPrefix(agentType, "engine:") {
		return LayerEngine
	}
	if strings.HasPrefix(agentType, "driver:") {
		return LayerDriver
	}

	// Unknown: fail-closed to engine (most restricted).
	return LayerEngine
}

// Decide is the pure verdict function — no I/O.
// Returns (allow bool, reason string).
//
// Inputs:
//   - layer: the layer the agent operates in.
//   - toolName: the tool being invoked (e.g. "Edit", "Bash", "Write").
//   - toolInput: a flattened string representation of the tool input,
//     used for path and bash-command substring checks.
func (p *Policy) Decide(lyr Layer, toolName, toolInput string) (bool, string) {
	rules, ok := p.Layers[lyr]
	if !ok {
		// Unknown layer → deny (fail-closed).
		return false, fmt.Sprintf("layer %q not registered in policy", string(lyr))
	}

	// 1. Explicit tool deny (highest precedence).
	for _, denied := range rules.ToolsDeny {
		if strings.EqualFold(denied, toolName) {
			return false, fmt.Sprintf("tool %q is in tools_deny for layer %q", toolName, string(lyr))
		}
	}

	// 2. Tool allow check (if not wildcard "*").
	if len(rules.ToolsAllow) > 0 && rules.ToolsAllow[0] != "*" {
		allowed := false
		for _, a := range rules.ToolsAllow {
			if strings.EqualFold(a, toolName) {
				allowed = true
				break
			}
		}
		if !allowed {
			return false, fmt.Sprintf("tool %q not in tools_allow for layer %q", toolName, string(lyr))
		}
	}

	// 3. Path deny (for file-touching tools: Edit, Write, Read).
	if isFileTool(toolName) {
		for _, pathPrefix := range rules.PathDeny {
			// Normalise: strip trailing slash for prefix match.
			prefix := strings.TrimSuffix(pathPrefix, "/")
			inputNorm := strings.TrimPrefix(toolInput, "./")
			if strings.HasPrefix(inputNorm, prefix) || strings.HasPrefix(toolInput, pathPrefix) {
				return false, fmt.Sprintf("path %q matches path_deny prefix %q for layer %q",
					toolInput, pathPrefix, string(lyr))
			}
		}
	}

	// 4. Bash-specific checks.
	if strings.EqualFold(toolName, "Bash") || strings.EqualFold(toolName, "mcp__bash__run_command") {
		// 4a. Deny substrings (always checked, highest precedence within Bash).
		for _, sub := range rules.BashDenySubstrings {
			if strings.Contains(toolInput, sub) {
				return false, fmt.Sprintf("bash command contains denied substring %q for layer %q",
					sub, string(lyr))
			}
		}

		// 4b. Allow prefix whitelist: if non-empty, the command must match one.
		if len(rules.BashAllowPrefixes) > 0 {
			matched := false
			for _, pfx := range rules.BashAllowPrefixes {
				// Strip trailing wildcard for prefix matching.
				cleanPfx := strings.TrimSuffix(pfx, "*")
				cleanPfx = strings.TrimRight(cleanPfx, " ")
				if strings.HasPrefix(toolInput, cleanPfx) {
					matched = true
					break
				}
			}
			if !matched {
				return false, fmt.Sprintf("bash command does not match any bash_allow_prefixes for layer %q",
					string(lyr))
			}
		}
	}

	return true, ""
}

// isFileTool reports whether the tool name operates on file paths.
func isFileTool(tool string) bool {
	switch strings.ToLower(tool) {
	case "edit", "write", "read":
		return true
	}
	return false
}
