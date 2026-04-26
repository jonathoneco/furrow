// Package hook provides Go subcommand implementations for Furrow's hook
// integration points (PreToolUse, etc.) that are registered via app.go and
// wired into both the Claude and Pi adapters.
package hook

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"strings"

	"github.com/jonathoneco/furrow/internal/cli/layer"
)

// hookInput is the canonical PreToolUse JSON payload shape — shared between
// Claude's PreToolUse hook and the Pi adapter's tool_call normalization.
type hookInput struct {
	SessionID     string `json:"session_id"`
	HookEventName string `json:"hook_event_name"`
	ToolName      string `json:"tool_name"`
	// ToolInput is the raw JSON tool arguments. Stored as json.RawMessage so
	// we can flatten it to a string for substring matching without
	// unmarshalling into a fixed struct (tool schemas vary widely).
	ToolInput json.RawMessage `json:"tool_input"`
	AgentID   string          `json:"agent_id"`
	AgentType string          `json:"agent_type"`
}

// verdictEnvelope is the stdout JSON returned to the Claude hook runtime.
// Exit code 0 + empty stdout = allow; exit code 2 + this envelope = block.
type verdictEnvelope struct {
	Block  bool   `json:"block"`
	Reason string `json:"reason"`
}

// emit writes the verdict envelope to w. Errors are silently swallowed because
// a write failure to stdout cannot be meaningfully reported to the hook runner.
func emit(w io.Writer, block bool, reason string) {
	env := verdictEnvelope{Block: block, Reason: reason}
	_ = json.NewEncoder(w).Encode(env)
}

// RunLayerGuard implements `furrow hook layer-guard`. It reads a PreToolUse
// JSON payload from in, evaluates it against the canonical layer policy, and
// writes a verdict envelope to out.
//
// Exit codes (Claude hook protocol):
//   - 0 → allow (may emit empty stdout)
//   - 2 → block (must emit JSON verdict to stdout)
func RunLayerGuard(_ context.Context, policyPath string, in io.Reader, out io.Writer) int {
	var ev hookInput
	if err := json.NewDecoder(in).Decode(&ev); err != nil {
		emit(out, true, "layer_guard: malformed hook payload: "+err.Error())
		return 2
	}

	pol, err := layer.Load(policyPath)
	if err != nil {
		emit(out, true, fmt.Sprintf("layer_policy_invalid: %s", err.Error()))
		return 2
	}

	lyr := pol.LookupLayer(ev.AgentType)

	// Flatten tool_input to a string for substring/prefix checks.
	flat := flattenToolInput(ev.ToolName, ev.ToolInput)

	slog.Debug("layer-guard decision",
		"agent_type", ev.AgentType,
		"layer", string(lyr),
		"tool_name", ev.ToolName,
		"flattened_input", flat,
	)

	allow, reason := pol.Decide(lyr, ev.ToolName, flat)
	if !allow {
		msg := fmt.Sprintf("layer_tool_violation: %s in layer %s: %s",
			ev.ToolName, string(lyr), reason)
		emit(out, true, msg)
		return 2
	}

	// Allow: exit 0, no output required (Claude interprets empty stdout as allow).
	return 0
}

// flattenToolInput extracts the key value from tool_input that is most relevant
// for policy checks. Different tools embed their target in different fields:
//
//   - Edit/Write/Read  → file_path
//   - Bash             → command
//   - SendMessage      → body (or full JSON if not found)
//   - Others           → full JSON string
//
// The flattened string is used only for substring/prefix matching, so
// over-inclusion is safe (may cause more false positives but never false negatives).
func flattenToolInput(toolName string, raw json.RawMessage) string {
	if len(raw) == 0 {
		return ""
	}

	var m map[string]json.RawMessage
	if err := json.Unmarshal(raw, &m); err != nil {
		// Not an object — return raw bytes as string.
		return string(raw)
	}

	switch strings.ToLower(toolName) {
	case "edit", "write", "read", "multiedit":
		if fp, ok := m["file_path"]; ok {
			return unquoteJSONString(fp)
		}
	case "bash", "mcp__bash__run_command":
		if cmd, ok := m["command"]; ok {
			return unquoteJSONString(cmd)
		}
	case "sendmessage":
		if body, ok := m["body"]; ok {
			return unquoteJSONString(body)
		}
	}

	// Fallback: join all string-valued fields.
	var parts []string
	for _, v := range m {
		parts = append(parts, unquoteJSONString(v))
	}
	return strings.Join(parts, " ")
}

// unquoteJSONString strips surrounding JSON quotes from a raw JSON value.
// If the value is not a JSON string, the raw bytes are returned as-is.
func unquoteJSONString(raw json.RawMessage) string {
	var s string
	if err := json.Unmarshal(raw, &s); err == nil {
		return s
	}
	return string(raw)
}
