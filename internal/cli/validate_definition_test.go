package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeDefinitionFixture(t *testing.T, dir, body string) string {
	t.Helper()
	path := filepath.Join(dir, "definition.yaml")
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatalf("write fixture: %v", err)
	}
	return path
}

// validDefinitionFixture is a minimal-but-valid definition for tests.
const validDefinitionFixture = `objective: "test fixture for D1 validator"
deliverables:
  - name: thing
    acceptance_criteria:
      - "thing does the thing"
context_pointers:
  - path: "/tmp/foo"
    note: "fixture pointer"
constraints:
  - "no real constraints"
gate_policy: supervised
mode: code
`

func TestValidateDefinitionHappyPath(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, err := LoadTaxonomy()
	if err != nil {
		t.Fatalf("LoadTaxonomy: %v", err)
	}

	dir := t.TempDir()
	path := writeDefinitionFixture(t, dir, validDefinitionFixture)

	envs := validateDefinition(path, tx)
	if len(envs) != 0 {
		t.Fatalf("expected 0 errors, got %d: %+v", len(envs), envs)
	}
}

func TestValidateDefinitionMissingObjective(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, err := LoadTaxonomy()
	if err != nil {
		t.Fatalf("LoadTaxonomy: %v", err)
	}

	body := strings.Replace(validDefinitionFixture, `objective: "test fixture for D1 validator"`, "", 1)
	path := writeDefinitionFixture(t, t.TempDir(), body)

	envs := validateDefinition(path, tx)
	assertHasCode(t, envs, "definition_objective_missing")
}

func TestValidateDefinitionMissingGatePolicy(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := strings.Replace(validDefinitionFixture, "gate_policy: supervised", "", 1)
	path := writeDefinitionFixture(t, t.TempDir(), body)

	envs := validateDefinition(path, tx)
	assertHasCode(t, envs, "definition_gate_policy_missing")
}

func TestValidateDefinitionInvalidGatePolicy(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := strings.Replace(validDefinitionFixture, "gate_policy: supervised", "gate_policy: foo", 1)
	path := writeDefinitionFixture(t, t.TempDir(), body)

	envs := validateDefinition(path, tx)
	env := assertHasCode(t, envs, "definition_gate_policy_invalid")
	if !strings.Contains(env.Message, "foo") {
		t.Fatalf("message does not include the bad value: %q", env.Message)
	}
}

func TestValidateDefinitionInvalidMode(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := strings.Replace(validDefinitionFixture, "mode: code", "mode: bogus", 1)
	path := writeDefinitionFixture(t, t.TempDir(), body)

	envs := validateDefinition(path, tx)
	assertHasCode(t, envs, "definition_mode_invalid")
}

func TestValidateDefinitionEmptyDeliverables(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := `objective: "x"
deliverables: []
context_pointers:
  - path: "/tmp"
    note: "n"
constraints: []
gate_policy: supervised
`
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	assertHasCode(t, envs, "definition_deliverables_empty")
}

func TestValidateDefinitionDeliverableNameMissing(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := `objective: "x"
deliverables:
  - acceptance_criteria:
      - "do thing"
context_pointers:
  - path: "/tmp"
    note: "n"
constraints: []
gate_policy: supervised
`
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	assertHasCode(t, envs, "definition_deliverable_name_missing")
}

func TestValidateDefinitionDeliverableNameBadPattern(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := strings.Replace(validDefinitionFixture, "name: thing", "name: Bad_Name", 1)
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	env := assertHasCode(t, envs, "definition_deliverable_name_invalid_pattern")
	if !strings.Contains(env.Message, "Bad_Name") {
		t.Fatalf("message should name the bad pattern: %q", env.Message)
	}
}

func TestValidateDefinitionPlaceholderAC(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := strings.Replace(validDefinitionFixture,
		`acceptance_criteria:
      - "thing does the thing"`,
		`acceptance_criteria:
      - "TODO write me"`, 1)
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	assertHasCode(t, envs, "definition_acceptance_criteria_placeholder")
}

func TestValidateDefinitionPlaceholderNotFalsePositive(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	// "outbound" contains "tbd" as a substring; word-boundary check should NOT match.
	body := strings.Replace(validDefinitionFixture,
		`acceptance_criteria:
      - "thing does the thing"`,
		`acceptance_criteria:
      - "the outbound queue is processed"`, 1)
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	for _, e := range envs {
		if e.Code == "definition_acceptance_criteria_placeholder" {
			t.Fatalf("false positive on substring 'tbd' in 'outbound'")
		}
	}
}

func TestValidateDefinitionUnknownTopLevelKey(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := validDefinitionFixture + "extra_field: foo\n"
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	env := assertHasCode(t, envs, "definition_unknown_keys")
	if !strings.Contains(env.Message, "extra_field") {
		t.Fatalf("message should name the unknown key: %q", env.Message)
	}
}

func TestValidateDefinitionMalformedYAML(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := "objective: [unclosed\n"
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	assertHasCode(t, envs, "definition_yaml_invalid")
}

