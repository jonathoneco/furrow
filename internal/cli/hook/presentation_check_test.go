package hook_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jonathoneco/furrow/internal/cli/hook"
)

// writeTranscript writes a single-line JSONL transcript to a temp file and
// returns the path.
func writeTranscript(t *testing.T, content string) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "transcript.jsonl")

	// Build a Claude-style assistant message line.
	msg := map[string]any{
		"type": "message",
		"message": map[string]any{
			"role":    "assistant",
			"content": content,
		},
	}
	b, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("marshal transcript line: %v", err)
	}
	if err := os.WriteFile(path, append(b, '\n'), 0o600); err != nil {
		t.Fatalf("write transcript: %v", err)
	}
	return path
}

// buildStopInput returns a JSON-encoded StopInput for the given transcript
// path and agent type.
func buildStopInput(t *testing.T, transcriptPath, agentType string) []byte {
	t.Helper()
	m := map[string]any{
		"session_id":       "test-session",
		"stop_hook_active": true,
		"transcript_path":  transcriptPath,
		"hook_event_name":  "Stop",
		"agent_type":       agentType,
	}
	b, err := json.Marshal(m)
	if err != nil {
		t.Fatalf("marshal stop input: %v", err)
	}
	return b
}

// run runs RunPresentationCheck with the given stdin bytes.
func runPresentationCheck(t *testing.T, stdin []byte) (stdout string, exitCode int) {
	t.Helper()
	var out bytes.Buffer
	code := hook.RunPresentationCheck(context.Background(), bytes.NewReader(stdin), &out)
	return out.String(), code
}

func TestRunPresentationCheck_AlwaysExitsZero(t *testing.T) {
	// Even with malformed input the hook must exit 0.
	_, code := runPresentationCheck(t, []byte(`not-json`))
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
}

func TestRunPresentationCheck_ArtifactPathWithoutMarker_EmitsViolation(t *testing.T) {
	body := "Here is the definition:\n.furrow/rows/my-row/definition.yaml\nPlease review."
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "operator")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}

	var env map[string]any
	if err := json.Unmarshal([]byte(strings.TrimSpace(out)), &env); err != nil {
		t.Fatalf("parse output envelope: %v (raw: %q)", err, out)
	}
	if env["code"] != "presentation_protocol_violation" {
		t.Errorf("expected code presentation_protocol_violation, got %q", env["code"])
	}
	if env["severity"] != "warn" {
		t.Errorf("expected severity warn, got %q", env["severity"])
	}
	if env["confirmation_path"] != "silent" {
		t.Errorf("expected confirmation_path silent, got %q", env["confirmation_path"])
	}
}

func TestRunPresentationCheck_ArtifactPathWithMarker_NoEmission(t *testing.T) {
	body := "Here is the definition:\n\n<!-- presentation:section:objective -->\n\n.furrow/rows/my-row/definition.yaml\n\nPlease review."
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "operator")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	if strings.TrimSpace(out) != "" {
		t.Errorf("expected empty output (no violation), got %q", out)
	}
}

func TestRunPresentationCheck_LongFencedBlockArtifact_EmitsViolation(t *testing.T) {
	// Build a long fenced YAML block that looks like a definition.yaml.
	var sb strings.Builder
	sb.WriteString("```yaml\n")
	sb.WriteString("objective: test the artifact presentation protocol\n")
	sb.WriteString("deliverables:\n")
	for i := 0; i < 35; i++ {
		sb.WriteString(fmt.Sprintf("  - name: item-%d\n", i))
	}
	sb.WriteString("gate_policy: supervised\n")
	sb.WriteString("```\n")

	body := "Here is the row artifact:\n" + sb.String()
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "operator")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	// Should emit violation because no marker precedes the fenced block.
	if strings.TrimSpace(out) == "" {
		t.Error("expected violation emission for long artifact fenced block without marker")
	}
	var env map[string]any
	if err := json.Unmarshal([]byte(strings.TrimSpace(out)), &env); err != nil {
		t.Fatalf("parse output: %v", err)
	}
	if env["code"] != "presentation_protocol_violation" {
		t.Errorf("expected presentation_protocol_violation, got %q", env["code"])
	}
}

func TestRunPresentationCheck_LongFencedBlockWithMarker_NoEmission(t *testing.T) {
	var sb strings.Builder
	sb.WriteString("<!-- presentation:section:objective -->\n\n")
	sb.WriteString("```yaml\n")
	sb.WriteString("objective: test the artifact presentation protocol\n")
	sb.WriteString("deliverables:\n")
	for i := 0; i < 35; i++ {
		sb.WriteString(fmt.Sprintf("  - name: item-%d\n", i))
	}
	sb.WriteString("gate_policy: supervised\n")
	sb.WriteString("```\n")

	body := "Here is the artifact:\n" + sb.String()
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "operator")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	if strings.TrimSpace(out) != "" {
		t.Errorf("expected no violation when marker precedes fenced block, got %q", out)
	}
}

