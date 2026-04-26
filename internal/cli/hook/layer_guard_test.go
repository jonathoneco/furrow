package hook_test

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jonathoneco/furrow/internal/cli/hook"
)

// writePolicy writes a layer-policy.yaml to a temp dir and returns the path.
func writePolicy(t *testing.T, content string) string {
	t.Helper()
	dir := t.TempDir()

	// Create .furrow/layer-policy.yaml structure.
	furrowDir := filepath.Join(dir, ".furrow")
	if err := os.MkdirAll(furrowDir, 0o755); err != nil {
		t.Fatalf("mkdir .furrow: %v", err)
	}

	policyPath := filepath.Join(furrowDir, "layer-policy.yaml")
	if err := os.WriteFile(policyPath, []byte(content), 0o600); err != nil {
		t.Fatalf("write policy: %v", err)
	}
	return policyPath
}

const testPolicy = `
version: "1"
agent_type_map:
  operator: operator
  driver:plan: driver
  driver:research: driver
  driver:ideate: driver
  driver:spec: driver
  driver:decompose: driver
  driver:implement: driver
  driver:review: driver
  engine:freeform: engine
layers:
  operator:
    tools_allow: ["*"]
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []
  driver:
    tools_allow: ["Read", "Grep", "Glob", "Bash", "SendMessage", "Agent", "TaskCreate", "TaskGet", "TaskList", "TaskUpdate"]
    tools_deny: ["Edit", "Write", "NotebookEdit"]
    path_deny: []
    bash_allow_prefixes:
      - "rws "
      - "alm "
      - "sds "
      - "furrow context "
      - "furrow handoff render"
      - "furrow validate "
      - "go test "
    bash_deny_substrings:
      - " > "
      - " >> "
      - "rm -"
      - "git commit"
  engine:
    tools_allow: ["Read", "Grep", "Glob", "Edit", "Write", "Bash"]
    tools_deny: ["SendMessage", "Agent", "TaskCreate"]
    path_deny:
      - ".furrow/"
      - "schemas/blocker-taxonomy.yaml"
    bash_allow_prefixes: []
    bash_deny_substrings:
      - "furrow "
      - "rws "
      - "alm "
      - "sds "
      - ".furrow/"
`

// buildPayload creates a hook input JSON string.
func buildPayload(agentType, toolName string, toolInput any) string {
	ti, _ := json.Marshal(toolInput)
	payload := map[string]any{
		"session_id":      "test-session",
		"hook_event_name": "PreToolUse",
		"tool_name":       toolName,
		"tool_input":      json.RawMessage(ti),
		"agent_id":        "agent-1",
		"agent_type":      agentType,
	}
	data, _ := json.Marshal(payload)
	return string(data)
}

// ---------------------------------------------------------------------------
// Table-driven tests covering all 10 parity fixtures plus extras
// ---------------------------------------------------------------------------

