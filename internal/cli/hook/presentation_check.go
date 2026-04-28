package hook

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"regexp"
	"strings"
)

// stopInput is the Claude Stop-hook JSON payload shape.
// agent_type distinguishes operator from driver:* from engine:* turns.
type stopInput struct {
	SessionID      string `json:"session_id"`
	StopHookActive bool   `json:"stop_hook_active"`
	TranscriptPath string `json:"transcript_path"`
	HookEventName  string `json:"hook_event_name"`
	AgentID        string `json:"agent_id,omitempty"`
	AgentType      string `json:"agent_type,omitempty"`
}

// PresentationEvent is Furrow's runtime-neutral presentation scan event.
// Runtime adapters own transcript/message extraction and pass only the text
// that the backend scanner should evaluate.
type PresentationEvent struct {
	SchemaVersion string `json:"schema_version,omitempty"`
	Runtime       string `json:"runtime,omitempty"`
	EventName     string `json:"event_name,omitempty"`
	AgentID       string `json:"agent_id,omitempty"`
	AgentType     string `json:"agent_type,omitempty"`
	Text          string `json:"text"`
	Source        string `json:"source,omitempty"`
}

// transcriptLine is a single JSONL line from the Claude transcript.
type transcriptLine struct {
	Type    string `json:"type"`
	Role    string `json:"role"`
	Content any    `json:"content"`
	// message wrapper shape
	Message *transcriptMessage `json:"message,omitempty"`
}

type transcriptMessage struct {
	Role    string `json:"role"`
	Content any    `json:"content"`
}

// artifactPathRE matches .furrow/rows/<name>/<canonical-artifact-path> references in text.
var artifactPathRE = regexp.MustCompile(
	`(?m)\.furrow/rows/[a-z0-9-]+/(definition\.yaml|plan\.json|spec\.md|summary\.md|research\.md|handoffs/[^\s]+\.md)`,
)

// fencedBlockRE matches fenced code blocks of >= 30 lines (multiline+singleline modes).
var fencedBlockRE = regexp.MustCompile(
	"(?ms)^```(?:yaml|json|md|markdown)?\\s*\\n((?:.*\\n){30,})```\\s*$",
)

// artifactHeuristicRE matches the first 200 chars of a fenced block to detect canonical artifact shapes.
var artifactHeuristicRE = regexp.MustCompile(
	`^(objective:|deliverables:|gate_policy:|## Goals|## Non-Goals|## Acceptance|"step":|"row":|"target":\s*"(driver|engine):)`,
)

// markerWindowRE matches a canonical section marker on its own line.
var markerWindowRE = regexp.MustCompile(
	`(?m)^<!--\s*(ideate|research|plan|spec|decompose|implement|review|presentation):section:[a-z][a-z0-9-]*\s*-->\s*$`,
)

// RunPresentationCheck implements `furrow hook presentation-check`.
//
// It reads a Stop-hook JSON payload from in, loads the transcript, and scans
// the final assistant turn for artifact-shaped content that lacks
// <!-- {phase}:section:{name} --> markers. On detection it emits a
// presentation_protocol_violation blocker envelope (severity warn,
// confirmation_path silent) and exits 0 (advisory — never blocks).
//
// Scope: operator turns and driver:* turns are scanned. engine:* turns are
// skipped (engines are Furrow-unaware; output in their sandbox is unrestricted).
//
// Exit codes:
//   - 0 always (advisory hook; never blocks the turn)
func RunPresentationCheck(_ context.Context, in io.Reader, out io.Writer) int {
	var ev stopInput
	if err := json.NewDecoder(in).Decode(&ev); err != nil {
		slog.Warn("presentation-check: malformed stop hook payload", "err", err)
		return 0
	}

	slog.Debug("presentation-check",
		"session_id", ev.SessionID,
		"agent_type", ev.AgentType,
		"transcript_path", ev.TranscriptPath,
	)

	if ev.TranscriptPath == "" {
		slog.Debug("presentation-check: no transcript_path, skipping")
		return 0
	}

	body, lineNo, err := readLastAssistantTurn(ev.TranscriptPath)
	if err != nil {
		slog.Warn("presentation-check: could not read transcript", "path", ev.TranscriptPath, "err", err)
		return 0
	}

	if body == "" {
		return 0
	}

	return RunPresentationScan(context.Background(), PresentationEvent{
		SchemaVersion: "presentation_event.v1",
		Runtime:       "claude",
		EventName:     ev.HookEventName,
		AgentID:       ev.AgentID,
		AgentType:     ev.AgentType,
		Text:          body,
		Source:        ev.TranscriptPath,
	}, lineNo, out)
}

// RunPresentationScan scans a normalized presentation event. It never blocks
// and returns exit code 0 for both clean and advisory-warning outcomes.
func RunPresentationScan(_ context.Context, ev PresentationEvent, lineOffset int, out io.Writer) int {
	if strings.HasPrefix(ev.AgentType, "engine:") {
		return 0
	}
	if ev.AgentType != "operator" && !strings.HasPrefix(ev.AgentType, "driver:") && ev.AgentType != "" {
		slog.Debug("presentation-scan: skipping non-operator/driver agent type", "agent_type", ev.AgentType)
		return 0
	}
	if ev.Text == "" {
		return 0
	}

	violationLine := detectViolation(ev.Text, lineOffset)
	if violationLine < 0 {
		return 0
	}

	detail := fmt.Sprintf("artifact-shaped content at line %d lacks <!-- {phase}:section:{name} --> marker", violationLine)
	emitPresentationViolation(out, ev.Source, detail)
	return 0
}

