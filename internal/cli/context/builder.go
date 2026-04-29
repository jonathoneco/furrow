// Package context provides concrete Builder, Strategy, ChainNode and ContextSource
// implementations for Furrow context bundle assembly.
//
// D4 owns this file: the concrete Builder implementation satisfying the Builder
// interface defined in contracts.go (D5-owned).
package context

import (
	"fmt"
	"sync"
)

// BundleBuilder is the concrete implementation of the Builder interface.
// It accumulates skills, references, artifacts, decisions, and learnings
// then produces an immutable Bundle via Build.
//
// Zero value is not ready for use; construct via NewBundleBuilder.
type BundleBuilder struct {
	mu       sync.Mutex
	consumed bool

	row    string
	step   string
	target string

	skills     []Skill
	references []Reference
	artifact   Artifact
	decisions  []Decision
}

// NewBundleBuilder constructs a ready-to-use BundleBuilder for the given
// (row, step, target) tuple. Constructor injection prevents zero-value misuse.
func NewBundleBuilder(row, step, target string) *BundleBuilder {
	return &BundleBuilder{
		row:      row,
		step:     step,
		target:   target,
		artifact: Artifact{State: map[string]any{}, SummarySections: map[string]any{}, GateEvidence: map[string]any{}, Learnings: []Learning{}},
	}
}

// Reset zeros all accumulated state so the builder can be reused.
// After Reset the builder is identical to a freshly constructed one
// (same row/step/target tuple).
func (b *BundleBuilder) Reset() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.consumed = false
	b.skills = nil
	b.references = nil
	b.artifact = Artifact{State: map[string]any{}, SummarySections: map[string]any{}, GateEvidence: map[string]any{}, Learnings: []Learning{}}
	b.decisions = nil
}

// AddSkill appends a Skill in insertion order.
func (b *BundleBuilder) AddSkill(s Skill) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.skills = append(b.skills, s)
}

// AddReference appends a Reference in insertion order.
func (b *BundleBuilder) AddReference(r Reference) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.references = append(b.references, r)
}

// AddArtifact sets the prior artifacts; a second call overwrites the previous value.
func (b *BundleBuilder) AddArtifact(a Artifact) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.artifact = a
}

// AddDecision appends a Decision in insertion order.
func (b *BundleBuilder) AddDecision(d Decision) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.decisions = append(b.decisions, d)
}

// AddLearning appends a Learning to PriorArtifacts.Learnings in insertion order.
func (b *BundleBuilder) AddLearning(l Learning) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.artifact.Learnings = append(b.artifact.Learnings, l)
}

// Build assembles the Bundle from accumulated state.
// Returns ErrBuilderConsumed if called a second time without Reset.
func (b *BundleBuilder) Build() (Bundle, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.consumed {
		return Bundle{}, fmt.Errorf("build: %w", ErrBuilderConsumed)
	}
	b.consumed = true

	skills := make([]Skill, len(b.skills))
	copy(skills, b.skills)

	refs := make([]Reference, len(b.references))
	copy(refs, b.references)

	decs := make([]Decision, len(b.decisions))
	copy(decs, b.decisions)

	learnings := make([]Learning, len(b.artifact.Learnings))
	copy(learnings, b.artifact.Learnings)

	artifact := b.artifact
	artifact.Learnings = learnings

	return Bundle{
		Row:              b.row,
		Step:             b.step,
		Target:           b.target,
		Skills:           skills,
		References:       refs,
		PriorArtifacts:   artifact,
		ArtifactContract: map[string]any{},
		Continuation:     map[string]any{},
		Decisions:        decs,
	}, nil
}
