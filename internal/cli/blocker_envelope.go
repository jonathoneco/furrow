package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
	"testing"

	"gopkg.in/yaml.v3"
)

// Blocker is a single entry in schemas/blocker-taxonomy.yaml.
type Blocker struct {
	Code             string   `yaml:"code" json:"code"`
	Category         string   `yaml:"category" json:"category"`
	Severity         string   `yaml:"severity" json:"severity"`
	MessageTemplate  string   `yaml:"message_template" json:"message_template"`
	RemediationHint  string   `yaml:"remediation_hint" json:"remediation_hint"`
	ConfirmationPath string   `yaml:"confirmation_path" json:"confirmation_path"`
	ApplicableSteps  []string `yaml:"applicable_steps,omitempty" json:"applicable_steps,omitempty"`
}

// Taxonomy is the parsed contents of schemas/blocker-taxonomy.yaml.
type Taxonomy struct {
	Version  string    `yaml:"version" json:"version"`
	Blockers []Blocker `yaml:"blockers" json:"blockers"`

	index map[string]*Blocker
}

// BlockerEnvelope is the JSON shape emitted to adapters by D1/D2 validators.
type BlockerEnvelope struct {
	Code             string `json:"code"`
	Category         string `json:"category"`
	Severity         string `json:"severity"`
	Message          string `json:"message"`
	RemediationHint  string `json:"remediation_hint"`
	ConfirmationPath string `json:"confirmation_path"`
}

var (
	validSeverities         = map[string]struct{}{"block": {}, "warn": {}, "info": {}}
	validConfirmationPaths  = map[string]struct{}{"block": {}, "warn-with-confirm": {}, "silent": {}}
	taxonomyOnce            sync.Once
	cachedTaxonomy          *Taxonomy
	cachedTaxonomyLoadError error
)

// LoadTaxonomy reads schemas/blocker-taxonomy.yaml from the project's Furrow
// root and returns the parsed, validated taxonomy. Subsequent calls return the
// cached result. Validation errors return a non-nil error.
//
// Validation rules (hand-coded, per the no-new-deps constraint):
//   - version must be non-empty
//   - blockers[] must be non-empty
//   - every blocker must have all required string fields populated
//   - severity must be one of {block, warn, info}
//   - confirmation_path must be one of {block, warn-with-confirm, silent}
//   - codes must be unique
func LoadTaxonomy() (*Taxonomy, error) {
	taxonomyOnce.Do(func() {
		// Resolution order:
		//   1. FURROW_TAXONOMY_PATH env var (explicit override; useful for tests
		//      and out-of-tree deployments).
		//   2. <findFurrowRoot()>/schemas/blocker-taxonomy.yaml — the
		//      conventional location inside a Furrow project tree.
		//   3. <module-source-root>/schemas/blocker-taxonomy.yaml — discovered
		//      via runtime.Caller. Lets `go test` runs and binaries built
		//      inside the source tree find the canonical registry without
		//      requiring callers to provision it in temp roots.
		// This is expand-contract migration discipline: existing callers under
		// the project root keep working (path 2), tests in temp dirs fall back
		// to the source-tree copy (path 3), and ad-hoc consumers can override
		// with FURROW_TAXONOMY_PATH (path 1).
		for _, path := range candidateTaxonomyPaths() {
			if path == "" {
				continue
			}
			if _, statErr := os.Stat(path); statErr != nil {
				continue
			}
			cachedTaxonomy, cachedTaxonomyLoadError = loadTaxonomyFrom(path)
			return
		}
		cachedTaxonomyLoadError = fmt.Errorf("blocker taxonomy: schemas/blocker-taxonomy.yaml not found in any candidate location (set FURROW_TAXONOMY_PATH to override)")
	})
	return cachedTaxonomy, cachedTaxonomyLoadError
}

// candidateTaxonomyPaths returns the ordered list of paths LoadTaxonomy
// probes for the canonical YAML registry. See LoadTaxonomy for resolution
// order rationale.
func candidateTaxonomyPaths() []string {
	candidates := make([]string, 0, 3)
	if override := strings.TrimSpace(os.Getenv("FURROW_TAXONOMY_PATH")); override != "" {
		candidates = append(candidates, override)
	}
	if root, err := findFurrowRoot(); err == nil {
		candidates = append(candidates, filepath.Join(root, "schemas", "blocker-taxonomy.yaml"))
	}
	if srcRoot, ok := moduleSourceRoot(); ok {
		candidates = append(candidates, filepath.Join(srcRoot, "schemas", "blocker-taxonomy.yaml"))
	}
	return candidates
}

// moduleSourceRoot walks up from this source file's location to find the
// nearest directory containing a `schemas/blocker-taxonomy.yaml`. Returns the
// project root containing both `internal/cli/` and `schemas/`. This is a
// best-effort fallback for tests and tools that run outside a `.furrow/`
// project tree; it returns ok=false when run from a stripped binary.
func moduleSourceRoot() (string, bool) {
	_, file, _, ok := runtime.Caller(0)
	if !ok || file == "" {
		return "", false
	}
	dir := filepath.Dir(file)
	for {
		if _, err := os.Stat(filepath.Join(dir, "schemas", "blocker-taxonomy.yaml")); err == nil {
			return dir, true
		}
		next := filepath.Dir(dir)
		if next == dir {
			return "", false
		}
		dir = next
	}
}

// resetTaxonomyCacheForTest clears the package-level cache; only intended for
// tests that need to reload the taxonomy from a fixture path.
func resetTaxonomyCacheForTest() {
	taxonomyOnce = sync.Once{}
	cachedTaxonomy = nil
	cachedTaxonomyLoadError = nil
}

