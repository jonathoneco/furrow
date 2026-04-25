package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

// runValidateOwnership implements `furrow validate ownership`.
//
// Usage: furrow validate ownership --path <target> [--row <name>] [--json]
//
// Verdict: in_scope | out_of_scope | not_applicable.
// Step-agnostic — never reads state.json.step.
//
// Exit codes: 0 (verdict produced regardless of in_scope/out_of_scope/not_applicable),
// 1 (usage error).
func (a *App) runValidateOwnership(args []string) int {
	positionals, flags, err := parseArgs(args, map[string]bool{"path": true, "row": true}, nil)
	if err != nil {
		return a.fail("furrow validate ownership", err, false)
	}
	if len(positionals) > 0 {
		return a.fail("furrow validate ownership", &cliError{
			exit: 1, code: "usage",
			message: fmt.Sprintf("unexpected positional %q (use --path, --row)", positionals[0]),
		}, flags.json)
	}

	path := flags.values["path"]
	if path == "" {
		return a.fail("furrow validate ownership", &cliError{
			exit: 1, code: "usage", message: "missing required flag --path",
		}, flags.json)
	}

	root, err := findFurrowRoot()
	if err != nil {
		return a.fail("furrow validate ownership", &cliError{
			exit: 4, code: "internal", message: err.Error(),
		}, flags.json)
	}

	rowName := flags.values["row"]
	if rowName == "" {
		focused, present, err := readFocusedRowName(root)
		if err != nil || !present {
			return a.emitOwnershipNotApplicable(flags.json, "no_active_row")
		}
		rowName = focused
	}

	verdict := computeOwnership(root, rowName, path)
	return a.emitOwnership(flags.json, verdict)
}

// OwnershipVerdict is the structured result of a validate-ownership run.
type OwnershipVerdict struct {
	Verdict            string           `json:"verdict"`
	MatchedDeliverable string           `json:"matched_deliverable,omitempty"`
	MatchedGlob        string           `json:"matched_glob,omitempty"`
	Reason             string           `json:"reason,omitempty"`
	Envelope           *BlockerEnvelope `json:"envelope,omitempty"`
}

// canonicalArtifactRowSubpaths are the row-infrastructure files that always
// yield not_applicable per spec — kept narrow to match specs/validate-ownership-go.md
// AC #4 exactly. Other row artifacts (research.md, plan.json, team-plan.md,
// parity-verification.md, specs/*, reviews/*, gates/*, etc.) are NOT carved out;
// they must be explicitly listed in deliverables[].file_ownership when a
// deliverable touches them.
var canonicalArtifactRowSubpaths = []string{
	"state.json",
	"definition.yaml",
	"summary.md",
	"learnings.jsonl",
}

// canonicalArtifactRowDirs is intentionally empty. The spec's canonical-artifact
// carve-out is by-file, not by-directory. Earlier versions of this validator
// included specs/, reviews/, gates/, etc. — that broadening was outside spec.
var canonicalArtifactRowDirs = []string{}

// computeOwnership runs the ownership check for a given row + target path. It
// is step-agnostic and pure (no I/O beyond reading definition.yaml). Returns a
// verdict suitable for direct JSON encoding.
func computeOwnership(root, rowName, targetPath string) OwnershipVerdict {
	if isCanonicalRowArtifact(targetPath) {
		return OwnershipVerdict{Verdict: "not_applicable", Reason: "canonical_row_artifact"}
	}

	defPath := filepath.Join(root, ".furrow", "rows", rowName, "definition.yaml")
	payload, err := os.ReadFile(defPath)
	if err != nil {
		return OwnershipVerdict{Verdict: "not_applicable", Reason: "row_definition_unreadable"}
	}

	var raw struct {
		Deliverables []struct {
			Name          string   `yaml:"name"`
			FileOwnership []string `yaml:"file_ownership"`
		} `yaml:"deliverables"`
	}
	if err := yaml.Unmarshal(payload, &raw); err != nil {
		return OwnershipVerdict{Verdict: "not_applicable", Reason: "row_definition_unparsable"}
	}
	if len(raw.Deliverables) == 0 {
		return OwnershipVerdict{Verdict: "not_applicable", Reason: "row_has_no_deliverables"}
	}

	// Normalize the target relative to root so globs in definition.yaml
	// (which are typically project-relative) line up.
	rel := relativeToRoot(root, targetPath)

	for _, d := range raw.Deliverables {
		for _, glob := range d.FileOwnership {
			if globMatch(glob, rel) {
				return OwnershipVerdict{
					Verdict:            "in_scope",
					MatchedDeliverable: d.Name,
					MatchedGlob:        glob,
				}
			}
		}
	}

	tx, err := LoadTaxonomy()
	if err != nil {
		return OwnershipVerdict{Verdict: "not_applicable", Reason: "taxonomy_unavailable"}
	}
	envelope := tx.EmitBlocker("ownership_outside_scope", map[string]string{
		"path": rel,
		"row":  rowName,
	})
	return OwnershipVerdict{
		Verdict:  "out_of_scope",
		Envelope: &envelope,
	}
}

