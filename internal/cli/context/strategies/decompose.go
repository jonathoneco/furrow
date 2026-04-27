package strategies

import (
	"fmt"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
)

// DecomposeStrategy implements the Strategy pattern (D5 contract) for the
// decompose step. Decompose translates approved specs into a wave-structured
// plan.json and team-plan.md, verifying file_ownership conflict-freedom.
//
// Context rules for decompose:
//   - Loads skills tagged for the decompose step.
//   - Prior artifacts: all spec files in specs/; decisions through spec.
//   - References: all specs/*.md files.
//   - Metadata: spec_count derived from references that match specs/ path prefix.
//
// implements D5 Strategy pattern; see internal/cli/context/contracts.go
type DecomposeStrategy struct{}

// NewDecomposeStrategy constructs a DecomposeStrategy.
func NewDecomposeStrategy() ctx.Strategy { return &DecomposeStrategy{} }

// Step returns "decompose".
func (s *DecomposeStrategy) Step() string { return "decompose" }

// Apply populates b from src according to decompose step context rules.
func (s *DecomposeStrategy) Apply(b ctx.Builder, src ctx.ContextSource) error {
	skills, err := src.ListSkills()
	if err != nil {
		return fmt.Errorf("decompose strategy: list skills: %w", err)
	}
	for _, sk := range skills {
		b.AddSkill(sk)
	}

	refs, err := src.ListReferences()
	if err != nil {
		return fmt.Errorf("decompose strategy: list references: %w", err)
	}
	specCount := 0
	for _, r := range refs {
		b.AddReference(r)
		if len(r.Path) > 6 && r.Path[:6] == "specs/" {
			specCount++
		}
	}

	state, err := src.ReadState()
	if err != nil {
		return fmt.Errorf("decompose strategy: read state: %w", err)
	}
	if state == nil {
		state = map[string]any{}
	}

	summary, err := src.ReadSummary()
	if err != nil {
		return fmt.Errorf("decompose strategy: read summary: %w", err)
	}
	if summary == nil {
		summary = map[string]any{}
	}

	evidence, err := src.ReadGateEvidence()
	if err != nil {
		return fmt.Errorf("decompose strategy: read gate evidence: %w", err)
	}
	if evidence == nil {
		evidence = map[string]any{}
	}

	learnings, err := src.ReadLearnings()
	if err != nil {
		return fmt.Errorf("decompose strategy: read learnings: %w", err)
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
	ctx.RegisterStrategy(NewDecomposeStrategy())
}
