package context_test

// contracts_test.go — in-package proof that the conformance harness is
// non-vacuous. Each in-test fake implements the contract; the standard Test*
// wrappers here call the exported harness (TestBuilderConformance,
// TestStrategyConformance, TestChainNodeConformance) to exercise them.
//
// D4's strategies_test.go calls the same exported harness functions per step.

import (
	"testing"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
)

// ---------------------------------------------------------------------------
// In-test fakes
// ---------------------------------------------------------------------------

// fakeBuilder is a minimal Builder implementation proving the harness works.
type fakeBuilder struct {
	consumed   bool
	skills     []ctx.Skill
	references []ctx.Reference
	artifact   ctx.Artifact
	decisions  []ctx.Decision
	metadata   map[string]any
}

func newFakeBuilder() ctx.Builder { return &fakeBuilder{} }

func (b *fakeBuilder) Reset() {
	b.consumed = false
	b.skills = nil
	b.references = nil
	b.artifact = ctx.Artifact{}
	b.decisions = nil
	b.metadata = nil
}

func (b *fakeBuilder) AddSkill(s ctx.Skill)         { b.skills = append(b.skills, s) }
func (b *fakeBuilder) AddReference(r ctx.Reference) { b.references = append(b.references, r) }
func (b *fakeBuilder) AddArtifact(a ctx.Artifact)   { b.artifact = a }
func (b *fakeBuilder) AddDecision(d ctx.Decision)   { b.decisions = append(b.decisions, d) }
func (b *fakeBuilder) AddLearning(l ctx.Learning) {
	b.artifact.Learnings = append(b.artifact.Learnings, l)
}
func (b *fakeBuilder) SetMetadata(key string, val any) {
	if b.metadata == nil {
		b.metadata = map[string]any{}
	}
	b.metadata[key] = val
}

func (b *fakeBuilder) Build() (ctx.Bundle, error) {
	if b.consumed {
		return ctx.Bundle{}, ctx.ErrBuilderConsumed
	}
	b.consumed = true
	return ctx.Bundle{
		Skills:               b.skills,
		References:           b.references,
		PriorArtifacts:       b.artifact,
		Decisions:            b.decisions,
		StepStrategyMetadata: b.metadata,
	}, nil
}

// fakeSource is a minimal ContextSource fixture.
type fakeSource struct {
	row    string
	step   string
	target string
}

func (s *fakeSource) Row() string    { return s.row }
func (s *fakeSource) Step() string   { return s.step }
func (s *fakeSource) Target() string { return s.target }

func (s *fakeSource) ReadState() (map[string]any, error) {
	return map[string]any{"step": s.step}, nil
}
func (s *fakeSource) ReadSummary() (map[string]any, error)      { return map[string]any{}, nil }
func (s *fakeSource) ReadGateEvidence() (map[string]any, error) { return map[string]any{}, nil }
func (s *fakeSource) ReadLearnings() ([]ctx.Learning, error)    { return nil, nil }

func (s *fakeSource) ListSkills() ([]ctx.Skill, error) {
	return []ctx.Skill{
		{Path: "skills/" + s.step + ".md", Layer: "step", Content: "# " + s.step},
	}, nil
}

func (s *fakeSource) ListReferences() ([]ctx.Reference, error) {
	return []ctx.Reference{{Path: "references/gate-protocol.md"}}, nil
}

// fakeStrategy is a trivial Strategy that loads skills from the source.
type fakeStrategy struct{ step string }

func newFakeStrategy() ctx.Strategy { return &fakeStrategy{step: "ideate"} }

func (s *fakeStrategy) Step() string { return s.step }

func (s *fakeStrategy) Apply(b ctx.Builder, src ctx.ContextSource) error {
	skills, err := src.ListSkills()
	if err != nil {
		return err
	}
	for _, sk := range skills {
		b.AddSkill(sk)
	}
	return nil
}

// fakeChainNode is a terminal ChainNode that loads references from the source.
type fakeChainNode struct{}

func newFakeChainNode() ctx.ChainNode { return &fakeChainNode{} }

func (n *fakeChainNode) Next() ctx.ChainNode { return nil }

func (n *fakeChainNode) Apply(b ctx.Builder, src ctx.ContextSource) error {
	refs, err := src.ListReferences()
	if err != nil {
		return err
	}
	for _, r := range refs {
		b.AddReference(r)
	}
	return nil
}

// ---------------------------------------------------------------------------
// Standard Test* wrappers — prove harness non-vacuous.
// ---------------------------------------------------------------------------

// TestBuilderConformance_Fake exercises the exported harness against fakeBuilder,
// proving that the harness is callable and non-trivially exercised by an
// implementation that satisfies the contract.
func TestBuilderConformance_Fake(t *testing.T) {
	ctx.TestBuilderConformance(t, newFakeBuilder)
}

// TestStrategyConformance_Fake exercises the exported harness against fakeStrategy.
func TestStrategyConformance_Fake(t *testing.T) {
	src := &fakeSource{row: "test-row", step: "ideate", target: "operator"}
	ctx.TestStrategyConformance(t, newFakeStrategy, src)
}

// TestChainNodeConformance_Fake exercises the exported harness against fakeChainNode.
func TestChainNodeConformance_Fake(t *testing.T) {
	src := &fakeSource{row: "test-row", step: "ideate", target: "operator"}
	ctx.TestChainNodeConformance(t, newFakeChainNode, src)
}

// TestSentinelErrors verifies that sentinel errors are distinct and non-nil.
func TestSentinelErrors(t *testing.T) {
	errs := []struct {
		name string
		err  error
	}{
		{"ErrBuilderConsumed", ctx.ErrBuilderConsumed},
		{"ErrStrategyStepUnknown", ctx.ErrStrategyStepUnknown},
		{"ErrChainTerminated", ctx.ErrChainTerminated},
	}
	for _, tc := range errs {
		if tc.err == nil {
			t.Errorf("%s must not be nil", tc.name)
		}
		if tc.err.Error() == "" {
			t.Errorf("%s.Error() must not be empty", tc.name)
		}
	}
	// Verify distinctness.
	if ctx.ErrBuilderConsumed == ctx.ErrStrategyStepUnknown {
		t.Error("ErrBuilderConsumed and ErrStrategyStepUnknown must be distinct")
	}
	if ctx.ErrBuilderConsumed == ctx.ErrChainTerminated {
		t.Error("ErrBuilderConsumed and ErrChainTerminated must be distinct")
	}
	if ctx.ErrStrategyStepUnknown == ctx.ErrChainTerminated {
		t.Error("ErrStrategyStepUnknown and ErrChainTerminated must be distinct")
	}
}
