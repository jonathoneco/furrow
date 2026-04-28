package layer_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jonathoneco/furrow/internal/cli/layer"
)

// minimalValidYAML returns a minimal valid layer-policy.yaml for tests that
// don't need the full canonical policy.
func minimalValidYAML() string {
	return `
version: "1"
agent_type_map:
  operator: operator
  driver:plan: driver
  engine:freeform: engine
layers:
  operator:
    tools_allow: ["*"]
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []
  driver:
    tools_allow: ["Read", "Grep", "Glob", "Bash", "SendMessage", "Agent", "Edit", "Write", "NotebookEdit"]
    tools_deny:  []
    path_deny: []
    bash_allow_prefixes:
      - "rws "
      - "furrow "
    bash_deny_substrings:
      - " > "
      - "rm -"
  engine:
    tools_allow: ["Read", "Grep", "Glob", "Edit", "Write", "Bash", "SendMessage", "Agent", "TaskCreate", "TaskGet", "TaskList", "TaskUpdate"]
    tools_deny:  []
    path_deny:
      - ".furrow/"
    bash_allow_prefixes: []
    bash_deny_substrings:
      - "furrow "
      - "rws "
      - ".furrow/"
`
}

func writeTempPolicy(t *testing.T, content string) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "layer-policy.yaml")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatalf("write temp policy: %v", err)
	}
	return path
}

// ---------------------------------------------------------------------------
// Load tests
// ---------------------------------------------------------------------------

func TestLoad_ValidPolicy(t *testing.T) {
	path := writeTempPolicy(t, minimalValidYAML())
	pol, err := layer.Load(path)
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if pol == nil {
		t.Fatal("Load returned nil policy")
	}
	if pol.Version == "" {
		t.Error("Policy.Version is empty")
	}
}

func TestLoad_MissingFile(t *testing.T) {
	_, err := layer.Load("/nonexistent/layer-policy.yaml")
	if err == nil {
		t.Fatal("expected error for missing file, got nil")
	}
	if !strings.Contains(err.Error(), "layer_policy_invalid") {
		t.Errorf("error should mention layer_policy_invalid; got: %v", err)
	}
}

func TestLoad_MalformedYAML(t *testing.T) {
	path := writeTempPolicy(t, "version: [not: valid: yaml}}")
	_, err := layer.Load(path)
	if err == nil {
		t.Fatal("expected error for malformed YAML, got nil")
	}
}

func TestLoad_MissingVersion(t *testing.T) {
	yaml := strings.ReplaceAll(minimalValidYAML(), `version: "1"`, "")
	path := writeTempPolicy(t, yaml)
	_, err := layer.Load(path)
	if err == nil {
		t.Fatal("expected error for missing version, got nil")
	}
	if !strings.Contains(err.Error(), "layer_policy_invalid") {
		t.Errorf("error should mention layer_policy_invalid; got: %v", err)
	}
}

func TestLoad_MissingRequiredLayer(t *testing.T) {
	yaml := `
version: "1"
agent_type_map:
  operator: operator
layers:
  operator:
    tools_allow: ["*"]
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []
`
	path := writeTempPolicy(t, yaml)
	_, err := layer.Load(path)
	if err == nil {
		t.Fatal("expected error for missing driver/engine layers, got nil")
	}
}

// ---------------------------------------------------------------------------
// LookupLayer tests
// ---------------------------------------------------------------------------

