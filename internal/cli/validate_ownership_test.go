package cli

import (
	"os"
	"path/filepath"
	"testing"
)

// fixtureRoot creates a fake project root with a row's definition.yaml and a
// .furrow directory. Returns the project root path.
func fixtureRoot(t *testing.T, rowName, defBody string) string {
	t.Helper()
	root := t.TempDir()
	rowDir := filepath.Join(root, ".furrow", "rows", rowName)
	if err := os.MkdirAll(rowDir, 0o755); err != nil {
		t.Fatalf("mkdir row: %v", err)
	}
	if err := os.WriteFile(filepath.Join(rowDir, "definition.yaml"), []byte(defBody), 0o644); err != nil {
		t.Fatalf("write definition: %v", err)
	}
	return root
}

const ownershipFixtureDef = `objective: "ownership fixture"
deliverables:
  - name: code-paths
    file_ownership:
      - "internal/cli/validate_ownership.go"
      - "internal/cli/**/*_test.go"
  - name: shell-paths
    file_ownership:
      - "bin/frw.d/scripts/*.sh"
context_pointers:
  - path: "/tmp/foo"
    note: "n"
constraints: []
gate_policy: supervised
`

func TestComputeOwnershipInScopeExact(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	root := fixtureRoot(t, "fix", ownershipFixtureDef)

	v := computeOwnership(root, "fix", "internal/cli/validate_ownership.go")
	if v.Verdict != "in_scope" {
		t.Fatalf("verdict: got %q, want in_scope", v.Verdict)
	}
	if v.MatchedDeliverable != "code-paths" {
		t.Fatalf("matched_deliverable: got %q", v.MatchedDeliverable)
	}
	if v.MatchedGlob != "internal/cli/validate_ownership.go" {
		t.Fatalf("matched_glob: got %q", v.MatchedGlob)
	}
}

func TestComputeOwnershipInScopeDoubleStar(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	root := fixtureRoot(t, "fix", ownershipFixtureDef)

	v := computeOwnership(root, "fix", "internal/cli/foo/bar_test.go")
	if v.Verdict != "in_scope" {
		t.Fatalf("verdict: got %q, want in_scope", v.Verdict)
	}
	if v.MatchedGlob != "internal/cli/**/*_test.go" {
		t.Fatalf("matched_glob: got %q", v.MatchedGlob)
	}
}

func TestComputeOwnershipOutOfScope(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	root := fixtureRoot(t, "fix", ownershipFixtureDef)

	// Make the fixture's root the active Furrow root for taxonomy lookup
	// by symlinking the schemas dir.
	repoRoot, err := os.Getwd()
	if err != nil {
		t.Fatalf("Getwd: %v", err)
	}
	repoRoot = filepath.Dir(filepath.Dir(repoRoot)) // back out of internal/cli
	mustLinkSchemas(t, repoRoot, root)

	t.Chdir(root)

	v := computeOwnership(root, "fix", "some/other/file.txt")
	if v.Verdict != "out_of_scope" {
		t.Fatalf("verdict: got %q, want out_of_scope", v.Verdict)
	}
	if v.Envelope == nil {
		t.Fatal("expected envelope, got nil")
	}
	if v.Envelope.Code != "ownership_outside_scope" {
		t.Fatalf("envelope.code: got %q", v.Envelope.Code)
	}
}

func TestComputeOwnershipCanonicalArtifactCarveOut(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	root := fixtureRoot(t, "fix", ownershipFixtureDef)

	cases := []string{
		".furrow/rows/fix/state.json",
		".furrow/rows/fix/definition.yaml",
		".furrow/rows/fix/summary.md",
		".furrow/rows/fix/learnings.jsonl",
		".furrow/rows/fix/research.md",
		".furrow/rows/fix/plan.json",
		".furrow/rows/fix/team-plan.md",
		".furrow/rows/fix/parity-verification.md",
		".furrow/rows/fix/specs/foo.md",
		".furrow/rows/fix/reviews/cross.json",
		".furrow/rows/fix/gates/something.json",
	}
	for _, p := range cases {
		v := computeOwnership(root, "fix", p)
		if v.Verdict != "not_applicable" {
			t.Fatalf("path %q: verdict %q, want not_applicable", p, v.Verdict)
		}
		if v.Reason != "canonical_row_artifact" {
			t.Fatalf("path %q: reason %q, want canonical_row_artifact", p, v.Reason)
		}
	}
}

func TestComputeOwnershipRowHasNoDeliverables(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	emptyDef := `objective: "x"
deliverables: []
context_pointers:
  - path: "/tmp"
    note: "n"
constraints: []
gate_policy: supervised
`
	root := fixtureRoot(t, "empty", emptyDef)

	v := computeOwnership(root, "empty", "internal/cli/foo.go")
	if v.Verdict != "not_applicable" || v.Reason != "row_has_no_deliverables" {
		t.Fatalf("verdict=%q reason=%q want not_applicable/row_has_no_deliverables", v.Verdict, v.Reason)
	}
}

func TestComputeOwnershipMissingRow(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	root := t.TempDir()

	v := computeOwnership(root, "nonexistent", "internal/cli/foo.go")
	if v.Verdict != "not_applicable" || v.Reason != "row_definition_unreadable" {
		t.Fatalf("verdict=%q reason=%q want not_applicable/row_definition_unreadable", v.Verdict, v.Reason)
	}
}

func TestComputeOwnershipDeterministicFirstMatch(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	def := `objective: "x"
deliverables:
  - name: first
    file_ownership:
      - "internal/cli/shared.go"
  - name: second
    file_ownership:
      - "internal/cli/shared.go"
context_pointers:
  - path: "/tmp"
    note: "n"
constraints: []
gate_policy: supervised
`
	root := fixtureRoot(t, "fix", def)

	v := computeOwnership(root, "fix", "internal/cli/shared.go")
	if v.Verdict != "in_scope" {
		t.Fatalf("verdict: %q", v.Verdict)
	}
	if v.MatchedDeliverable != "first" {
		t.Fatalf("matched_deliverable: got %q, want first (deterministic order)", v.MatchedDeliverable)
	}
}

func TestGlobMatchVariants(t *testing.T) {
	cases := []struct {
		glob  string
		path  string
		match bool
	}{
		{"foo.go", "foo.go", true},
		{"foo.go", "bar.go", false},
		{"*.go", "foo.go", true},
		{"*.go", "sub/foo.go", false},
		{"**/*.go", "foo.go", true},
		{"**/*.go", "sub/foo.go", true},
		{"**/*.go", "sub/sub/foo.go", true},
		{"internal/**/*.go", "internal/cli/foo.go", true},
		{"internal/**/*.go", "external/foo.go", false},
		{"foo.?", "foo.a", true},
		{"foo.?", "foo.ab", false},
	}
	for _, c := range cases {
		got := globMatch(c.glob, c.path)
		if got != c.match {
			t.Errorf("globMatch(%q, %q) = %v, want %v", c.glob, c.path, got, c.match)
		}
	}
}

// mustLinkSchemas is a helper for tests that need the live schemas/ directory
// from the real repo present under a temp Furrow root. We symlink instead of
// copy so taxonomy reloads pick up any in-repo changes during the test run.
func mustLinkSchemas(t *testing.T, repoRoot, targetRoot string) {
	t.Helper()
	src := filepath.Join(repoRoot, "schemas")
	dst := filepath.Join(targetRoot, "schemas")
	if err := os.Symlink(src, dst); err != nil {
		t.Fatalf("symlink schemas: %v", err)
	}
}