func TestRunPresentationCheck_EngineTurnSkipped(t *testing.T) {
	// engine:* turns are skipped entirely even if they contain artifact content.
	body := ".furrow/rows/my-row/definition.yaml"
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "engine:specialist:go-specialist")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	if strings.TrimSpace(out) != "" {
		t.Errorf("engine turns should not emit violations, got %q", out)
	}
}

func TestRunPresentationCheck_DriverTurnScanned(t *testing.T) {
	// driver:* turns are scanned (drivers shouldn't render artifacts to user).
	body := ".furrow/rows/my-row/plan.json"
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "driver:plan")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	// Should emit violation because driver rendered artifact path without marker.
	if strings.TrimSpace(out) == "" {
		t.Error("expected violation for driver turn with artifact path and no marker")
	}
}

func TestRunPresentationCheck_NoArtifactContent_NoEmission(t *testing.T) {
	body := "The plan looks good. Let me proceed with the implementation."
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "operator")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	if strings.TrimSpace(out) != "" {
		t.Errorf("expected no emission for non-artifact content, got %q", out)
	}
}

func TestRunPresentationCheck_ShortFencedBlockNotFlagged(t *testing.T) {
	// A fenced block under 30 lines should not trigger the artifact heuristic.
	body := "Here is a short snippet:\n```yaml\nfoo: bar\nbaz: qux\n```\n"
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "operator")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	if strings.TrimSpace(out) != "" {
		t.Errorf("expected no violation for short fenced block, got %q", out)
	}
}

func TestRunPresentationCheck_EmptyTranscriptPath_NoEmission(t *testing.T) {
	stdin := buildStopInput(t, "", "operator")
	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	if strings.TrimSpace(out) != "" {
		t.Errorf("expected no emission when transcript_path empty, got %q", out)
	}
}

func TestRunPresentationCheck_MalformedJSON_ExitsZero(t *testing.T) {
	_, code := runPresentationCheck(t, []byte(`{"unclosed`))
	if code != 0 {
		t.Errorf("expected exit 0 even for malformed JSON, got %d", code)
	}
}

func TestRunPresentationCheck_MultipleArtifactPaths_FirstViolation(t *testing.T) {
	body := "First artifact: .furrow/rows/row-a/definition.yaml\n\nSecond artifact: .furrow/rows/row-b/plan.json"
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "operator")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	if strings.TrimSpace(out) == "" {
		t.Error("expected violation for artifact paths without markers")
	}
}

func TestRunPresentationCheck_UnknownAgentTypeSkipped(t *testing.T) {
	// An unknown non-empty agent_type that is not "operator" or "driver:*" is skipped.
	body := ".furrow/rows/my-row/definition.yaml"
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "unknown:type")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	if strings.TrimSpace(out) != "" {
		t.Errorf("unknown agent type should not emit violation, got %q", out)
	}
}

func TestRunPresentationCheck_EmptyAgentType_OperatorDefault(t *testing.T) {
	// Empty agent_type (agent_type="") defaults to operator-equivalent scan.
	body := ".furrow/rows/my-row/spec.md"
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "")

	out, code := runPresentationCheck(t, stdin)
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	// Empty agent type is not excluded so should be scanned.
	if strings.TrimSpace(out) == "" {
		t.Error("expected violation for empty agent_type with artifact path and no marker")
	}
}

func TestRunPresentationCheck_EnvelopeSchema(t *testing.T) {
	// Verify the envelope has all required fields with correct values.
	body := ".furrow/rows/my-row/summary.md"
	transcript := writeTranscript(t, body)
	stdin := buildStopInput(t, transcript, "operator")

	out, _ := runPresentationCheck(t, stdin)
	if strings.TrimSpace(out) == "" {
		t.Fatal("expected violation envelope, got empty output")
	}

	var env map[string]any
	if err := json.Unmarshal([]byte(strings.TrimSpace(out)), &env); err != nil {
		t.Fatalf("envelope not valid JSON: %v", err)
	}

	required := []string{"code", "category", "severity", "message", "remediation_hint", "confirmation_path"}
	for _, field := range required {
		if _, ok := env[field]; !ok {
			t.Errorf("envelope missing required field %q", field)
		}
	}
	if env["code"] != "presentation_protocol_violation" {
		t.Errorf("code = %q, want presentation_protocol_violation", env["code"])
	}
	if env["category"] != "presentation" {
		t.Errorf("category = %q, want presentation", env["category"])
	}
	if env["severity"] != "warn" {
		t.Errorf("severity = %q, want warn", env["severity"])
	}
	if env["confirmation_path"] != "silent" {
		t.Errorf("confirmation_path = %q, want silent", env["confirmation_path"])
	}
}
