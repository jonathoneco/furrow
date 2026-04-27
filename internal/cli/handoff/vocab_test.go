package handoff

import "testing"

// TestVocabCorpus validates the FurrowVocabPattern against a 50-string corpus:
// 25 must-pass (benign English that should NOT match) and
// 25 must-fail (Furrow-laden strings that MUST match).
func TestVocabCorpus(t *testing.T) {
	// mustPass: benign strings that should NOT trigger Furrow vocab detection.
	mustPass := []string{
		// Plain English using words that previously false-positived on bare \bstep\b / \brow\b.
		"step through the function call graph",
		"iterate over each row of items in the table",
		"the next step is to run the tests",
		"a single row of data",
		"move one step at a time",
		"bootstrap the database with a seed row",
		// Tool-like words used in non-Furrow contexts.
		"use sed to transform the file",
		"run npm install",
		"call git status",
		"execute the shell script",
		"configure the adapter",
		"check the definition of the function",
		// Partial matches that should NOT fire (no boundary or prefix mismatch).
		"rwspace is a coworking company",
		"the old almanacks (plural, different word) were useful references",
		"the soul of the deliverer",
		"blockering is not a real word",
		"gate_policies_extended is a different key entirely",
		// Technical prose without Furrow context.
		"update the JSON schema draft",
		"parse the YAML configuration",
		"write integration tests",
		"validate the input before processing",
		"the context bundle holds compiled data",
		"emit structured log entries",
		"the artifact was produced by the build system",
		"check the status of the pipeline",
	}

	// mustFail: Furrow-laden strings that MUST trigger Furrow vocab detection.
	mustFail := []string{
		// gate_policy token.
		"respect the gate_policy at all times",
		"gate_policy is set to supervised",
		"override gate_policy for this run",
		// deliverable token.
		"complete the deliverable before the gate",
		"this deliverable is owned by the go-specialist",
		"update the deliverable status",
		// blocker token.
		"there is a blocker preventing progress",
		"raise a blocker envelope",
		"the blocker code is handoff_schema_invalid",
		// almanac token.
		"check the almanac for prior decisions",
		"almanac entry created",
		"promote to the almanac",
		// rationale.yaml token.
		"see rationale.yaml for the decision record",
		"rationale.yaml was updated",
		// .furrow/ path.
		".furrow/rows/my-row/state.json",
		"read from .furrow/rows/",
		".furrow/almanac/rationale.yaml",
		// furrow command combos.
		"furrow row status my-row",
		"furrow context bundle --row my-row",
		"furrow handoff render --target driver:research",
		"furrow validate definition --path definition.yaml",
		"furrow gate run --step implement",
		// rws/alm/sds with trailing space.
		"rws transition my-row implement pass",
		"alm promote learning",
		"sds create my-seed",
	}

	t.Run("must_pass_benign", func(t *testing.T) {
		for _, s := range mustPass {
			if ContainsFurrowVocab(s) {
				t.Errorf("false positive: %q matched FurrowVocabPattern (should be benign)", s)
			}
		}
	})

	t.Run("must_fail_furrow_laden", func(t *testing.T) {
		for _, s := range mustFail {
			if !ContainsFurrowVocab(s) {
				t.Errorf("false negative: %q did not match FurrowVocabPattern (should be Furrow-laden)", s)
			}
		}
	})
}