func loadTaxonomyFrom(path string) (*Taxonomy, error) {
	payload, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("blocker taxonomy: read %s: %w", path, err)
	}

	var t Taxonomy
	if err := yaml.Unmarshal(payload, &t); err != nil {
		return nil, fmt.Errorf("blocker taxonomy: parse %s: %w", path, err)
	}

	if strings.TrimSpace(t.Version) == "" {
		return nil, fmt.Errorf("blocker taxonomy: missing version")
	}
	if len(t.Blockers) == 0 {
		return nil, fmt.Errorf("blocker taxonomy: blockers[] is empty")
	}

	t.index = make(map[string]*Blocker, len(t.Blockers))
	for i := range t.Blockers {
		b := &t.Blockers[i]
		if strings.TrimSpace(b.Code) == "" {
			return nil, fmt.Errorf("blocker taxonomy: entry at index %d has empty code", i)
		}
		if strings.TrimSpace(b.Category) == "" {
			return nil, fmt.Errorf("blocker taxonomy: code %q has empty category", b.Code)
		}
		if strings.TrimSpace(b.MessageTemplate) == "" {
			return nil, fmt.Errorf("blocker taxonomy: code %q has empty message_template", b.Code)
		}
		if strings.TrimSpace(b.RemediationHint) == "" {
			return nil, fmt.Errorf("blocker taxonomy: code %q has empty remediation_hint", b.Code)
		}
		if _, ok := validSeverities[b.Severity]; !ok {
			return nil, fmt.Errorf("blocker taxonomy: code %q has invalid severity %q", b.Code, b.Severity)
		}
		if _, ok := validConfirmationPaths[b.ConfirmationPath]; !ok {
			return nil, fmt.Errorf("blocker taxonomy: code %q has invalid confirmation_path %q", b.Code, b.ConfirmationPath)
		}
		if _, dup := t.index[b.Code]; dup {
			return nil, fmt.Errorf("blocker taxonomy: duplicate code %q", b.Code)
		}
		t.index[b.Code] = b
	}

	return &t, nil
}

// Lookup returns the registered Blocker for the given code, or (nil, false)
// when the code is not registered. Useful for callers that need to inspect
// the canonical entry (e.g., to honor applicable_steps) before deciding to
// emit.
func (t *Taxonomy) Lookup(code string) (*Blocker, bool) {
	if t == nil || t.index == nil {
		return nil, false
	}
	b, ok := t.index[code]
	return b, ok
}

// Applies reports whether a code applies in the given row step. Codes whose
// applicable_steps is absent or empty apply to every step. Unregistered codes
// return false (a code that does not exist in the registry never "applies").
func (t *Taxonomy) Applies(code, step string) bool {
	b, ok := t.Lookup(code)
	if !ok {
		return false
	}
	if len(b.ApplicableSteps) == 0 {
		return true
	}
	for _, s := range b.ApplicableSteps {
		if s == step {
			return true
		}
	}
	return false
}

// EmitBlocker resolves the code in the taxonomy, interpolates {placeholder}
// substitutions from interp into message_template, and returns the JSON
// envelope. In test mode (testing.Testing()), an unregistered code panics; in
// production it returns a synthetic envelope with the code embedded so the
// caller can still surface something.
func (t *Taxonomy) EmitBlocker(code string, interp map[string]string) BlockerEnvelope {
	b, ok := t.index[code]
	if !ok {
		if testing.Testing() {
			panic(fmt.Sprintf("blocker taxonomy: unregistered code %q (test mode)", code))
		}
		return BlockerEnvelope{
			Code:             code,
			Category:         "unregistered",
			Severity:         "warn",
			Message:          fmt.Sprintf("unregistered blocker code %q", code),
			RemediationHint:  "Add this code to schemas/blocker-taxonomy.yaml",
			ConfirmationPath: "warn-with-confirm",
		}
	}
	return BlockerEnvelope{
		Code:             b.Code,
		Category:         b.Category,
		Severity:         b.Severity,
		Message:          interpolate(b.MessageTemplate, interp),
		RemediationHint:  b.RemediationHint,
		ConfirmationPath: b.ConfirmationPath,
	}
}

// interpolate substitutes {key} occurrences in template with interp[key], then
// surfaces any remaining {key} placeholders as a clear error: panics in test
// mode (matching unregistered-code behavior) and prepends an "[unfilled
// placeholder]" marker on the rendered string in production so callers see
// the issue rather than silently shipping a half-rendered message.
func interpolate(template string, interp map[string]string) string {
	out := template
	if len(interp) > 0 {
		keys := make([]string, 0, len(interp))
		for k := range interp {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			out = strings.ReplaceAll(out, "{"+k+"}", interp[k])
		}
	}
	if missing := unresolvedPlaceholders(out); len(missing) > 0 {
		if testing.Testing() {
			panic(fmt.Sprintf("blocker taxonomy: unresolved interpolation placeholders %v in template %q", missing, template))
		}
		return "[unfilled placeholder " + strings.Join(missing, ",") + "] " + out
	}
	return out
}

// unresolvedPlaceholders returns the set of {key} tokens still present in s.
// Tokens are detected by scanning for "{...}" with simple identifier contents.
func unresolvedPlaceholders(s string) []string {
	var found []string
	for i := 0; i < len(s); i++ {
		if s[i] != '{' {
			continue
		}
		end := strings.IndexByte(s[i+1:], '}')
		if end < 0 {
			break
		}
		key := s[i+1 : i+1+end]
		if isPlaceholderIdent(key) {
			found = append(found, key)
		}
		i += end
	}
	return found
}

func isPlaceholderIdent(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if !((r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '_') {
			return false
		}
	}
	return true
}
