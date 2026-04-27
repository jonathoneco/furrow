package strategies

import (
	"fmt"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
)

// SpecStrategy implements the Strategy pattern (D5 contract) for the spec step.
// Spec translates the plan into per-deliverable specifications with acceptance
// criteria, test scenarios, and interface contracts.
//
// Context rules for spec:
//   - Loads skills tagged for the spec step.
//   - Prior artifacts: plan.json, all research artifacts; decisions through plan.
//   - References: plan artifacts + research artifacts.
//   - Metadata: deliverable_count derived from plan deliverables in state.
//
// implements D5 Strategy pattern; see internal/cli/context/contracts.go
type SpecStrategy struct{}

// NewSpecStrategy constructs a SpecStrategy.
func NewSpecStrategy() ctx.Strategy { return &SpecStrategy{} }

// Step returns "spec".
func (s *SpecStrategy) Step() string { return "spec" }

// Apply populates b from src according to spec step context rules.
func (s *SpecStrategy) Apply(b ctx.Builder, src ctx.ContextSource) error {
	skills, err := src.ListSkills()
	if err != nil {
		return fmt.Errorf("spec strategy: list skills: %w", err)
	}
	for _, sk := range skills {
		b.AddSkill(sk)
	}

	refs, err := src.ListReferences()
	if err != nil {
		return fmt.Errorf("spec strategy: list references: %w", err)
	}
	for _, r := range refs {
		b.AddReference(r)
	}

	state, err := src.ReadState()
	if err != nil {
		return fmt.Errorf("spec strategy: read state: %w", err)
	}
	if state == nil {
		state = map[string]any{}
	}

	summary, err := src.ReadSummary()
	if err != nil {
		return fmt.Errorf("spec strategy: read summary: %w", err)
	}
	if summary == nil {
		summary = map[string]any{}
	}

	evidence, err := src.ReadGateEvidence()
	if err != nil {
		return fmt.Errorf("spec strategy: read gate evidence: %w", err)
	}
	if evidence == nil {
		evidence = map[string]any{}
	}

	learnings, err := src.ReadLearnings()
	if err != nil {
		return fmt.Errorf("spec strategy: read learnings: %w", err)
	}

	b.AddArtifact(ctx.Artifact{
		State:           state,
		SummarySections: summary,
		GateEvidence:    evidence,
		Learnings:       learnings,
	})

	deliverableCount := 0
	if deliverables, ok := state["deliverables"].(map[string]any); ok {
		deliverableCount = len(deliverables)
	}

	b.SetMetadata("deliverable_count", deliverableCount)

	return nil
}

func init() {
	ctx.RegisterStrategy(NewSpecStrategy())
}
