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
	"path/filepath"
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
	Block         bool   `json:"block"`
	Reason        string `json:"reason"`
	Code          string `json:"code,omitempty"`
	VerdictSource string `json:"verdict_source,omitempty"`
}

// emit writes the verdict envelope to w. Errors are silently swallowed because
// a write failure to stdout cannot be meaningfully reported to the hook runner.
func emit(w io.Writer, block bool, reason, code, source string) {
	env := verdictEnvelope{Block: block, Reason: reason, Code: code, VerdictSource: source}
	_ = json.NewEncoder(w).Encode(env)
}

// EmitLayerVerdict writes the shared layer verdict shape for app-level command
// parsing failures that cannot reach RunLayerDecide.
func EmitLayerVerdict(w io.Writer, block bool, reason string) {
	emit(w, block, reason, "", "")
}

// RunLayerGuard implements `furrow hook layer-guard`. It reads a PreToolUse
// JSON payload from in, evaluates it against the canonical layer policy, and
// writes a verdict envelope to out. Block reasons are also mirrored to errOut
// for hook runtimes that surface stderr to the operator.
//
// Exit codes (Claude hook protocol):
//   - 0 → allow (may emit empty stdout)
//   - 2 → block (must emit JSON verdict to stdout)
func RunLayerGuard(_ context.Context, policyPath string, in io.Reader, out, errOut io.Writer) int {
	var ev hookInput
	if err := json.NewDecoder(in).Decode(&ev); err != nil {
		emitBlock(out, errOut, "layer_guard: malformed hook payload: "+err.Error(), "layer_guard_payload_invalid", "payload-parse-failure")
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

	return RunLayerDecide(context.Background(), policyPath, toolEvent, out, errOut)
}

// RunLayerDecide applies the layer policy to a normalized Furrow ToolEvent.
func RunLayerDecide(_ context.Context, policyPath string, ev layer.ToolEvent, out, errOut io.Writer) int {
	pol, err := layer.Load(policyPath)
	if err != nil {
		reason := fmt.Sprintf("layer_policy_invalid: %s", err.Error())
		if isPolicyLoadRecoveryEdit(ev, policyPath) {
			_, _ = fmt.Fprintf(errOut, "layer-guard recovery allow: %s\n", reason)
			return 0
		}
		emitBlock(out, errOut, reason, "layer_policy_invalid", "policy-load-failure")
		return 2
	}

	slog.Debug("layer-guard decision",
		"agent_type", ev.AgentType,
		"tool_name", ev.ToolName,
	)

	verdict := pol.DecideEvent(ev)
	if verdict.Block {
		emitBlock(out, errOut, verdict.Reason, "layer_tool_violation", "policy-decision-block")
		return 2
	}

	return 0
}

func emitBlock(out, errOut io.Writer, reason, code, source string) {
	emit(out, true, reason, code, source)
	if reason != "" {
		_, _ = fmt.Fprintln(errOut, reason)
	}
}

func isPolicyLoadRecoveryEdit(ev layer.ToolEvent, policyPath string) bool {
	if !strings.EqualFold(ev.ToolName, "Edit") {
		return false
	}
	target := normalizeRecoveryPath(layer.FlattenToolInput(ev.ToolName, ev.ToolInput), policyPath)
	if target == "" {
		return false
	}
	return target == ".furrow/layer-policy.yaml" ||
		strings.HasPrefix(target, "internal/cli/") ||
		strings.HasPrefix(target, "schemas/")
}

func normalizeRecoveryPath(path, policyPath string) string {
	path = strings.TrimSpace(strings.TrimPrefix(path, "@"))
	if path == "" {
		return ""
	}
	if filepath.IsAbs(path) {
		root := filepath.Dir(filepath.Dir(policyPath))
		if rel, err := filepath.Rel(root, path); err == nil && !strings.HasPrefix(rel, "..") {
			path = rel
		}
	}
	path = filepath.ToSlash(filepath.Clean(path))
	path = strings.TrimPrefix(path, "./")
	return path
}
