package cli

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

var slugPattern = regexp.MustCompile(`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`)

func findFurrowRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}

	current := cwd
	for {
		candidate := filepath.Join(current, ".furrow")
		if info, err := os.Stat(candidate); err == nil && info.IsDir() {
			return current, nil
		}
		next := filepath.Dir(current)
		if next == current {
			return "", errors.New(".furrow root not found")
		}
		current = next
	}
}

func readFocusedRowName(root string) (string, bool, error) {
	payload, err := os.ReadFile(filepath.Join(root, ".furrow", ".focused"))
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return "", false, nil
		}
		return "", false, err
	}
	row := strings.TrimSpace(string(payload))
	if row == "" {
		return "", true, errors.New(".furrow/.focused is empty")
	}
	return row, true, nil
}

func statePathForRow(root, rowName string) string {
	return filepath.Join(root, ".furrow", "rows", rowName, "state.json")
}

func rowDirFor(root, rowName string) string {
	return filepath.Join(root, ".furrow", "rows", rowName)
}

func loadJSONMap(path string) (map[string]any, error) {
	payload, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var out map[string]any
	if err := json.Unmarshal(payload, &out); err != nil {
		return nil, err
	}
	return out, nil
}

func writeJSONMapAtomic(path string, value map[string]any) error {
	dir := filepath.Dir(path)
	tmp, err := os.CreateTemp(dir, ".state-*.tmp")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer func() { _ = os.Remove(tmpPath) }()

	enc := json.NewEncoder(tmp)
	enc.SetIndent("", "  ")
	if err := enc.Encode(value); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpPath, path)
}

func getString(m map[string]any, key string) (string, bool) {
	v, ok := m[key]
	if !ok || v == nil {
		return "", false
	}
	s, ok := v.(string)
	return s, ok
}

func getStringDefault(m map[string]any, key, fallback string) string {
	if s, ok := getString(m, key); ok && s != "" {
		return s
	}
	return fallback
}

func asMap(v any) (map[string]any, bool) {
	m, ok := v.(map[string]any)
	return m, ok
}

func asSlice(v any) ([]any, bool) {
	s, ok := v.([]any)
	return s, ok
}

func asStringSlice(v any) ([]string, bool) {
	raw, ok := asSlice(v)
	if !ok {
		return nil, false
	}
	out := make([]string, 0, len(raw))
	for _, item := range raw {
		s, ok := item.(string)
		if !ok {
			return nil, false
		}
		out = append(out, s)
	}
	return out, true
}

func intFromAny(v any) (int, bool) {
	switch n := v.(type) {
	case int:
		return n, true
	case int64:
		return int(n), true
	case float64:
		return int(n), true
	default:
		return 0, false
	}
}

func isArchivedState(state map[string]any) bool {
	archivedAt, ok := getString(state, "archived_at")
	return ok && strings.TrimSpace(archivedAt) != ""
}

func defaultStepsSequence() []string {
	return []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}
}

func stepsSequenceFromState(state map[string]any) ([]string, bool) {
	if steps, ok := asStringSlice(state["steps_sequence"]); ok && len(steps) > 0 {
		return steps, true
	}
	return nil, false
}

func indexOfStep(steps []string, target string) int {
	for i, step := range steps {
		if step == target {
			return i
		}
	}
	return -1
}

func nowRFC3339() string {
	return time.Now().UTC().Format(time.RFC3339)
}

func isValidSlug(value string) bool {
	return slugPattern.MatchString(value)
}

func parseRFC3339(value string) time.Time {
	if value == "" {
		return time.Time{}
	}
	t, err := time.Parse(time.RFC3339, value)
	if err != nil {
		return time.Time{}
	}
	return t
}

type rowListEntry struct {
	Name              string
	Title             string
	Step              string
	StepStatus        string
	Archived          bool
	Focused           bool
	UpdatedAt         string
	Branch            any
	DeliverableCounts map[string]int
	StatePath         string
	Warnings          []map[string]any
}

func sortRowEntries(rows []rowListEntry) {
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].Archived != rows[j].Archived {
			return !rows[i].Archived
		}
		ti := parseRFC3339(rows[i].UpdatedAt)
		tj := parseRFC3339(rows[j].UpdatedAt)
		if !ti.Equal(tj) {
			return tj.Before(ti)
		}
		return rows[i].Name < rows[j].Name
	})
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func requireNoPositionals(command string, positionals []string, jsonOut bool) error {
	if len(positionals) == 0 {
		return nil
	}
	return &cliError{exit: 1, code: "usage", message: fmt.Sprintf("usage: %s [--json]", command)}
}
