package context

import (
	"fmt"
	"strings"
)

// ---------------------------------------------------------------------------
// DefaultsNode — Chain of Responsibility: first node; injects ambient defaults.
// ---------------------------------------------------------------------------

// DefaultsNode is the first ChainNode in the assembly chain. It sets
// zero/empty defaults so subsequent nodes can safely overwrite specific fields
// without worrying about nil slices or missing metadata keys.
//
// DefaultsNode implements the Chain of Responsibility pattern (D5 contract).
// It does NOT self-walk the chain; that is the runner's responsibility.
type DefaultsNode struct {
	next ChainNode
}

// NewDefaultsNode constructs a DefaultsNode that passes to next on completion.
func NewDefaultsNode(next ChainNode) *DefaultsNode {
	return &DefaultsNode{next: next}
}

// Next returns the following ChainNode, or nil if this is terminal.
func (n *DefaultsNode) Next() ChainNode { return n.next }

// Apply seeds the builder with structural defaults: empty slices/maps so
// downstream nodes never encounter nils. Idempotent; calling twice is safe.
func (n *DefaultsNode) Apply(b Builder, src ContextSource) error {
	// Defaults are implicit in BundleBuilder's zero state; nothing to do here
	// except ensure metadata carries the source triple.
	if bb, ok := b.(*BundleBuilder); ok {
		bb.SetMetadata("row", src.Row())
		bb.SetMetadata("step", src.Step())
		bb.SetMetadata("target", src.Target())
	}
	return nil
}

// ---------------------------------------------------------------------------
// ArtifactNode — Chain of Responsibility: second node; loads prior artifacts.
// ---------------------------------------------------------------------------

// ArtifactNode loads prior-step artifacts (state, summary sections, gate
// evidence, learnings) from the ContextSource and stores them via AddArtifact.
//
// ArtifactNode implements the Chain of Responsibility pattern (D5 contract).
type ArtifactNode struct {
	next ChainNode
}

// NewArtifactNode constructs an ArtifactNode.
func NewArtifactNode(next ChainNode) *ArtifactNode {
	return &ArtifactNode{next: next}
}

// Next returns the following ChainNode.
func (n *ArtifactNode) Next() ChainNode { return n.next }

// Apply reads prior artifacts from src and stores them via AddArtifact.
// Missing-state and missing-summary are treated as empty (not errors) because
// early steps (ideate) have no prior artifacts. ReadLearnings errors surface.
func (n *ArtifactNode) Apply(b Builder, src ContextSource) error {
	state, err := src.ReadState()
	if err != nil {
		return fmt.Errorf("artifact node: read state: %w", err)
	}
	if state == nil {
		state = map[string]any{}
	}

	summary, err := src.ReadSummary()
	if err != nil {
		return fmt.Errorf("artifact node: read summary: %w", err)
	}
	if summary == nil {
		summary = map[string]any{}
	}

	evidence, err := src.ReadGateEvidence()
	if err != nil {
		return fmt.Errorf("artifact node: read gate evidence: %w", err)
	}
	if evidence == nil {
		evidence = map[string]any{}
	}

	learnings, err := src.ReadLearnings()
	if err != nil {
		return fmt.Errorf("artifact node: read learnings: %w", err)
	}

	b.AddArtifact(Artifact{
		State:           state,
		SummarySections: summary,
		GateEvidence:    evidence,
		Learnings:       learnings,
	})
	return nil
}

// ---------------------------------------------------------------------------
// TargetFilterNode — Chain of Responsibility: terminal node; filters by target.
// ---------------------------------------------------------------------------

// TargetFilterNode is the terminal ChainNode that filters skills and references
// to match the requested target layer (operator, driver, engine, specialist:*).
//
// Filter rules per spec table:
//   - operator    → layer in {operator, shared}
//   - driver      → layer in {driver, shared}
//   - engine      → layer in {engine, shared}; strip .furrow/ references
//   - specialist:* → layer in {engine, shared}; strip .furrow/ references
//
// TargetFilterNode implements the Chain of Responsibility pattern (D5 contract).
type TargetFilterNode struct {
	// Terminal node has no next.
}

// NewTargetFilterNode constructs a terminal TargetFilterNode.
func NewTargetFilterNode() *TargetFilterNode {
	return &TargetFilterNode{}
}

// Next returns nil — this is the terminal node.
func (n *TargetFilterNode) Next() ChainNode { return nil }

// Apply filters skills and references stored in the builder according to the
// target declared by src.Target(). This node reads the current builder state
// via Build (harness builder pattern), filters, resets, and re-populates.
//
// Note: because the Builder interface does not expose a getter, Apply uses a
// type assertion to *BundleBuilder to access the accumulated state directly.
// This is an intentional coupling point between the chain and the concrete
// builder; alternative designs (a ReadonlyBundle getter on Builder) were
// considered and deferred per spec open question §1.
func (n *TargetFilterNode) Apply(b Builder, src ContextSource) error {
	bb, ok := b.(*BundleBuilder)
	if !ok {
		// Harness builder or other non-concrete; skip filtering (conformance only).
		return nil
	}

	target := src.Target()
	allowedLayers := targetLayers(target)
	stripFurrow := strings.HasPrefix(target, "engine") || strings.HasPrefix(target, "specialist:")

	// Filter skills in-place (avoid allocation by reusing slice).
	bb.mu.Lock()
	filtered := bb.skills[:0]
	for _, s := range bb.skills {
		if allowedLayers[s.Layer] {
			filtered = append(filtered, s)
		}
	}
	bb.skills = filtered

	// Filter references if needed.
	if stripFurrow {
		filteredRefs := bb.references[:0]
		for _, r := range bb.references {
			if !strings.HasPrefix(r.Path, ".furrow/") {
				filteredRefs = append(filteredRefs, r)
			}
		}
		bb.references = filteredRefs
	}

	// Filter learnings for engine/specialist targets.
	if stripFurrow {
		filteredL := bb.artifact.Learnings[:0]
		for _, l := range bb.artifact.Learnings {
			if l.BroadlyApplicable {
				filteredL = append(filteredL, l)
			}
		}
		bb.artifact.Learnings = filteredL
	}
	bb.mu.Unlock()

	return nil
}

// targetLayers returns the set of allowed layer strings for the given target.
func targetLayers(target string) map[string]bool {
	switch {
	case target == "operator":
		return map[string]bool{"operator": true, "shared": true}
	case target == "driver":
		return map[string]bool{"driver": true, "shared": true}
	case target == "engine" || strings.HasPrefix(target, "specialist:"):
		return map[string]bool{"engine": true, "shared": true}
	default:
		// Unknown target: allow nothing from unknown layers; only shared passes.
		return map[string]bool{"shared": true}
	}
}

// ---------------------------------------------------------------------------
// BuildChain assembles the standard four-node chain.
// ---------------------------------------------------------------------------

// BuildChain constructs the standard chain:
//
//	DefaultsNode → ArtifactNode → TargetFilterNode (terminal)
//
// The caller walks the chain by calling each node's Apply then Next.
func BuildChain() ChainNode {
	target := NewTargetFilterNode()
	artifact := NewArtifactNode(target)
	defaults := NewDefaultsNode(artifact)
	return defaults
}

// WalkChain walks the chain rooted at node, calling Apply(b, src) on each node
// until Next returns nil. Stops and returns the first non-nil error.
func WalkChain(node ChainNode, b Builder, src ContextSource) error {
	for node != nil {
		if err := node.Apply(b, src); err != nil {
			return fmt.Errorf("chain walk: %w", err)
		}
		node = node.Next()
	}
	return nil
}
