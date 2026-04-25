package cli

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"sort"
	"strings"
)

// NormalizedEvent matches schemas/blocker-event.schema.json. Adapters
// translate host event payloads (Claude tool_input JSON, git pre-commit
// path lists, etc.) into this shape before passing to `furrow guard`.
type NormalizedEvent struct {
	Version    string         `json:"version"`
	EventType  string         `json:"event_type"`
	TargetPath string         `json:"target_path,omitempty"`
	Step       string         `json:"step,omitempty"`
	Row        string         `json:"row,omitempty"`
	Payload    map[string]any `json:"payload"`
}

// ErrUnknownEventType is returned when the requested event type has no
// registered handler. It's exported so adapter tests can assert on it via
// errors.Is.
var ErrUnknownEventType = errors.New("unknown event type")

// eventHandler is the per-event-type entry point. Handlers receive the
// loaded taxonomy and the normalized event; they return zero or more
// canonical envelopes (empty slice == no trigger). An error indicates an
// invocation problem (missing required payload key, malformed payload),
// not a triggered blocker.
type eventHandler func(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error)

// guardHandlers is the closed handler registry keyed by event_type.
//
// Justification for the package-level map: the handler set is closed at
// compile time (10 entries, one per emit-bearing hook), and the alternative
// (constructor injection of the map into every *App caller) leaks
// implementation detail into every consumer of `Run()`. The drift-guard
// test (TestGuardHandlerRegistryParity) catches missing or extra entries
// against schemas/blocker-event.yaml — registry corruption is impossible
// to ship silently.
var guardHandlers = map[string]eventHandler{
	"pre_write_state_json":       handlePreWriteStateJSON,
	"pre_write_verdict":          handlePreWriteVerdict,
	"pre_write_correction_limit": handlePreWriteCorrectionLimit,
	"pre_bash_internal_script":   handlePreBashInternalScript,
	"pre_commit_bakfiles":        handlePreCommitBakfiles,
	"pre_commit_typechange":      handlePreCommitTypechange,
	"pre_commit_script_modes":    handlePreCommitScriptModes,
	"stop_ideation_completeness": handleStopIdeationCompleteness,
	"stop_summary_validation":    handleStopSummaryValidation,
	"stop_work_check":            handleStopWorkCheck,
}