func TestRunValidateDefinitionCLIExitCodes(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)

	dir := t.TempDir()
	validPath := writeDefinitionFixture(t, dir, validDefinitionFixture)
	invalidBody := strings.Replace(validDefinitionFixture, "gate_policy: supervised", "gate_policy: bogus", 1)
	invalidPath := writeDefinitionFixture(t, t.TempDir(), invalidBody)

	cases := []struct {
		name               string
		args               []string
		wantExit           int
		wantStdoutContains string
	}{
		{"valid path text", []string{"--path", validPath}, 0, "definition.yaml is valid"},
		{"valid path json", []string{"--path", validPath, "--json"}, 0, "\"verdict\": \"valid\""},
		{"invalid path json", []string{"--path", invalidPath, "--json"}, 3, "\"verdict\": \"invalid\""},
		{"missing path arg", []string{}, 1, ""},
		{"file not found", []string{"--path", filepath.Join(dir, "nonexistent.yaml")}, 1, ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			var stdout, stderr strings.Builder
			app := New(&stdout, &stderr)
			exit := app.runValidateDefinition(c.args)
			if exit != c.wantExit {
				t.Fatalf("exit: got %d want %d (stderr=%q)", exit, c.wantExit, stderr.String())
			}
			if c.wantStdoutContains != "" && !strings.Contains(stdout.String(), c.wantStdoutContains) {
				t.Fatalf("stdout missing %q; got %q", c.wantStdoutContains, stdout.String())
			}
		})
	}
}

func TestValidateDefinitionNestedAdditionalProperties(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := `objective: "x"
deliverables:
  - name: thing
    acceptance_criteria:
      - "do thing"
    bogus_field: yes
context_pointers:
  - path: "/tmp"
    note: "n"
constraints: []
gate_policy: supervised
`
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	env := assertHasCode(t, envs, "definition_unknown_keys")
	if !strings.Contains(env.Message, "bogus_field") {
		t.Fatalf("nested unknown key not surfaced: %q", env.Message)
	}
}

func TestValidateDefinitionMissingAcceptanceCriteria(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := `objective: "x"
deliverables:
  - name: thing
context_pointers:
  - path: "/tmp"
    note: "n"
constraints: []
gate_policy: supervised
`
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	assertHasCode(t, envs, "definition_acceptance_criteria_placeholder")
}

func TestValidateDefinitionContextPointerExtraKey(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := `objective: "x"
deliverables:
  - name: thing
    acceptance_criteria:
      - "do thing"
context_pointers:
  - path: "/tmp"
    note: "n"
    bogus_key: yes
constraints: []
gate_policy: supervised
`
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	env := assertHasCode(t, envs, "definition_unknown_keys")
	if !strings.Contains(env.Message, "context_pointers") || !strings.Contains(env.Message, "bogus_key") {
		t.Fatalf("expected context_pointers/bogus_key in message: %q", env.Message)
	}
}

func TestValidateDefinitionSupersedesExtraKey(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := `objective: "x"
deliverables:
  - name: thing
    acceptance_criteria:
      - "do thing"
context_pointers:
  - path: "/tmp"
    note: "n"
constraints: []
gate_policy: supervised
supersedes:
  commit: abc123
  row: foo-bar
  extra: nope
`
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	env := assertHasCode(t, envs, "definition_unknown_keys")
	if !strings.Contains(env.Message, "supersedes") || !strings.Contains(env.Message, "extra") {
		t.Fatalf("expected supersedes/extra in message: %q", env.Message)
	}
}

func TestValidateDefinitionDeliverableGateInvalid(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := `objective: "x"
deliverables:
  - name: thing
    acceptance_criteria:
      - "do thing"
    gate: robot
context_pointers:
  - path: "/tmp"
    note: "n"
constraints: []
gate_policy: supervised
`
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	env := assertHasCode(t, envs, "definition_unknown_keys")
	if !strings.Contains(env.Message, "gate") || !strings.Contains(env.Message, "robot") {
		t.Fatalf("expected gate/robot in message: %q", env.Message)
	}
}

func TestValidateDefinitionEmptyAcceptanceCriteria(t *testing.T) {
	resetTaxonomyCacheForTest()
	t.Cleanup(resetTaxonomyCacheForTest)
	tx, _ := LoadTaxonomy()

	body := `objective: "x"
deliverables:
  - name: thing
    acceptance_criteria: []
context_pointers:
  - path: "/tmp"
    note: "n"
constraints: []
gate_policy: supervised
`
	path := writeDefinitionFixture(t, t.TempDir(), body)
	envs := validateDefinition(path, tx)
	assertHasCode(t, envs, "definition_acceptance_criteria_placeholder")
}

// assertHasCode finds the first envelope with code; fails the test if absent.
// Returns the matching envelope so callers can make further assertions on it.
func assertHasCode(t *testing.T, envs []BlockerEnvelope, code string) BlockerEnvelope {
	t.Helper()
	for _, e := range envs {
		if e.Code == code {
			return e
		}
	}
	codes := make([]string, len(envs))
	for i, e := range envs {
		codes[i] = e.Code
	}
	t.Fatalf("expected envelope with code %q; got codes: %v", code, codes)
	return BlockerEnvelope{}
}
