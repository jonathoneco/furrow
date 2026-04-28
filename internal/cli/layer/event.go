package layer

import (
	"encoding/json"
	"fmt"
	"strings"
)

// ToolEvent is Furrow's runtime-neutral tool-call event. Adapters translate
// their native hook payloads into this shape before asking the backend for a
// layer-policy decision.
type ToolEvent struct {
	SchemaVersion string          `json:"schema_version,omitempty"`
	Runtime       string          `json:"runtime,omitempty"`
	EventName     string          `json:"event_name,omitempty"`
	ToolName      string          `json:"tool_name"`
	ToolInput     json.RawMessage `json:"tool_input"`
	AgentID       string          `json:"agent_id,omitempty"`
	AgentType     string          `json:"agent_type,omitempty"`
}

// Verdict is the normalized backend decision returned by layer decision paths.
type Verdict struct {
	Block  bool   `json:"block"`
	Reason string `json:"reason"`
}

// DecideEvent applies the policy to a normalized tool event.
func (p *Policy) DecideEvent(ev ToolEvent) Verdict {
	lyr := p.LookupLayer(ev.AgentType)
	flat := FlattenToolInput(ev.ToolName, ev.ToolInput)
	allow, reason := p.Decide(lyr, ev.ToolName, flat)
	if allow {
		return Verdict{Block: false}
	}
	return Verdict{
		Block:  true,
		Reason: fmt.Sprintf("layer_tool_violation: %s in layer %s: %s", ev.ToolName, string(lyr), reason),
	}
}

// FlattenToolInput extracts the value most relevant for policy checks.
func FlattenToolInput(toolName string, raw json.RawMessage) string {
	if len(raw) == 0 {
		return ""
	}

	var m map[string]json.RawMessage
	if err := json.Unmarshal(raw, &m); err != nil {
		return string(raw)
	}

	switch strings.ToLower(toolName) {
	case "edit", "write", "read", "multiedit":
		if fp, ok := firstRaw(m, "file_path", "path"); ok {
			return unquoteJSONString(fp)
		}
	case "bash", "mcp__bash__run_command":
		if cmd, ok := firstRaw(m, "command", "cmd"); ok {
			return unquoteJSONString(cmd)
		}
	case "sendmessage":
		if body, ok := m["body"]; ok {
			return unquoteJSONString(body)
		}
	}

	var parts []string
	for _, v := range m {
		parts = append(parts, unquoteJSONString(v))
	}
	return strings.Join(parts, " ")
}

func firstRaw(m map[string]json.RawMessage, keys ...string) (json.RawMessage, bool) {
	for _, key := range keys {
		if raw, ok := m[key]; ok {
			return raw, true
		}
	}
	return nil, false
}

func unquoteJSONString(raw json.RawMessage) string {
	var s string
	if err := json.Unmarshal(raw, &s); err == nil {
		return s
	}
	return string(raw)
}