// presentationViolationEnvelope is the blocker envelope shape for
// presentation_protocol_violation, matching the BlockerEnvelope schema from
// internal/cli/blocker_envelope.go. The hook package cannot import the parent
// cli package (cycle), so this is kept as a local struct.
type presentationViolationEnvelope struct {
	Code             string `json:"code"`
	Category         string `json:"category"`
	Severity         string `json:"severity"`
	Message          string `json:"message"`
	RemediationHint  string `json:"remediation_hint"`
	ConfirmationPath string `json:"confirmation_path"`
}

// emitPresentationViolation writes a presentation_protocol_violation envelope
// to w (severity warn, confirmation_path silent — advisory, never blocks).
func emitPresentationViolation(w io.Writer, path, detail string) {
	env := presentationViolationEnvelope{
		Code:             "presentation_protocol_violation",
		Category:         "presentation",
		Severity:         "warn",
		Message:          fmt.Sprintf("%s: artifact-shaped content lacks section markers (%s)", path, detail),
		RemediationHint:  "Wrap each artifact section with <!-- {phase}:section:{name} --> per skills/shared/presentation-protocol.md",
		ConfirmationPath: "silent",
	}
	_ = json.NewEncoder(w).Encode(env)
}

// readLastAssistantTurn reads the transcript JSONL at path and returns the
// concatenated text content of the final assistant message, along with the
// approximate line number of that turn in the transcript.
func readLastAssistantTurn(path string) (body string, startLine int, err error) {
	f, err := os.Open(path)
	if err != nil {
		return "", 0, fmt.Errorf("open transcript: %w", err)
	}
	defer f.Close()

	var lastBody string
	var lastLine int
	lineNo := 0

	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 4*1024*1024), 4*1024*1024)
	for scanner.Scan() {
		lineNo++
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}

		var tl transcriptLine
		if err := json.Unmarshal(line, &tl); err != nil {
			continue
		}

		role, content := resolveRoleContent(tl)
		if role != "assistant" {
			continue
		}

		text := extractText(content)
		if text != "" {
			lastBody = text
			lastLine = lineNo
		}
	}
	if serr := scanner.Err(); serr != nil {
		return "", 0, fmt.Errorf("scan transcript: %w", serr)
	}

	return lastBody, lastLine, nil
}

// resolveRoleContent handles both flat transcript lines and message-wrapper shapes.
func resolveRoleContent(tl transcriptLine) (role string, content any) {
	if tl.Role != "" {
		return tl.Role, tl.Content
	}
	if tl.Message != nil {
		return tl.Message.Role, tl.Message.Content
	}
	return "", nil
}

// extractText concatenates text from a content field that is either a plain
// string or a Claude content-block array ([{type:"text",text:"..."},...]).
func extractText(content any) string {
	if content == nil {
		return ""
	}

	switch v := content.(type) {
	case string:
		return v
	case []any:
		var sb strings.Builder
		for _, item := range v {
			m, ok := item.(map[string]any)
			if !ok {
				continue
			}
			if t, ok := m["type"].(string); ok && t == "text" {
				if txt, ok := m["text"].(string); ok {
					sb.WriteString(txt)
				}
			}
		}
		return sb.String()
	default:
		// Try JSON round-trip for other shapes.
		b, err := json.Marshal(content)
		if err == nil {
			return string(b)
		}
		return ""
	}
}

// detectViolation scans body for artifact-shaped content and checks for
// surrounding markers. Returns the line number of the first violation, or -1
// if no violation is found.
//
// lineOffset is the absolute line in the transcript where body starts;
// returned line numbers are relative to body (1-indexed).
func detectViolation(body string, _ int) int {
	lines := strings.Split(body, "\n")

	// Build a set of line indices that have a marker (for fast window lookup).
	markerLines := markerWindowRE.FindAllStringIndex(body, -1)
	markerLineSet := make(map[int]bool)
	for _, loc := range markerLines {
		// Convert byte offset to line number.
		ln := strings.Count(body[:loc[0]], "\n") + 1
		markerLineSet[ln] = true
	}

	// Check 1: artifact path references.
	pathMatches := artifactPathRE.FindAllStringIndex(body, -1)
	for _, loc := range pathMatches {
		matchLine := strings.Count(body[:loc[0]], "\n") + 1
		if !hasMarkerInWindow(markerLineSet, matchLine, 10) {
			return matchLine
		}
	}

	// Check 2: long fenced code blocks that look like canonical artifacts.
	fencedMatches := fencedBlockRE.FindAllStringSubmatchIndex(body, -1)
	for _, loc := range fencedMatches {
		if len(loc) < 4 {
			continue
		}
		captureStart := loc[2]
		captureContent := body[captureStart:]
		if len(captureContent) > 200 {
			captureContent = captureContent[:200]
		}

		if !artifactHeuristicRE.MatchString(captureContent) {
			continue
		}

		matchLine := strings.Count(body[:loc[0]], "\n") + 1
		_ = lines
		if !hasMarkerInWindow(markerLineSet, matchLine, 10) {
			return matchLine
		}
	}

	return -1
}

// hasMarkerInWindow returns true if any marker line falls within [target-window, target].
func hasMarkerInWindow(markerSet map[int]bool, targetLine, window int) bool {
	start := targetLine - window
	if start < 1 {
		start = 1
	}
	for ln := start; ln <= targetLine; ln++ {
		if markerSet[ln] {
			return true
		}
	}
	return false
}