func TestLookupLayer(t *testing.T) {
	path := writeTempPolicy(t, minimalValidYAML())
	pol, err := layer.Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}

	tests := []struct {
		name      string
		agentType string
		want      layer.Layer
	}{
		{"empty_is_operator", "", layer.LayerOperator},
		{"explicit_operator", "operator", layer.LayerOperator},
		{"explicit_driver_plan", "driver:plan", layer.LayerDriver},
		{"explicit_engine_freeform", "engine:freeform", layer.LayerEngine},
		{"engine_prefix_fallback", "engine:specialist:go-specialist", layer.LayerEngine},
		{"driver_prefix_fallback", "driver:research", layer.LayerDriver},
		{"unknown_defaults_engine", "totally-unknown-agent", layer.LayerEngine},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := pol.LookupLayer(tc.agentType)
			if got != tc.want {
				t.Errorf("LookupLayer(%q) = %q; want %q", tc.agentType, got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Decide tests — parity fixtures from the spec
// ---------------------------------------------------------------------------

func TestDecide_ParityFixtures(t *testing.T) {
	path := writeTempPolicy(t, minimalValidYAML())
	pol, err := layer.Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}

	tests := []struct {
		name      string
		agentType string
		toolName  string
		toolInput string
		wantAllow bool
	}{
		// Fixture 1: operator Write anything → allow
		{"operator_write_allow", "operator", "Write", "definition.yaml", true},
		// Fixture 2: driver Write → allow (drivers write row artifacts)
		{"driver_write_allow", "driver:plan", "Write", ".furrow/rows/example/definition.yaml", true},
		// Fixture 3: driver Bash rws status → allow
		{"driver_bash_rws_allow", "driver:plan", "Bash", "rws status", true},
		// Fixture 4: driver Bash rm -rf → block (bash_deny_substrings)
		{"driver_bash_rm_block", "driver:plan", "Bash", "rm -rf /tmp/x", false},
		// Fixture 5: engine Write non-furrow file → allow
		{"engine_write_src_allow", "engine:specialist:go-specialist", "Write", "src/foo.go", true},
		// Fixture 6: engine Write .furrow/ path → block (path_deny)
		{"engine_write_furrow_block", "engine:specialist:go-specialist", "Write", ".furrow/learnings.jsonl", false},
		// Fixture 7: engine Bash furrow context → block (bash_deny_substrings)
		{"engine_bash_furrow_block", "engine:specialist:go-specialist", "Bash", "furrow context for-step plan", false},
		// Fixture 8: engine SendMessage → allow (no signal justifies isolation)
		{"engine_sendmessage_allow", "engine:specialist:go-specialist", "SendMessage", "to: subagent_1", true},
		// Fixture 8b: engine Agent → allow (fan-out budget tracked separately)
		{"engine_agent_allow", "engine:specialist:go-specialist", "Agent", "subagent_type: foo", true},
		// Fixture 8c: engine Bash harness CLI → block (real boundary)
		{"engine_bash_harness_cli_block", "engine:specialist:go-specialist", "Bash", "furrow row archive foo", false},
		// Fixture 9: engine:freeform Read → allow
		{"engine_freeform_read_allow", "engine:freeform", "Read", "src/foo.go", true},
		// Fixture 10: missing agent_type (main-thread) Write → allow (operator default)
		{"main_thread_write_allow", "", "Write", "src/foo.go", true},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			lyr := pol.LookupLayer(tc.agentType)
			got, reason := pol.Decide(lyr, tc.toolName, tc.toolInput)
			if got != tc.wantAllow {
				t.Errorf("Decide(layer=%q, tool=%q, input=%q) = allow:%v, reason:%q; want allow:%v",
					string(lyr), tc.toolName, tc.toolInput, got, reason, tc.wantAllow)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Decide — additional unit cases
// ---------------------------------------------------------------------------

func TestDecide_DriverBashRedirectionBlocked(t *testing.T) {
	path := writeTempPolicy(t, minimalValidYAML())
	pol, _ := layer.Load(path)
	allow, reason := pol.Decide(layer.LayerDriver, "Bash", "echo hello > output.txt")
	if allow {
		t.Errorf("expected block for output redirection; got allow (reason: %q)", reason)
	}
}

func TestDecide_OperatorAllToolsAllowed(t *testing.T) {
	path := writeTempPolicy(t, minimalValidYAML())
	pol, _ := layer.Load(path)
	for _, tool := range []string{"Edit", "Write", "Read", "Bash", "Agent", "SendMessage"} {
		allow, reason := pol.Decide(layer.LayerOperator, tool, "anything")
		if !allow {
			t.Errorf("operator should allow %q; got block (reason: %q)", tool, reason)
		}
	}
}

func TestDecide_UnknownLayerDenied(t *testing.T) {
	path := writeTempPolicy(t, minimalValidYAML())
	pol, _ := layer.Load(path)
	allow, _ := pol.Decide("nonexistent-layer", "Write", "foo.go")
	if allow {
		t.Error("unknown layer should be denied (fail-closed)")
	}
}
