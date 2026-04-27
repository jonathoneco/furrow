package strategies

import (
	"fmt"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
)

// PlanStrategy implements the Strategy pattern (D5 contract) for the plan step.
// Plan synthesises research findings into a structured work plan (plan.json)
// and team-plan.md, grounded in the ideate→research decision.
//
// Context rules for plan:
//   - Loads skills tagged for the plan step.
//   - Prior artifacts: research synthesis + state.json; surfaces ideate→research
//     gate decision from summary.md Settled Decisions.
//   - References: research artifacts (research.md, per-topic files).
//   - Metadata: has_research=bool (whether research.md is non-empty in summary).
//
// implements D5 Strategy pattern; see internal/cli/context/contracts.go
type PlanStrategy struct{}

// NewPlanStrategy constructs a PlanStrategy.
func NewPlanStrategy() ctx.Strategy { return &PlanStrategy{} }

// Step returns "plan".
func (s *PlanStrategy) Step() string { return "plan" }

// Apply populates b from src according to plan step context rules.
func (s *PlanStrategy) Apply(b ctx.Builder, src ctx.ContextSource) error {
	skills, err := src.ListSkills()
	if err != nil {
		return fmt.Errorf("plan strategy: list skills: %w", err)
	}
	for _, sk := range skills {
		b.AddSkill(sk)
	}

	refs, err := src.ListReferences()
	if err != nil {
		return fmt.Errorf("plan strategy: list references: %w", err)
	}
	for _, r := range refs {
		b.AddReference(r)
	}

	state, err := src.ReadState()
	if err != nil {
		return fmt.Errorf("plan strategy: read state: %w", err)
	}
	if state == nil {
		state = map[string]any{}
	}

	summary, err := src.ReadSummary()
	if err != nil {
		return fmt.Errorf("plan strategy: read summary: %w", err)
	}
	if summary == nil {
		summary = map[string]any{}
	}

	evidence, err := src.ReadGateEvidence()
	if err != nil {
		return fmt.Errorf("plan strategy: read gate evidence: %w", err)
	}
	if evidence == nil {
		evidence = map[string]any{}
	}

	learnings, err := src.ReadLearnings()
	if err != nil {
		return fmt.Errorf("plan strategy: read learnings: %w", err)
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
	ctx.RegisterStrategy(NewPlanStrategy())
}