// guardEventTypes returns the registered event-type names sorted, for
// help text and error messages.
func guardEventTypes() []string {
	names := make([]string, 0, len(guardHandlers))
	for name := range guardHandlers {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

// Guard dispatches a normalized event to the registered handler.
//
// Returns:
//   - (nil, nil)         when the trigger condition is not met. Callers
//     should marshal this as the empty JSON array `[]`.
//   - ([envelope...], nil) when one or more codes fired.
//   - (nil, error)       on invocation errors (unknown event type, missing
//     required payload key, internal loader failures).
func Guard(eventType string, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	handler, ok := guardHandlers[eventType]
	if !ok {
		return nil, fmt.Errorf("guard %s: %w", eventType, ErrUnknownEventType)
	}
	tx, err := LoadTaxonomy()
	if err != nil {
		return nil, fmt.Errorf("guard %s: load taxonomy: %w", eventType, err)
	}
	envelopes, err := handler(tx, evt)
	if err != nil {
		return nil, fmt.Errorf("guard %s: %w", eventType, err)
	}
	return envelopes, nil
}

// runGuard implements the `furrow guard <event-type>` subcommand.
//
// Contract (specs/shared-contracts.md §C2):
//   - No flags. Single positional arg `<event-type>`.
//   - Stdin: a single JSON document conforming to
//     schemas/blocker-event.schema.json.
//   - Stdout: ALWAYS a JSON array of zero or more BlockerEnvelope objects
//     (encoded with `SetIndent("", "  ")` + trailing newline). Empty
//     array `[]` = no trigger.
//   - Exit 0 = ran cleanly (stdout array may be empty or non-empty).
//   - Exit 1 = invocation error (unknown event type, malformed input,
//     missing required payload key, internal loader failure). Stderr
//     carries a one-line diagnostic.
//   - NEVER exits 2. Host-blocking exit codes are produced only by the
//     shell helper translating envelope severity.
func (a *App) runGuard(args []string) int {
	// `help` / `-h` / `--help` produce usage on stdout, exit 0. They
	// short-circuit before stdin is read.
	if len(args) == 1 {
		switch args[0] {
		case "help", "-h", "--help":
			a.printGuardHelp()
			return 0
		}
	}
	if len(args) != 1 {
		_, _ = fmt.Fprintln(a.stderr, "guard: usage: furrow guard <event-type>")
		return 1
	}
	eventType := args[0]

	stdin, ok := a.readGuardStdin()
	if !ok {
		return 1
	}

	var evt NormalizedEvent
	if len(strings.TrimSpace(string(stdin))) == 0 {
		// Empty stdin is permitted; handler sees zero-value event with an
		// empty payload and decides whether the trigger applies.
		evt = NormalizedEvent{Payload: map[string]any{}}
	} else if err := json.Unmarshal(stdin, &evt); err != nil {
		_, _ = fmt.Fprintf(a.stderr, "guard %s: parse stdin: %v\n", eventType, err)
		return 1
	}
	if evt.Payload == nil {
		evt.Payload = map[string]any{}
	}
	// Honor the redundancy check: if the event JSON carries an event_type,
	// it MUST match the positional arg. Mismatches are a misrouted
	// adapter — fail fast so the bug surfaces at the boundary.
	if evt.EventType != "" && evt.EventType != eventType {
		_, _ = fmt.Fprintf(a.stderr,
			"guard %s: event_type mismatch: stdin says %q, arg says %q\n",
			eventType, evt.EventType, eventType)
		return 1
	}

	envelopes, err := Guard(eventType, evt)
	if err != nil {
		_, _ = fmt.Fprintln(a.stderr, err.Error())
		return 1
	}

	// Always emit a JSON array, even when empty or single-element. Uniform
	// shape removes branching in shell callers and parity-comparison tests.
	if envelopes == nil {
		envelopes = []BlockerEnvelope{}
	}
	enc := json.NewEncoder(a.stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(envelopes); err != nil {
		_, _ = fmt.Fprintf(a.stderr, "guard %s: encode envelopes: %v\n", eventType, err)
		return 1
	}
	return 0
}

// readGuardStdin reads the entire stdin into memory. Stdin payloads are
// small (~few KB at most — a single tool_input JSON), so reading-all is
// safe. We type-assert to io.Reader because *App.stdin is not stored on
// the struct (Run() consumes os.Args, not stdin) — guard is the only
// command that reads stdin, so we resolve it via a stdinReader interface
// that os.Stdin satisfies. In tests, app.go's stderr/stdout writers are
// the only injection point; runGuard reads from os.Stdin directly which
// the test harness redirects via os.Stdin override.
func (a *App) readGuardStdin() ([]byte, bool) {
	r := a.stdin
	if r == nil {
		// Fall back to os.Stdin when the App was constructed without an
		// explicit stdin (production: cmd/furrow/main.go passes os.Stdin
		// via NewWithStdin; legacy New() callers leave stdin nil and the
		// run-time defaults below are unreachable in practice).
		_, _ = fmt.Fprintln(a.stderr, "guard: no stdin reader configured")
		return nil, false
	}
	payload, err := io.ReadAll(r)
	if err != nil {
		_, _ = fmt.Fprintf(a.stderr, "guard: read stdin: %v\n", err)
		return nil, false
	}
	return payload, true
}

// printGuardHelp writes the `furrow guard help` usage to stdout.
func (a *App) printGuardHelp() {
	_, _ = fmt.Fprintln(a.stdout, `furrow guard <event-type>

Reads a normalized blocker event JSON document on stdin and emits a JSON
array of zero or more canonical BlockerEnvelope objects on stdout.

Stdout is ALWAYS an array (empty array means trigger not met).
Exit 0: ran cleanly. Exit 1: invocation error (never exits 2).

Event types:
  `+strings.Join(guardEventTypes(), "\n  "))
}

// requireString extracts a string-typed payload key. Returns an error
// naming the key when absent or empty (handlers use this to enforce
// schemas/blocker-event.yaml event_types[].required[]).
func requireString(payload map[string]any, key string) (string, error) {
	v, ok := payload[key]
	if !ok || v == nil {
		return "", fmt.Errorf("missing required payload key %q", key)
	}
	s, ok := v.(string)
	if !ok {
		return "", fmt.Errorf("payload key %q must be a string (got %T)", key, v)
	}
	if strings.TrimSpace(s) == "" {
		return "", fmt.Errorf("payload key %q is empty", key)
	}
	return s, nil
}

// requireArray extracts an array-typed payload key. Returns an error
// naming the key when absent or empty.
func requireArray(payload map[string]any, key string) ([]any, error) {
	v, ok := payload[key]
	if !ok || v == nil {
		return nil, fmt.Errorf("missing required payload key %q", key)
	}
	arr, ok := v.([]any)
	if !ok {
		return nil, fmt.Errorf("payload key %q must be an array (got %T)", key, v)
	}
	if len(arr) == 0 {
		return nil, fmt.Errorf("payload key %q is empty", key)
	}
	return arr, nil
}

// firstNonEmptyString returns the first non-empty value among the listed
// payload keys. Used by handlers that accept either a top-level convenience
// field (e.g., `target_path`) or the same key inside `payload`.
func firstNonEmptyString(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

// --- Mechanical handlers (small, single-emit) ---

// handlePreWriteStateJSON: emit when the target path ends in state.json.
func handlePreWriteStateJSON(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	path := firstNonEmptyString(evt.TargetPath, asString(evt.Payload["target_path"]))
	if path == "" {
		// No path → nothing to guard. Treat as no-trigger rather than an
		// invocation error: pre-write hooks fire on every Write/Edit and
		// some tool calls don't carry a path (e.g., MCP tool calls).
		return nil, nil
	}
	if !pathHasBaseName(path, "state.json") {
		return nil, nil
	}
	return []BlockerEnvelope{
		tx.EmitBlocker("state_json_direct_write", map[string]string{"path": path}),
	}, nil
}

// handlePreWriteVerdict: emit when the target path crosses gate-verdicts/.
func handlePreWriteVerdict(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	path := firstNonEmptyString(evt.TargetPath, asString(evt.Payload["target_path"]))
	if path == "" {
		return nil, nil
	}
	if !strings.Contains(path, "gate-verdicts/") {
		return nil, nil
	}
	return []BlockerEnvelope{
		tx.EmitBlocker("verdict_direct_write", map[string]string{"path": path}),
	}, nil
}

// asString is a permissive conversion: returns the underlying string when
// the value is a string, "" otherwise. Used in places where the payload
// key is optional and the handler decides on absence.
func asString(v any) string {
	s, _ := v.(string)
	return s
}

// pathHasBaseName reports whether the path's last component equals name.
// Defensive against trailing slashes and Windows separators are out of
// scope (Furrow targets POSIX paths).
func pathHasBaseName(path, name string) bool {
	idx := strings.LastIndex(path, "/")
	base := path
	if idx >= 0 {
		base = path[idx+1:]
	}
	return base == name
}