func isCanonicalRowArtifact(targetPath string) bool {
	// Canonicalise: any path that mentions /.furrow/rows/<name>/<x> where x is
	// in our canonical sets is row infrastructure regardless of working dir.
	idx := strings.Index(targetPath, ".furrow/rows/")
	if idx < 0 {
		return false
	}
	tail := targetPath[idx+len(".furrow/rows/"):]
	// Strip the row-name segment.
	slash := strings.Index(tail, "/")
	if slash < 0 {
		return false
	}
	rest := tail[slash+1:]
	for _, leaf := range canonicalArtifactRowSubpaths {
		if rest == leaf {
			return true
		}
	}
	for _, dir := range canonicalArtifactRowDirs {
		if strings.HasPrefix(rest, dir) {
			return true
		}
	}
	return false
}

func relativeToRoot(root, target string) string {
	if !filepath.IsAbs(target) {
		// Already relative; canonicalise via Clean to avoid `./` noise.
		return filepath.ToSlash(filepath.Clean(target))
	}
	rel, err := filepath.Rel(root, target)
	if err != nil {
		return filepath.ToSlash(target)
	}
	return filepath.ToSlash(rel)
}

// globMatch reports whether path matches glob, supporting `*` (within a path
// segment) and `**` (across segments) patterns. Hand-rolled because the
// project has no doublestar library vendored (per go.mod).
func globMatch(glob, path string) bool {
	pattern := globToRegex(glob)
	re, err := regexp.Compile(pattern)
	if err != nil {
		return false
	}
	return re.MatchString(path)
}

// globToRegex converts a shell-style glob with `**` doublestar support into
// an anchored regular expression.
func globToRegex(glob string) string {
	var b strings.Builder
	b.WriteByte('^')
	i := 0
	for i < len(glob) {
		c := glob[i]
		switch c {
		case '*':
			if i+1 < len(glob) && glob[i+1] == '*' {
				// `**` matches across path segments (zero or more characters).
				b.WriteString(".*")
				i += 2
				// Consume optional trailing slash so `**/foo` matches `foo` and `bar/foo`.
				if i < len(glob) && glob[i] == '/' {
					i++
				}
			} else {
				// `*` matches within a single path segment.
				b.WriteString("[^/]*")
				i++
			}
		case '?':
			b.WriteString("[^/]")
			i++
		case '.', '+', '(', ')', '|', '^', '$', '{', '}', '[', ']', '\\':
			b.WriteByte('\\')
			b.WriteByte(c)
			i++
		default:
			b.WriteByte(c)
			i++
		}
	}
	b.WriteByte('$')
	return b.String()
}

func (a *App) emitOwnership(jsonOut bool, verdict OwnershipVerdict) int {
	if jsonOut {
		return a.okJSON("furrow validate ownership", verdict)
	}
	switch verdict.Verdict {
	case "in_scope":
		_, _ = fmt.Fprintf(a.stdout, "in_scope (deliverable=%s, glob=%s)\n", verdict.MatchedDeliverable, verdict.MatchedGlob)
	case "out_of_scope":
		_, _ = fmt.Fprintf(a.stdout, "out_of_scope: %s\n", verdict.Envelope.Message)
		if verdict.Envelope.RemediationHint != "" {
			_, _ = fmt.Fprintf(a.stdout, "  hint: %s\n", verdict.Envelope.RemediationHint)
		}
	case "not_applicable":
		_, _ = fmt.Fprintf(a.stdout, "not_applicable (%s)\n", verdict.Reason)
	}
	return 0
}

func (a *App) emitOwnershipNotApplicable(jsonOut bool, reason string) int {
	return a.emitOwnership(jsonOut, OwnershipVerdict{Verdict: "not_applicable", Reason: reason})
}
