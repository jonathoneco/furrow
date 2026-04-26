// Package strategies provides per-step Strategy implementations for Furrow
// context bundle assembly. Each file in this package implements one step's
// Strategy and self-registers via package init() (justified registry pattern).
//
// All strategies satisfy the Strategy interface defined in
// internal/cli/context/contracts.go (D5-owned). The registry in
// internal/cli/context/registry.go (D4-owned) dispatches by step name.
package strategies

import (
	"fmt"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
)

// IdeateStrategy implements the Strategy pattern (D5 contract) for the ideate
// step. Ideate is the first step in the workflow; it establishes the problem
// framing and produces a definition.yaml that downstream steps build on.
//
// Context rules for ideate:
//   - Loads skills tagged layer:driver or layer:operator (filtered by target).
//   - Pulls definition.yaml content (objective, deliverable names only — no ACs).
//   - Prior artifacts: empty (no prior step).
//   - Decisions: none at this step.
//   - Metadata: is_first_step=true.
//
// implements D5 Strategy pattern; see internal/cli/context/contracts.go
type IdeateStrategy struct{}

// NewIdeateStrategy constructs an IdeateStrategy.
func NewIdeateStrategy() ctx.Strategy { return &IdeateStrategy{} }

// Step returns "ideate".
func (s *IdeateStrategy) Step() string { return "ideate" }

// Apply populates b from src according to ideate step context rules.
// Idempotent: calling Apply twice on freshly-Reset Builders with the same
// ContextSource produces structurally equal Bundles.
func (s *IdeateStrategy) Apply(b ctx.Builder, src ctx.ContextSource) error {
	skills, err := src.ListSkills()
	if err != nil {
		return fmt.Errorf("ideate strategy: list skills: %w", err)
	}
	for _, sk := range skills {
		b.AddSkill(sk)
	}

	refs, err := src.ListReferences()
	if err != nil {
		return fmt.Errorf("ideate strategy: list references: %w", err)
	}
	for _, r := range refs {
		b.AddReference(r)
	}

	// Ideate is the first step; no prior artifacts to load.
	// AddArtifact with empty values so the bundle shape is always valid.
	b.AddArtifact(ctx.Artifact{
		State:           map[string]any{},
		SummarySections: map[string]any{},
		GateEvidence:    map[string]any{},
		Learnings:       []ctx.Learning{},
	})

	if bb, ok := b.(*ctx.BundleBuilder); ok {
		bb.SetMetadata("is_first_step", true)
	}

	return nil
}

func init() {
	ctx.RegisterStrategy(NewIdeateStrategy())
}
