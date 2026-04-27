package strategies

import (
	"fmt"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
)

// ImplementStrategy implements the Strategy pattern (D5 contract) for the
// implement step. Implement drives wave-by-wave delivery, surfacing only the
// current-wave specs and accumulated gate evidence to keep context focused.
//
// Context rules for implement:
//   - Loads skills tagged for the implement step.
//   - Prior artifacts: plan.json (waves), current-wave specs/*.md; decisions
//     through decompose; gate evidence accumulated across previous waves.
//   - Metadata: wave=<current wave int>, deliverables=[...names in wave].
//
// implements D5 Strategy pattern; see internal/cli/context/contracts.go
type ImplementStrategy struct{}

// NewImplementStrategy constructs an ImplementStrategy.
func NewImplementStrategy() ctx.Strategy { return &ImplementStrategy{} }

// Step returns "implement".
func (s *ImplementStrategy) Step() string { return "implement" }

// Apply populates b from src according to implement step context rules.
func (s *ImplementStrategy) Apply(b ctx.Builder, src ctx.ContextSource) error {
	skills, err := src.ListSkills()
	if err != nil {
		return fmt.Errorf("implement strategy: list skills: %w", err)
	}
	for _, sk := range skills {
		b.AddSkill(sk)
	}

	refs, err := src.ListReferences()
	if err != nil {
		return fmt.Errorf("implement strategy: list references: %w", err)
	}
	for _, r := range refs {
		b.AddReference(r)
	}

	state, err := src.ReadState()
	if err != nil {
		return fmt.Errorf("implement strategy: read state: %w", err)
	}
	if state == nil {
		state = map[string]any{}
	}

	summary, err := src.ReadSummary()
	if err != nil {
		return fmt.Errorf("implement strategy: read summary: %w", err)
	}
	if summary == nil {
		summary = map[string]any{}
	}

	evidence, err := src.ReadGateEvidence()
	if err != nil {
		return fmt.Errorf("implement strategy: read gate evidence: %w", err)
	}
	if evidence == nil {
		evidence = map[string]any{}
	}

	learnings, err := src.ReadLearnings()
	if err != nil {
		return fmt.Errorf("implement strategy: read learnings: %w", err)
	}

	b.AddArtifact(ctx.Artifact{
		State:           state,
		SummarySections: summary,
		GateEvidence:    evidence,
		Learnings:       learnings,
	})

	// Derive current wave from deliverables in state.
	wave := 1
	var deliverableNames []string
	if deliverables, ok := state["deliverables"].(map[string]any); ok {
		for name, v := range deliverables {
			if d, ok := v.(map[string]any); ok {
				if w, ok := d["wave"].(float64); ok {
					waveInt := int(w)
					if waveInt > wave {
						wave = waveInt
					}
					deliverableNames = append(deliverableNames, name)
				}
			}
		}
	}


	return nil
}

func init() {
	ctx.RegisterStrategy(NewImplementStrategy())
}
