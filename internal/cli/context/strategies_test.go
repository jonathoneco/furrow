package context_test

import (
	"os"
	"strings"
	"testing"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
	"github.com/jonathoneco/furrow/internal/cli/context/strategies"
)

// ---------------------------------------------------------------------------
// D5 conformance harness: one test per strategy (7 strategies, 7 tests).
// ---------------------------------------------------------------------------

func TestStrategy_Ideate_Conformance(t *testing.T) {
	src := &fakeSource{row: "test-row", step: "ideate", target: "driver"}
	ctx.TestStrategyConformance(t, func() ctx.Strategy { return strategies.NewIdeateStrategy() }, src)
}

func TestStrategy_Research_Conformance(t *testing.T) {
	src := &fakeSource{row: "test-row", step: "research", target: "driver"}
	ctx.TestStrategyConformance(t, func() ctx.Strategy { return strategies.NewResearchStrategy() }, src)
}

func TestStrategy_Plan_Conformance(t *testing.T) {
	src := &fakeSource{row: "test-row", step: "plan", target: "driver"}
	ctx.TestStrategyConformance(t, func() ctx.Strategy { return strategies.NewPlanStrategy() }, src)
}

func TestStrategy_Spec_Conformance(t *testing.T) {
	src := &fakeSource{row: "test-row", step: "spec", target: "driver"}
	ctx.TestStrategyConformance(t, func() ctx.Strategy { return strategies.NewSpecStrategy() }, src)
}

func TestStrategy_Decompose_Conformance(t *testing.T) {
	src := &fakeSource{row: "test-row", step: "decompose", target: "driver"}
	ctx.TestStrategyConformance(t, func() ctx.Strategy { return strategies.NewDecomposeStrategy() }, src)
}

func TestStrategy_Implement_Conformance(t *testing.T) {
	src := &fakeSource{row: "test-row", step: "implement", target: "driver"}
	ctx.TestStrategyConformance(t, func() ctx.Strategy { return strategies.NewImplementStrategy() }, src)
}

func TestStrategy_Review_Conformance(t *testing.T) {
	src := &fakeSource{row: "test-row", step: "review", target: "driver"}
	ctx.TestStrategyConformance(t, func() ctx.Strategy { return strategies.NewReviewStrategy() }, src)
}

// ---------------------------------------------------------------------------
// Step name invariants.
// ---------------------------------------------------------------------------