func TestRunLayerGuard(t *testing.T) {
	policyPath := writePolicy(t, testPolicy)

	tests := []struct {
		name      string
		agentType string
		toolName  string
		toolInput any
		wantExit  int // 0=allow, 2=block
	}{
		// Parity fixture 1: operator Write → allow
		{
			name:      "fixture1_operator_write_allow",
			agentType: "operator",
			toolName:  "Write",
			toolInput: map[string]string{"file_path": "definition.yaml"},
			wantExit:  0,
		},
		// Parity fixture 2: driver:plan Write → block (tools_deny)
		{
			name:      "fixture2_driver_write_block",
			agentType: "driver:plan",
			toolName:  "Write",
			toolInput: map[string]string{"file_path": "plan.json"},
			wantExit:  2,
		},
		// Parity fixture 3: driver:plan Bash rws status → allow
		{
			name:      "fixture3_driver_bash_rws_allow",
			agentType: "driver:plan",
			toolName:  "Bash",
			toolInput: map[string]string{"command": "rws status"},
			wantExit:  0,
		},
		// Parity fixture 4: driver:plan Bash rm -rf → block
		{
			name:      "fixture4_driver_bash_rm_block",
			agentType: "driver:plan",
			toolName:  "Bash",
			toolInput: map[string]string{"command": "rm -rf /tmp/x"},
			wantExit:  2,
		},
		// Parity fixture 5: engine Write src/foo.go → allow
		{
			name:      "fixture5_engine_write_src_allow",
			agentType: "engine:specialist:go-specialist",
			toolName:  "Write",
			toolInput: map[string]string{"file_path": "src/foo.go"},
			wantExit:  0,
		},
		// Parity fixture 6: engine Write .furrow/ → block (path_deny)
		{
			name:      "fixture6_engine_write_furrow_block",
			agentType: "engine:specialist:go-specialist",
			toolName:  "Write",
			toolInput: map[string]string{"file_path": ".furrow/learnings.jsonl"},
			wantExit:  2,
		},
		// Parity fixture 7: engine Bash furrow context → block (bash_deny_substrings)
		{
			name:      "fixture7_engine_bash_furrow_block",
			agentType: "engine:specialist:go-specialist",
			toolName:  "Bash",
			toolInput: map[string]string{"command": "furrow context for-step plan"},
			wantExit:  2,
		},
		// Parity fixture 8: engine SendMessage → block (tools_deny)
		{
			name:      "fixture8_engine_sendmessage_block",
			agentType: "engine:specialist:go-specialist",
			toolName:  "SendMessage",
			toolInput: map[string]string{"to": "subagent_1", "body": "hello"},
			wantExit:  2,
		},
		// Parity fixture 9: engine:freeform Read → allow
		{
			name:      "fixture9_engine_freeform_read_allow",
			agentType: "engine:freeform",
			toolName:  "Read",
			toolInput: map[string]string{"file_path": "src/foo.go"},
			wantExit:  0,
		},
		// Parity fixture 10: missing agent_type (main-thread) → operator → Write allow
		{
			name:      "fixture10_main_thread_write_allow",
			agentType: "",
			toolName:  "Write",
			toolInput: map[string]string{"file_path": "src/foo.go"},
			wantExit:  0,
		},
		// Extra: driver Edit → block
		{
			name:      "driver_edit_block",
			agentType: "driver:research",
			toolName:  "Edit",
			toolInput: map[string]string{"file_path": "src/foo.go"},
			wantExit:  2,
		},
		// Extra: engine Bash rws → block
		{
			name:      "engine_bash_rws_block",
			agentType: "engine:specialist:go-specialist",
			toolName:  "Bash",
			toolInput: map[string]string{"command": "rws transition my-row plan pass auto '{}'"},
			wantExit:  2,
		},
		// Extra: engine Read non-furrow file → allow
		{
			name:      "engine_read_allow",
			agentType: "engine:specialist:go-specialist",
			toolName:  "Read",
			toolInput: map[string]string{"file_path": "internal/cli/app.go"},
			wantExit:  0,
		},
		// Extra: unknown agent_type → engine → Write .furrow/ → block
		{
			name:      "unknown_agent_engine_fallback_block",
			agentType: "rogue-agent-xyz",
			toolName:  "Write",
			toolInput: map[string]string{"file_path": ".furrow/state.json"},
			wantExit:  2,
		},
		// Extra: driver bash output redirection → block
		{
			name:      "driver_bash_redirect_block",
			agentType: "driver:implement",
			toolName:  "Bash",
			toolInput: map[string]string{"command": "echo hello > out.txt"},
			wantExit:  2,
		},
		// Extra: driver bash git commit → block
		{
			name:      "driver_bash_git_commit_block",
			agentType: "driver:implement",
			toolName:  "Bash",
			toolInput: map[string]string{"command": "git commit -m 'foo'"},
			wantExit:  2,
		},
		// Extra: operator Read anything → allow (wildcard)
		{
			name:      "operator_read_furrow_allow",
			agentType: "operator",
			toolName:  "Read",
			toolInput: map[string]string{"file_path": ".furrow/state.json"},
			wantExit:  0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			payload := buildPayload(tc.agentType, tc.toolName, tc.toolInput)
			in := strings.NewReader(payload)
			var out bytes.Buffer
			got := hook.RunLayerGuard(context.Background(), policyPath, in, &out)
			if got != tc.wantExit {
				t.Errorf("RunLayerGuard exit = %d; want %d\n  payload: %s\n  stdout: %s",
					got, tc.wantExit, payload, out.String())
			}
			if got == 2 {
				// Verify the block envelope is valid JSON with block=true.
				var env map[string]any
				if err := json.Unmarshal(out.Bytes(), &env); err != nil {
					t.Errorf("exit 2 but stdout is not valid JSON: %v\nstdout: %s", err, out.String())
					return
				}
				if env["block"] != true {
					t.Errorf("exit 2 but block field is not true: %v", env)
				}
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Edge cases
// ---------------------------------------------------------------------------

func TestRunLayerGuard_MalformedPayload(t *testing.T) {
	policyPath := writePolicy(t, testPolicy)
	in := strings.NewReader("not json at all {{{")
	var out bytes.Buffer
	exit := hook.RunLayerGuard(context.Background(), policyPath, in, &out)
	if exit != 2 {
		t.Errorf("malformed payload should exit 2; got %d", exit)
	}
}

func TestRunLayerGuard_MissingPolicyFile(t *testing.T) {
	in := strings.NewReader(buildPayload("driver:plan", "Write", map[string]string{"file_path": "x"}))
	var out bytes.Buffer
	exit := hook.RunLayerGuard(context.Background(), "/nonexistent/.furrow/layer-policy.yaml", in, &out)
	if exit != 2 {
		t.Errorf("missing policy should exit 2; got %d", exit)
	}
	if !strings.Contains(out.String(), "layer_policy_invalid") {
		t.Errorf("expected layer_policy_invalid in output; got: %s", out.String())
	}
}
