package context

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// ---------------------------------------------------------------------------
// FileContextSource — concrete ContextSource reading from the filesystem.
// ---------------------------------------------------------------------------

// FileContextSource implements ContextSource by reading a row's files from the
// .furrow/rows/{row}/ directory tree. Safe for concurrent reads.
type FileContextSource struct {
	root   string // furrow root (parent of .furrow/)
	row    string
	step   string
	target string
}

// NewFileContextSource constructs a FileContextSource.
// root is the directory containing .furrow/ (i.e. the repo root).
func NewFileContextSource(root, row, step, target string) *FileContextSource {
	return &FileContextSource{root: root, row: row, step: step, target: target}
}

func (s *FileContextSource) Row() string    { return s.row }
func (s *FileContextSource) Step() string   { return s.step }
func (s *FileContextSource) Target() string { return s.target }

func (s *FileContextSource) rowDir() string {
	return filepath.Join(s.root, ".furrow", "rows", s.row)
}

// ReadState returns the parsed state.json for this row.
func (s *FileContextSource) ReadState() (map[string]any, error) {
	path := filepath.Join(s.rowDir(), "state.json")
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return map[string]any{}, nil
		}
		return nil, fmt.Errorf("source: read state: %w", err)
	}
	var result map[string]any
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, fmt.Errorf("source: parse state: %w", err)
	}
	return result, nil
}

// ReadSummary returns parsed summary.md sections as a map of heading → content.
func (s *FileContextSource) ReadSummary() (map[string]any, error) {
	path := filepath.Join(s.rowDir(), "summary.md")
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return map[string]any{}, nil
		}
		return nil, fmt.Errorf("source: read summary: %w", err)
	}
	sections := parseSummarySections(string(data))
	result := make(map[string]any, len(sections))
	for k, v := range sections {
		result[k] = v
	}
	return result, nil
}

// parseSummarySections splits a markdown document into heading→content pairs.
// Only top-level ## headings are used as section keys.
func parseSummarySections(content string) map[string]string {
	sections := map[string]string{}
	var currentHeading string
	var buf strings.Builder

	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "## ") {
			if currentHeading != "" {
				sections[currentHeading] = strings.TrimSpace(buf.String())
			}
			currentHeading = strings.TrimPrefix(line, "## ")
			buf.Reset()
		} else {
			buf.WriteString(line)
			buf.WriteByte('\n')
		}
	}
	if currentHeading != "" {
		sections[currentHeading] = strings.TrimSpace(buf.String())
	}
	return sections
}

// ReadGateEvidence returns gate evidence extracted from state.json gates array.
func (s *FileContextSource) ReadGateEvidence() (map[string]any, error) {
	state, err := s.ReadState()
	if err != nil {
		return nil, fmt.Errorf("source: gate evidence: %w", err)
	}
	gates, _ := state["gates"]
	return map[string]any{"gates": gates}, nil
}

// ReadLearnings returns learnings from learnings.jsonl for this row.
func (s *FileContextSource) ReadLearnings() ([]Learning, error) {
	path := filepath.Join(s.rowDir(), "learnings.jsonl")
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("source: read learnings: %w", err)
	}
	var learnings []Learning
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	lineNo := 0
	for scanner.Scan() {
		lineNo++
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var raw map[string]any
		if err := json.Unmarshal([]byte(line), &raw); err != nil {
			return nil, fmt.Errorf("source: learnings.jsonl line %d: %w", lineNo, err)
		}
		l := Learning{}
		if id, ok := raw["id"].(string); ok {
			l.ID = id
		} else {
			// Synthesize ID from summary field if present.
			if summary, ok := raw["summary"].(string); ok {
				l.ID = slugify(summary)
			}
		}
		if body, ok := raw["detail"].(string); ok {
			l.Body = body
		} else if body, ok := raw["body"].(string); ok {
			l.Body = body
		} else if summary, ok := raw["summary"].(string); ok {
			l.Body = summary
		}
		if promoted, ok := raw["promoted"].(bool); ok {
			l.BroadlyApplicable = promoted
		} else if ba, ok := raw["broadly_applicable"].(bool); ok {
			l.BroadlyApplicable = ba
		}
		learnings = append(learnings, l)
	}
	return learnings, nil
}

// slugify creates a simple lowercase slug from a string (for ID synthesis).
func slugify(s string) string {
	s = strings.ToLower(s)
	s = regexp.MustCompile(`[^a-z0-9]+`).ReplaceAllString(s, "-")
	s = strings.Trim(s, "-")
	if len(s) > 60 {
		s = s[:60]
	}
	return s
}

