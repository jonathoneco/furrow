package strategies

import (
	"fmt"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
)

// ReviewStrategy implements the Strategy pattern (D5 contract) for the review
// step. Review evaluates the full row output, requiring the complete decision
// history and all learnings filtered by target audience.
//
// Context rules for review:
//   - Loads skills tagged for the review step.
//   - Prior artifacts: full summary.md, reviews/ directory artifacts, complete
//     decision history; learnings filtered per target (engine → broadly_applicable only).
//   - Metadata: review_round derived from gate evidence for implement→review.
//
// implements D5 Strategy pattern; see internal/cli/context/contracts.go
type ReviewStrategy struct{}

// NewReviewStrategy constructs a ReviewStrategy.
func NewReviewStrategy() ctx.Strategy { return &ReviewStrategy{} }

// Step returns "review".
func (s *ReviewStrategy) Step() string { return "review" }

// Apply populates b from src according to review step context rules.
func (s *ReviewStrategy) Apply(b ctx.Builder, src ctx.ContextSource) error {
	skills, err := src.ListSkills()
	if err != nil {
		return fmt.Errorf("review strategy: list skills: %w", err)
	}
	for _, sk := range skills {
		b.AddSkill(sk)
	}

	refs, err := src.ListReferences()
	if err != nil {
		return fmt.Errorf("review strategy: list references: %w", err)
	}
	for _, r := range refs {
		b.AddReference(r)
	}

	state, err := src.ReadState()
	if err != nil {
		return fmt.Errorf("review strategy: read state: %w", err)
	}
	if state == nil {
		state = map[string]any{}
	}

	summary, err := src.ReadSummary()
	if err != nil {
		return fmt.Errorf("review strategy: read summary: %w", err)
	}
	if summary == nil {
		summary = map[string]any{}
	}

	evidence, err := src.ReadGateEvidence()
	if err != nil {
		return fmt.Errorf("review strategy: read gate evidence: %w", err)
	}
	if evidence == nil {
		evidence = map[string]any{}
	}

	learnings, err := src.ReadLearnings()
	if err != nil {
		return fmt.Errorf("review strategy: read learnings: %w", err)
	}

	b.AddArtifact(ctx.Artifact{
		State:           state,
		SummarySections: summary,
		GateEvidence:    evidence,
		Learnings:       learnings,
	})

	return nil
}

func init() {
	ctx.RegisterStrategy(NewReviewStrategy())
}
