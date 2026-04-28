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

// EmitLayerVerdict writes the shared layer verdict shape for app-level command
// parsing failures that cannot reach RunLayerDecide.
func EmitLayerVerdict(w io.Writer, block bool, reason string) {
	emit(w, block, reason)
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

	toolEvent := layer.ToolEvent{
		SchemaVersion: "tool_event.v1",
		Runtime:       "claude",
		EventName:     ev.HookEventName,
		ToolName:      ev.ToolName,
		ToolInput:     ev.ToolInput,
		AgentID:       ev.AgentID,
		AgentType:     ev.AgentType,
	}

	return RunLayerDecide(context.Background(), policyPath, toolEvent, out)
}

// RunLayerDecide applies the layer policy to a normalized Furrow ToolEvent.
func RunLayerDecide(_ context.Context, policyPath string, ev layer.ToolEvent, out io.Writer) int {
	pol, err := layer.Load(policyPath)
	if err != nil {
		emit(out, true, fmt.Sprintf("layer_policy_invalid: %s", err.Error()))
		return 2
	}

	slog.Debug("layer-guard decision",
		"agent_type", ev.AgentType,
		"tool_name", ev.ToolName,
	)

	verdict := pol.DecideEvent(ev)
	if verdict.Block {
		emit(out, true, verdict.Reason)
		return 2
	}

	return 0
}