// ListSkills returns skills from the skills/ directory tree (including
// skills/shared/*), tagged with layer from front-matter. Skills missing a
// layer: tag are returned with sentinel layer "MISSING" so the caller can
// emit skill_layer_unset. When the target is specialist:{id}, the
// specialists/{id}.md brief is also injected as a Skill with layer "engine".
func (s *FileContextSource) ListSkills() ([]Skill, error) {
	skillsDir := filepath.Join(s.root, "skills")
	var skills []Skill

	// Walk skills/ recursively so skills/shared/* is included.
	walkErr := filepath.WalkDir(skillsDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			if os.IsNotExist(err) {
				return nil
			}
			return fmt.Errorf("source: walk skills: %w", err)
		}
		if d.IsDir() || !strings.HasSuffix(d.Name(), ".md") {
			return nil
		}
		data, readErr := os.ReadFile(path)
		if readErr != nil {
			return fmt.Errorf("source: read skill %s: %w", path, readErr)
		}
		// Compute path relative to s.root for consistent relative paths.
		relPath, relErr := filepath.Rel(s.root, path)
		if relErr != nil {
			relPath = path
		}
		layer := extractLayer(string(data))
		skills = append(skills, Skill{
			Path:    relPath,
			Layer:   layer,
			Content: string(data),
		})
		return nil
	})
	if walkErr != nil {
		if os.IsNotExist(walkErr) {
			// skills/ directory doesn't exist yet; non-fatal.
		} else {
			return nil, walkErr
		}
	}

	// When target is specialist:{id}, inject the specialist brief as an engine-layer skill.
	if strings.HasPrefix(s.target, "specialist:") {
		id := strings.TrimPrefix(s.target, "specialist:")
		briefPath := filepath.Join(s.root, "specialists", id+".md")
		data, err := os.ReadFile(briefPath)
		if err != nil && !os.IsNotExist(err) {
			return nil, fmt.Errorf("source: read specialist brief %s: %w", briefPath, err)
		}
		if err == nil {
			skills = append(skills, Skill{
				Path:    filepath.Join("specialists", id+".md"),
				Layer:   "engine",
				Content: string(data),
			})
		}
	}

	return skills, nil
}

// extractLayer parses the YAML front-matter from a skill file looking for
// a "layer: <value>" line. Returns "MISSING" if absent.
func extractLayer(content string) string {
	// Front-matter: leading lines before the first # heading, or the whole file.
	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "# ") {
			break // past front-matter
		}
		if strings.HasPrefix(line, "layer:") {
			val := strings.TrimSpace(strings.TrimPrefix(line, "layer:"))
			val = strings.Trim(val, `"' `)
			if val != "" {
				return val
			}
		}
	}
	return "MISSING"
}

// ListReferences returns reference files from references/ directory.
// Content is not pre-loaded (on-demand model per spec).
func (s *FileContextSource) ListReferences() ([]Reference, error) {
	refsDir := filepath.Join(s.root, "references")
	entries, err := os.ReadDir(refsDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("source: list references: %w", err)
	}
	var refs []Reference
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		refs = append(refs, Reference{Path: filepath.Join("references", e.Name())})
	}
	return refs, nil
}

// ---------------------------------------------------------------------------
// Decisions extraction (T3 finding, AC §6).
// ---------------------------------------------------------------------------

var (
	settledRe  = regexp.MustCompile(`^- \*\*([a-z_]+)->([a-z_]+)\*\*: (pass|fail) — (.*)$`)
	fallbackRe = regexp.MustCompile(`^- (?:Decision|DECISION): (.+)$`)
)

// ExtractDecisions parses a summary.md string and returns the de-duplicated
// Decision slice. De-dup: gate retries (same from_step+to_step pair appearing
// more than once) collapse to last-wins, preserving first-occurrence ordinal.
func ExtractDecisions(summaryMD, currentStep string) []Decision {
	var rawDecisions []Decision
	ordinal := 0

	lines := strings.Split(summaryMD, "\n")
	inSettled := false
	inKeyFindings := false

	for _, line := range lines {
		if strings.HasPrefix(line, "## ") {
			heading := strings.TrimPrefix(line, "## ")
			inSettled = strings.EqualFold(heading, "Settled Decisions")
			inKeyFindings = strings.EqualFold(heading, "Key Findings")
			continue
		}

		if inSettled {
			if m := settledRe.FindStringSubmatch(line); m != nil {
				rawDecisions = append(rawDecisions, Decision{
					Source:    "settled_decisions",
					FromStep:  m[1],
					ToStep:    m[2],
					Outcome:   m[3],
					Rationale: m[4],
					Ordinal:   ordinal,
				})
				ordinal++
			}
		}

		if inKeyFindings {
			if m := fallbackRe.FindStringSubmatch(line); m != nil {
				rawDecisions = append(rawDecisions, Decision{
					Source:    "key_findings_prose",
					FromStep:  currentStep,
					ToStep:    currentStep,
					Outcome:   "unknown",
					Rationale: m[1],
					Ordinal:   ordinal,
				})
				ordinal++
			}
		}
	}

	return deduplicateDecisions(rawDecisions)
}

// deduplicateDecisions collapses gate retries (same from_step+to_step pair)
// to last-wins, preserving the first-occurrence ordinal of the surviving entry.
func deduplicateDecisions(decisions []Decision) []Decision {
	type key struct{ from, to string }

	// Track first-occurrence ordinal and last-occurrence value per key.
	firstOrdinal := map[key]int{}
	lastDecision := map[key]Decision{}
	keyOrder := []key{} // tracks insertion order of first-occurrence

	for _, d := range decisions {
		k := key{d.FromStep, d.ToStep}
		if _, seen := firstOrdinal[k]; !seen {
			firstOrdinal[k] = d.Ordinal
			keyOrder = append(keyOrder, k)
		}
		lastDecision[k] = d
	}

	// Reconstruct: preserve first-occurrence ordinal on the surviving (last) entry.
	result := make([]Decision, 0, len(keyOrder))
	for _, k := range keyOrder {
		d := lastDecision[k]
		d.Ordinal = firstOrdinal[k]
		result = append(result, d)
	}
	return result
}
