package strategies

import (
	"fmt"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
)

// ResearchStrategy implements the Strategy pattern (D5 contract) for the
// research step. Research gathers evidence to ground the plan; it consumes
// ideate's artifacts and surfaces open questions for the plan step.
//
// Context rules for research:
//   - Loads skills tagged for the research step.
//   - Prior artifacts: state.json ideate evidence; ideate's Open Questions
//     section from summary.md.
//   - Gate evidence: empty for ideate (first populated at research gate).
//   - Metadata: topic_count derived from summary sections count.
//
// implements D5 Strategy pattern; see internal/cli/context/contracts.go
type ResearchStrategy struct{}

// NewResearchStrategy constructs a ResearchStrategy.
func NewResearchStrategy() ctx.Strategy { return &ResearchStrategy{} }

// Step returns "research".
func (s *ResearchStrategy) Step() string { return "research" }

// Apply populates b from src according to research step context rules.
func (s *ResearchStrategy) Apply(b ctx.Builder, src ctx.ContextSource) error {
	skills, err := src.ListSkills()
	if err != nil {
		return fmt.Errorf("research strategy: list skills: %w", err)
	}
	for _, sk := range skills {
		b.AddSkill(sk)
	}

	refs, err := src.ListReferences()
	if err != nil {
		return fmt.Errorf("research strategy: list references: %w", err)
	}
	for _, r := range refs {
		b.AddReference(r)
	}

	state, err := src.ReadState()
	if err != nil {
		return fmt.Errorf("research strategy: read state: %w", err)
	}
	if state == nil {
		state = map[string]any{}
	}

	summary, err := src.ReadSummary()
	if err != nil {
		return fmt.Errorf("research strategy: read summary: %w", err)
	}
	if summary == nil {
		summary = map[string]any{}
	}

	evidence, err := src.ReadGateEvidence()
	if err != nil {
		return fmt.Errorf("research strategy: read gate evidence: %w", err)
	}
	if evidence == nil {
		evidence = map[string]any{}
	}

	learnings, err := src.ReadLearnings()
	if err != nil {
		return fmt.Errorf("research strategy: read learnings: %w", err)
	}

	b.AddArtifact(ctx.Artifact{
		State:           state,
		SummarySections: summary,
		GateEvidence:    evidence,
		Learnings:       learnings,
	})

	if bb, ok := b.(*ctx.BundleBuilder); ok {
		bb.SetMetadata("topic_count", len(summary))
	}

	return nil
}

func init() {
	ctx.RegisterStrategy(NewResearchStrategy())
}