func TestStrategy_StepNames(t *testing.T) {
	cases := []struct {
		name     string
		strategy ctx.Strategy
		want     string
	}{
		{"ideate", strategies.NewIdeateStrategy(), "ideate"},
		{"research", strategies.NewResearchStrategy(), "research"},
		{"plan", strategies.NewPlanStrategy(), "plan"},
		{"spec", strategies.NewSpecStrategy(), "spec"},
		{"decompose", strategies.NewDecomposeStrategy(), "decompose"},
		{"implement", strategies.NewImplementStrategy(), "implement"},
		{"review", strategies.NewReviewStrategy(), "review"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := tc.strategy.Step(); got != tc.want {
				t.Errorf("Step() = %q, want %q", got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Registry: all 7 strategies registered.
// ---------------------------------------------------------------------------

func TestRegistry_AllStrategiesRegistered(t *testing.T) {
	steps := []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}
	for _, step := range steps {
		t.Run(step, func(t *testing.T) {
			s, err := ctx.LookupStrategy(step)
			if err != nil {
				t.Fatalf("LookupStrategy(%q): %v", step, err)
			}
			if s == nil {
				t.Errorf("LookupStrategy(%q): returned nil strategy", step)
			}
			if s.Step() != step {
				t.Errorf("strategy.Step() = %q, want %q", s.Step(), step)
			}
		})
	}
}

// TestRegistry_UnknownStepReturnsError verifies unregistered steps fail fast.
func TestRegistry_UnknownStepReturnsError(t *testing.T) {
	_, err := ctx.LookupStrategy("nonexistent-step")
	if err == nil {
		t.Fatal("expected error for unknown step, got nil")
	}
	if !strings.Contains(err.Error(), "nonexistent-step") {
		t.Errorf("error should mention the step name: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Target filtering integration.
// ---------------------------------------------------------------------------

func TestTargetFilter_DriverDoesNotIncludeOperator(t *testing.T) {
	b := ctx.NewBundleBuilder("r", "ideate", "driver")
	b.AddSkill(ctx.Skill{Path: "op.md", Layer: "operator", Content: "op"})
	b.AddSkill(ctx.Skill{Path: "dr.md", Layer: "driver", Content: "dr"})
	b.AddSkill(ctx.Skill{Path: "sh.md", Layer: "shared", Content: "sh"})

	src := &fakeSource{row: "r", step: "ideate", target: "driver"}
	node := ctx.NewTargetFilterNode()
	if err := node.Apply(b, src); err != nil {
		t.Fatalf("Apply: %v", err)
	}
	bundle, _ := b.Build()
	for _, sk := range bundle.Skills {
		if sk.Layer == "operator" {
			t.Errorf("driver target must not include operator skills")
		}
	}
}

func TestTargetFilter_SpecialistInjectsEngineLayer(t *testing.T) {
	b := ctx.NewBundleBuilder("r", "implement", "specialist:go-specialist")
	b.AddSkill(ctx.Skill{Path: "en.md", Layer: "engine", Content: "engine"})
	b.AddSkill(ctx.Skill{Path: "op.md", Layer: "operator", Content: "operator"})
	b.AddSkill(ctx.Skill{Path: "sh.md", Layer: "shared", Content: "shared"})

	src := &fakeSource{row: "r", step: "implement", target: "specialist:go-specialist"}
	node := ctx.NewTargetFilterNode()
	if err := node.Apply(b, src); err != nil {
		t.Fatalf("Apply: %v", err)
	}
	bundle, _ := b.Build()
	for _, sk := range bundle.Skills {
		if sk.Layer != "engine" && sk.Layer != "shared" {
			t.Errorf("specialist target must only include engine/shared, got %q", sk.Layer)
		}
	}
}

// ---------------------------------------------------------------------------
// Decisions extraction: fixture from pre-write-validation-go-first.
// ---------------------------------------------------------------------------

func TestDecisionsExtraction_PreWriteValidationFixture(t *testing.T) {
	root := furrowRoot(t)
	summaryPath := root + "/.furrow/rows/pre-write-validation-go-first/summary.md"
	data, err := os.ReadFile(summaryPath)
	if err != nil {
		t.Skipf("fixture not available: %v", err)
	}

	decisions := ctx.ExtractDecisions(string(data), "review")

	if len(decisions) == 0 {
		t.Fatal("expected at least one decision from pre-write-validation-go-first summary.md")
	}

	// Verify structure of each decision.
	for i, d := range decisions {
		if d.Source != "settled_decisions" && d.Source != "key_findings_prose" {
			t.Errorf("decision[%d]: invalid source %q", i, d.Source)
		}
		if d.Outcome != "pass" && d.Outcome != "fail" && d.Outcome != "unknown" {
			t.Errorf("decision[%d]: invalid outcome %q", i, d.Outcome)
		}
		if d.Ordinal < 0 {
			t.Errorf("decision[%d]: ordinal must be >= 0, got %d", i, d.Ordinal)
		}
	}

	// Check de-dup: plan->spec appears twice in the fixture (retry).
	// After de-dup we should see exactly one plan->spec with outcome=pass.
	planSpecCount := 0
	for _, d := range decisions {
		if d.FromStep == "plan" && d.ToStep == "spec" {
			planSpecCount++
			if d.Outcome != "pass" {
				t.Errorf("plan->spec should be pass (last-wins), got %q", d.Outcome)
			}
		}
	}
	if planSpecCount != 1 {
		t.Errorf("plan->spec de-dup: expected 1 entry, got %d", planSpecCount)
	}

	t.Logf("extracted %d decisions from pre-write-validation-go-first fixture", len(decisions))
}

// ---------------------------------------------------------------------------
// Learnings filtering.
// ---------------------------------------------------------------------------

func TestLearnings_EngineFiltersToApplicable(t *testing.T) {
	b := ctx.NewBundleBuilder("r", "review", "engine")
	b.AddLearning(ctx.Learning{ID: "L1", Body: "broad", BroadlyApplicable: true})
	b.AddLearning(ctx.Learning{ID: "L2", Body: "narrow", BroadlyApplicable: false})
	b.AddLearning(ctx.Learning{ID: "L3", Body: "also broad", BroadlyApplicable: true})

	src := &fakeSource{row: "r", step: "review", target: "engine"}
	node := ctx.NewTargetFilterNode()
	if err := node.Apply(b, src); err != nil {
		t.Fatalf("Apply: %v", err)
	}
	bundle, _ := b.Build()

	for _, l := range bundle.PriorArtifacts.Learnings {
		if !l.BroadlyApplicable {
			t.Errorf("engine target must exclude broadly_applicable=false learnings, got %q", l.ID)
		}
	}
	if len(bundle.PriorArtifacts.Learnings) != 2 {
		t.Errorf("expected 2 broadly_applicable learnings, got %d", len(bundle.PriorArtifacts.Learnings))
	}
}

// ---------------------------------------------------------------------------
// Missing skill layer rejection.
// ---------------------------------------------------------------------------

type erroringSkillSource struct {
	fakeSource
}

func (s *erroringSkillSource) ListSkills() ([]ctx.Skill, error) {
	return []ctx.Skill{
		{Path: "missing-layer.md", Layer: "MISSING", Content: "no layer tag"},
	}, nil
}

// TestMissingSkillLayer_StrategyToleratesMissing verifies that strategies
// themselves do not reject skills with MISSING layers — that is the cmd.go's
// responsibility (blocker emission). Strategies pass skills through.
func TestMissingSkillLayer_StrategyToleratesMissing(t *testing.T) {
	src := &erroringSkillSource{fakeSource: fakeSource{row: "r", step: "ideate", target: "driver"}}
	s := strategies.NewIdeateStrategy()
	b := ctx.NewBundleBuilder("r", "ideate", "driver")
	// Apply should not fail even with MISSING layer.
	err := s.Apply(b, src)
	if err != nil {
		t.Fatalf("strategy.Apply with MISSING layer: unexpected error: %v", err)
	}
}

// ---------------------------------------------------------------------------
// R9 — ListSkills covers skills/shared/* and specialist injection.
// ---------------------------------------------------------------------------

// TestListSkills_SharedSkillsIncluded verifies that ListSkills returns at
// least one skills/shared/* file (recursive walk correctness).
func TestListSkills_SharedSkillsIncluded(t *testing.T) {
	root := furrowRoot(t)
	src := ctx.NewFileContextSource(root, "pre-write-validation-go-first", "plan", "driver")
	skills, err := src.ListSkills()
	if err != nil {
		t.Fatalf("ListSkills: %v", err)
	}
	foundShared := false
	for _, sk := range skills {
		if len(sk.Path) > 13 && sk.Path[:13] == "skills/shared" {
			foundShared = true
			break
		}
	}
	if !foundShared {
		t.Errorf("ListSkills: no skills/shared/* files found; expected at least one from skills/shared/")
	}
}

// TestListSkills_SpecialistBriefInjected verifies that when target is
// specialist:{id}, the specialists/{id}.md brief is included as an
// engine-layer skill.
func TestListSkills_SpecialistBriefInjected(t *testing.T) {
	root := furrowRoot(t)
	src := ctx.NewFileContextSource(root, "pre-write-validation-go-first", "implement", "specialist:go-specialist")
	skills, err := src.ListSkills()
	if err != nil {
		t.Fatalf("ListSkills: %v", err)
	}
	var brief *ctx.Skill
	for i := range skills {
		if skills[i].Path == "specialists/go-specialist.md" {
			brief = &skills[i]
			break
		}
	}
	if brief == nil {
		t.Fatal("ListSkills with specialist:go-specialist: specialists/go-specialist.md not in skills list")
	}
	if brief.Layer != "engine" {
		t.Errorf("specialist brief must have layer=engine, got %q", brief.Layer)
	}
}

// ---------------------------------------------------------------------------
// R6 — Chain ordering: target filter runs after strategy adds skills.
// ---------------------------------------------------------------------------

// TestChainOrdering_StrategySkillsAreFiltered verifies that skills added by
// strategy.Apply are subject to TargetFilterNode (i.e., strategy runs before
// the target filter in the chain).
func TestChainOrdering_StrategySkillsAreFiltered(t *testing.T) {
	// Use a real FileContextSource and BuildChainWithStrategy. The driver target
	// must contain ONLY driver|shared layers; if strategy ran AFTER the filter,
	// all unfiltered skills would be present.
	root := furrowRoot(t)
	row := "pre-write-validation-go-first"
	step := "plan"
	target := "driver"

	src := ctx.NewFileContextSource(root, row, step, target)
	b := ctx.NewBundleBuilder(row, step, target)

	s, err := ctx.LookupStrategy(step)
	if err != nil {
		t.Fatalf("LookupStrategy(%q): %v", step, err)
	}

	chain := ctx.BuildChainWithStrategy(s)
	if err := ctx.WalkChain(chain, b, src); err != nil {
		t.Fatalf("WalkChain: %v", err)
	}

	bundle, err := b.Build()
	if err != nil {
		t.Fatalf("Build: %v", err)
	}

	if len(bundle.Skills) == 0 {
		t.Fatal("expected non-empty skills after chain walk with driver target")
	}

	for _, sk := range bundle.Skills {
		if sk.Layer != "driver" && sk.Layer != "shared" {
			t.Errorf("driver target bundle contains skill with layer=%q (path=%s); want driver or shared only", sk.Layer, sk.Path)
		}
	}
}

// TestChainOrdering_DifferentTargetsDifferentSkills is a regression guard for
// R6: operator, driver, and specialist:go-specialist targets must produce
// distinct skill layer sets.
func TestChainOrdering_DifferentTargetsDifferentSkills(t *testing.T) {
	root := furrowRoot(t)
	row := "pre-write-validation-go-first"
	step := "plan"

	buildBundle := func(target string) ctx.Bundle {
		src := ctx.NewFileContextSource(root, row, step, target)
		b := ctx.NewBundleBuilder(row, step, target)
		s, err := ctx.LookupStrategy(step)
		if err != nil {
			t.Fatalf("LookupStrategy: %v", err)
		}
		chain := ctx.BuildChainWithStrategy(s)
		if err := ctx.WalkChain(chain, b, src); err != nil {
			t.Fatalf("WalkChain (target=%s): %v", target, err)
		}
		bundle, err := b.Build()
		if err != nil {
			t.Fatalf("Build (target=%s): %v", target, err)
		}
		return bundle
	}

	opBundle := buildBundle("operator")
	drBundle := buildBundle("driver")
	spBundle := buildBundle("specialist:go-specialist")

	// Collect unique layers per bundle.
	uniqueLayers := func(b ctx.Bundle) map[string]bool {
		m := map[string]bool{}
		for _, sk := range b.Skills {
			m[sk.Layer] = true
		}
		return m
	}

	opLayers := uniqueLayers(opBundle)
	drLayers := uniqueLayers(drBundle)
	spLayers := uniqueLayers(spBundle)

	// operator must have operator layer; driver must not.
	if !opLayers["operator"] {
		t.Error("operator target: expected operator layer in skills")
	}
	if drLayers["operator"] {
		t.Error("driver target: must not contain operator-layer skills")
	}

	// driver must have driver layer; operator must not.
	if !drLayers["driver"] {
		t.Error("driver target: expected driver layer in skills")
	}
	if opLayers["driver"] {
		t.Error("operator target: must not contain driver-layer skills")
	}

	// specialist target must have engine layer; operator and driver must not.
	if !spLayers["engine"] {
		t.Error("specialist target: expected engine layer in skills")
	}
	if opLayers["engine"] {
		t.Error("operator target: must not contain engine-layer skills")
	}
	if drLayers["engine"] {
		t.Error("driver target: must not contain engine-layer skills")
	}
}

