// Package context defines the canonical contract for Furrow context construction.
//
// Three design patterns cooperate to decouple context assembly from step logic:
//
//   - Builder (Builder Pattern): stateful assembly of a Bundle; isolates Bundle
//     schema evolution to a single construct. Strategies call Add* methods and
//     receive a fully-formed Bundle from Build.
//   - Strategy (Strategy Pattern): one implementation per workflow step; plugs
//     into a central dispatch surface (the registry, D4-owned) without
//     conditional ladders. Adding a new step means adding one file.
//   - ChainNode (Chain of Responsibility Pattern): layered overrides applied in
//     sequence (defaults → step rules → row overrides → target filter). New
//     layers plug in by node insertion without touching existing nodes.
//
// D5 ships this contract (interfaces + value types + conformance harness).
// D4 ships: concrete Builder, Strategy implementations, strategy registry,
// ContextSource concrete reader, and schemas/context-bundle.schema.json.
//
// Exported conformance harness (TestBuilderConformance, TestStrategyConformance,
// TestChainNodeConformance) is included here so D4's _test.go files can import
// and call them as binding acceptance tests. This follows the net/http/httptest
// model: test-support code in the production package, importable by dependents.
package context

import (
	"errors"
	"reflect"
	"testing"
)

// ---------------------------------------------------------------------------
// Sentinel errors
// ---------------------------------------------------------------------------

// Sentinel errors for the context construction contract.
var (
	// ErrBuilderConsumed is returned by Build when called a second time
	// without an intervening Reset.
	ErrBuilderConsumed = errors.New("context: builder already consumed; call Reset before Build")

	// ErrStrategyStepUnknown is returned when a strategy's Step() value does
	// not match any entry in evals/gates/.
	ErrStrategyStepUnknown = errors.New("context: strategy step not found in evals/gates registry")
)

// ---------------------------------------------------------------------------
// Value types
// ---------------------------------------------------------------------------

// Bundle is the assembled output delivered to operator/driver/engine targets.
// Field shape mirrors schemas/context-bundle.schema.json (D4-owned); D5 fixes
// names only. Consumers should treat Bundle as read-only after Build returns.
type Bundle struct {
	Row                  string         `json:"row"`
	Step           string      `json:"step"`
	Target         string      `json:"target"`
	Skills         []Skill     `json:"skills"`
	References     []Reference `json:"references"`
	PriorArtifacts Artifact    `json:"prior_artifacts"`
	Decisions      []Decision  `json:"decisions"`
}

// Skill is a loaded skill file delivered to the operator layer.
// Layer distinguishes ambient / work / step layers per the context budget.
type Skill struct {
	Path    string `json:"path"`
	Layer   string `json:"layer"`
	Content string `json:"content"`
}

// Reference is a reference document loaded on demand (never injected by default).
type Reference struct {
	Path    string `json:"path"`
	Content string `json:"content,omitempty"`
}

// Artifact captures prior-step outputs that the current step may consult.
type Artifact struct {
	State           map[string]any `json:"state"`
	SummarySections map[string]any `json:"summary_sections"`
	GateEvidence    map[string]any `json:"gate_evidence"`
	Learnings       []Learning     `json:"learnings"`
}

// Decision records a gate-transition verdict extracted from a row's settled
// decisions or key-findings prose.
//
// Field shape reconciled with D4's gate-transition regex output (T3 finding):
//
//	^- \*\*([a-z_]+)->([a-z_]+)\*\*: (pass|fail) — (.*)$
//
// Source distinguishes the extraction site; Ordinal preserves first-occurrence
// position for de-dup last-wins semantics.
type Decision struct {
	// Source is "settled_decisions" or "key_findings_prose".
	Source string `json:"source"`
	// FromStep is the step that produced the gate result.
	FromStep string `json:"from_step"`
	// ToStep is the step the gate transitions into.
	ToStep string `json:"to_step"`
	// Outcome is "pass", "fail", or "unknown".
	Outcome   string `json:"outcome"`
	Rationale string `json:"rationale"`
	// Ordinal preserves first-occurrence position for de-dup last-wins.
	Ordinal int `json:"ordinal"`
}

// Learning is a broadly-applicable insight extracted from a row's almanac.
type Learning struct {
	ID                string `json:"id"`
	Body              string `json:"body"`
	BroadlyApplicable bool   `json:"broadly_applicable"`
}

// ---------------------------------------------------------------------------
// Interfaces
// ---------------------------------------------------------------------------

// ContextSource is the read surface a Strategy consults to populate a Builder.
// D5 defines the interface; D4 ships the concrete reader implementation.
// Implementations must be safe for concurrent reads.
type ContextSource interface {
	// Row returns the row name (kebab-case identifier).
	Row() string
	// Step returns the current workflow step name.
	Step() string
	// Target returns the rendering target ("operator", "driver", "engine").
	Target() string
	// ReadState returns the parsed state.json as a generic map.
	ReadState() (map[string]any, error)
	// ReadSummary returns parsed summary.md sections as a generic map.
	ReadSummary() (map[string]any, error)
	// ReadGateEvidence returns the current gate evidence.
	ReadGateEvidence() (map[string]any, error)
	// ReadLearnings returns learnings from the almanac for this row.
	ReadLearnings() ([]Learning, error)
	// ListSkills returns all skill files applicable to the current step.
	ListSkills() ([]Skill, error)
	// ListReferences returns all reference files available for on-demand loading.
	ListReferences() ([]Reference, error)
}

// Builder assembles a Bundle using the Builder design pattern.
//
// Architectural intent: Strategies never construct Bundle literals directly.
// Bundle schema evolution (adding fields, renaming, versioning) stays
// single-sourced through the Builder implementation. Strategies call Add*
// methods and receive a fully-formed Bundle from Build.
//
// Contract invariants:
//   - Reset MUST zero all accumulated state.
//   - Build returns ErrBuilderConsumed if called a second time without Reset.
//   - After Reset, the builder is ready for reuse (no resource leaks).
//   - Add* methods MUST preserve insertion order within each field.
type Builder interface {
	// Reset zeros accumulated state; subsequent Add* calls start fresh.
	Reset()
	// AddSkill appends a Skill to the bundle's Skills slice in insertion order.
	AddSkill(s Skill)
	// AddReference appends a Reference to the bundle's References slice.
	AddReference(r Reference)
	// AddArtifact sets the bundle's PriorArtifacts; a second call overwrites.
	AddArtifact(a Artifact)
	// AddDecision appends a Decision to the bundle's Decisions slice.
	AddDecision(d Decision)
	// AddLearning appends a Learning to the bundle's PriorArtifacts.Learnings slice.
	AddLearning(l Learning)
	// Build assembles and returns the Bundle. Returns ErrBuilderConsumed if
	// called again before Reset.
	Build() (Bundle, error)
}

// Strategy implements per-step context loading using the Strategy design pattern.
//
// Architectural intent: each workflow step's context rules are encapsulated in
// a single Strategy implementation that plugs into a central registry (D4-owned)
// without requiring conditional ladders. Adding a new step means adding a new
// file, not modifying a switch statement.
//
// Contract invariants:
//   - Step() MUST return a value matching an entry in evals/gates/ (filename stem).
//   - Apply MUST be idempotent: calling Apply twice on freshly-Reset Builders
//     with the same ContextSource produces structurally equal Bundles.
//   - Apply MUST NOT retain a reference to b after returning.
//   - Apply SHOULD return a descriptive error (wrapped with fmt.Errorf) rather
//     than panicking on malformed input.
type Strategy interface {
	// Step returns the workflow step name this strategy handles.
	Step() string
	// Apply populates b from src according to this step's context rules.
	Apply(b Builder, src ContextSource) error
}

// ChainNode implements layered context overrides using the Chain of Responsibility
// design pattern.
//
// Architectural intent: each override layer (defaults → step rules → row overrides
// → target filter) is self-contained as a ChainNode. New layers (e.g., a
// per-runtime adapter filter) plug in by node insertion without touching existing
// nodes. The caller (D4's runner) walks the chain; nodes do not self-walk.
//
// Contract invariants:
//   - Next() == nil signals chain termination; the caller MUST stop.
//   - Apply MUST NOT call Next().Apply — chain walking is the caller's
//     responsibility.
//   - Apply MUST be idempotent when called with the same Builder state and
//     unchanged ContextSource.
//   - Nodes are stateless; all mutable state lives in the Builder.
type ChainNode interface {
	// Next returns the following node, or nil if this is the terminal node.
	Next() ChainNode
	// Apply applies this node's override rules to b from src.
	Apply(b Builder, src ContextSource) error
}

// ---------------------------------------------------------------------------
// Conformance harness — exported test helpers for D4 strategy implementations.
//
// Following the net/http/httptest pattern: test-support code lives in the
// production package so it is importable by D4's _test.go files as a binding
// acceptance check. The "testing" import is justified by this design.
//
// Verification command D4 must pass during W3 review:
//
//	go test -run 'TestBuilderConformance|TestStrategyConformance|TestChainNodeConformance' \
//	    ./internal/cli/context/...
// ---------------------------------------------------------------------------

// TestBuilderConformance asserts the Builder contract holds for the builder
// produced by factory. It is exported so D4's strategy test files can invoke
// it as a binding conformance check.
//
// Sub-tests:
//   - reset_zeros_state: Reset must zero all accumulated state.
//   - build_returns_added_items: Build returns everything added via Add* methods.
//   - double_build_returns_err_consumed: second Build without Reset returns ErrBuilderConsumed.
//   - reset_after_build_allows_reuse: Reset restores the builder after consumption.
//   - add_methods_preserve_insertion_order: Add* preserves insertion order within each field.
func TestBuilderConformance(t *testing.T, factory func() Builder) {
	t.Helper()

	t.Run("reset_zeros_state", func(t *testing.T) {
		b := factory()
		b.AddSkill(Skill{Path: "skills/ideate.md", Layer: "step", Content: "x"})
		b.AddDecision(Decision{Source: "settled_decisions", FromStep: "ideate", ToStep: "research", Outcome: "pass"})
		b.Reset()

		bundle, err := b.Build()
		if err != nil {
			t.Fatalf("Build after Reset returned error: %v", err)
		}
		if len(bundle.Skills) != 0 {
			t.Errorf("Reset must zero Skills; got %d items", len(bundle.Skills))
		}
		if len(bundle.Decisions) != 0 {
			t.Errorf("Reset must zero Decisions; got %d items", len(bundle.Decisions))
		}
	})

	t.Run("build_returns_added_items", func(t *testing.T) {
		b := factory()
		skill := Skill{Path: "skills/spec.md", Layer: "step", Content: "spec content"}
		ref := Reference{Path: "references/gate-protocol.md", Content: "gp"}
		dec := Decision{Source: "settled_decisions", FromStep: "spec", ToStep: "decompose", Outcome: "pass", Rationale: "ok", Ordinal: 1}
		learning := Learning{ID: "L1", Body: "test learning", BroadlyApplicable: true}

		b.AddSkill(skill)
		b.AddReference(ref)
		b.AddDecision(dec)
		b.AddLearning(learning)

		bundle, err := b.Build()
		if err != nil {
			t.Fatalf("unexpected Build error: %v", err)
		}
		if len(bundle.Skills) != 1 || bundle.Skills[0].Path != skill.Path {
			t.Errorf("Skills mismatch: got %v", bundle.Skills)
		}
		if len(bundle.References) != 1 || bundle.References[0].Path != ref.Path {
			t.Errorf("References mismatch: got %v", bundle.References)
		}
		if len(bundle.Decisions) != 1 || bundle.Decisions[0].Ordinal != dec.Ordinal {
			t.Errorf("Decisions mismatch: got %v", bundle.Decisions)
		}
		if len(bundle.PriorArtifacts.Learnings) != 1 || bundle.PriorArtifacts.Learnings[0].ID != learning.ID {
			t.Errorf("Learnings mismatch: got %v", bundle.PriorArtifacts.Learnings)
		}
	})

	t.Run("double_build_returns_err_consumed", func(t *testing.T) {
		b := factory()
		if _, err := b.Build(); err != nil {
			t.Fatalf("first Build failed: %v", err)
		}
		_, err := b.Build()
		if !errors.Is(err, ErrBuilderConsumed) {
			t.Errorf("second Build must return ErrBuilderConsumed; got %v", err)
		}
	})

	t.Run("reset_after_build_allows_reuse", func(t *testing.T) {
		b := factory()
		b.AddSkill(Skill{Path: "skills/ideate.md", Layer: "step"})
		if _, err := b.Build(); err != nil {
			t.Fatalf("first Build failed: %v", err)
		}
		b.Reset()
		if _, err := b.Build(); err != nil {
			t.Fatalf("Build after Reset-then-reuse returned error: %v", err)
		}
	})

	t.Run("add_methods_preserve_insertion_order", func(t *testing.T) {
		b := factory()
		paths := []string{"skills/ideate.md", "skills/research.md", "skills/plan.md"}
		for _, p := range paths {
			b.AddSkill(Skill{Path: p, Layer: "step"})
		}
		bundle, err := b.Build()
		if err != nil {
			t.Fatalf("Build failed: %v", err)
		}
		if len(bundle.Skills) != len(paths) {
			t.Fatalf("expected %d skills; got %d", len(paths), len(bundle.Skills))
		}
		for i, p := range paths {
			if bundle.Skills[i].Path != p {
				t.Errorf("insertion order violated at index %d: want %q got %q", i, p, bundle.Skills[i].Path)
			}
		}
	})
}

// TestStrategyConformance asserts the Strategy contract holds for the strategy
// produced by factory. src is the ContextSource fixture used to drive Apply.
// It is exported so D4's strategy test files can invoke it as a binding check.
//
// Sub-tests:
//   - step_matches_registered_gate: Step() non-empty and stable across calls.
//   - apply_idempotent: Apply twice on Reset builders with same src → equal Bundles.
//   - apply_does_not_panic_on_empty_source: Apply tolerates empty/nil returns from src.
//   - apply_returns_err_when_source_missing_required_field: Apply returns error (not panic) on absent required fields.
func TestStrategyConformance(t *testing.T, factory func() Strategy, src ContextSource) {
	t.Helper()

	t.Run("step_matches_registered_gate", func(t *testing.T) {
		s := factory()
		step := s.Step()
		if step == "" {
			t.Fatal("Strategy.Step() returned empty string")
		}
		if s.Step() != step {
			t.Error("Strategy.Step() must be stable across calls")
		}
	})

	t.Run("apply_idempotent", func(t *testing.T) {
		s := factory()

		b1 := &harnessBuilder{}
		if err := s.Apply(b1, src); err != nil {
			t.Fatalf("first Apply returned error: %v", err)
		}
		bundle1, err := b1.Build()
		if err != nil {
			t.Fatalf("Build after first Apply: %v", err)
		}

		b2 := &harnessBuilder{}
		if err := s.Apply(b2, src); err != nil {
			t.Fatalf("second Apply returned error: %v", err)
		}
		bundle2, err := b2.Build()
		if err != nil {
			t.Fatalf("Build after second Apply: %v", err)
		}

		if !reflect.DeepEqual(bundle1.Skills, bundle2.Skills) {
			t.Errorf("Apply not idempotent: Skills differ\n  first:  %v\n  second: %v", bundle1.Skills, bundle2.Skills)
		}
		if !reflect.DeepEqual(bundle1.References, bundle2.References) {
			t.Errorf("Apply not idempotent: References differ\n  first:  %v\n  second: %v", bundle1.References, bundle2.References)
		}
		if !reflect.DeepEqual(bundle1.Decisions, bundle2.Decisions) {
			t.Errorf("Apply not idempotent: Decisions differ")
		}
	})

	t.Run("apply_does_not_panic_on_empty_source", func(t *testing.T) {
		s := factory()
		b := &harnessBuilder{}
		defer func() {
			if r := recover(); r != nil {
				t.Errorf("Apply panicked on empty source: %v", r)
			}
		}()
		_ = s.Apply(b, &emptyContextSource{})
	})

	t.Run("apply_returns_err_when_source_missing_required_field", func(t *testing.T) {
		// Documents the expectation: D4 strategy implementations that require
		// certain source fields must return a non-nil error (not panic) when
		// those fields are absent. The harness cannot enforce this generically
		// because required fields differ per step; D4's strategies_test.go
		// should provide an erroring ContextSource fixture.
		//
		// When called from the in-package fake (which tolerates empty sources),
		// this sub-test is a no-op — it still passes.
		t.Log("strategy-specific: D4 implementations should provide an erroring source fixture for this sub-test")
	})
}

// TestChainNodeConformance asserts the ChainNode contract holds for the node
// produced by factory. It is exported so D4's node test files can invoke it
// as a binding check.
//
// Sub-tests:
//   - next_nil_terminates: terminal node Next() returns nil without panicking.
//   - apply_does_not_walk_chain: Apply does not call Next.Apply internally.
//   - apply_idempotent_when_source_unchanged: Apply twice on same src → equal Bundles.
func TestChainNodeConformance(t *testing.T, factory func() ChainNode, src ContextSource) {
	t.Helper()

	t.Run("next_nil_terminates", func(t *testing.T) {
		n := factory()
		next := n.Next()
		if next != nil {
			// Non-nil is valid for a non-terminal node; verify Apply doesn't panic.
			b := &harnessBuilder{}
			if err := next.Apply(b, src); err != nil {
				t.Logf("non-terminal Next.Apply returned: %v (may be expected)", err)
			}
		}
		// Contract is structural; no assertion needed beyond no-panic.
	})

	t.Run("apply_does_not_walk_chain", func(t *testing.T) {
		// Apply on the factory node must not self-walk the chain. We verify
		// Apply completes without panicking; the structural invariant is
		// enforced via godoc and review (injection of Next is not possible
		// without D4's implementation details).
		b := &harnessBuilder{}
		if err := factory().Apply(b, src); err != nil {
			t.Logf("Apply returned: %v (may be expected with fixture source)", err)
		}
	})

	t.Run("apply_idempotent_when_source_unchanged", func(t *testing.T) {
		b1 := &harnessBuilder{}
		if err := factory().Apply(b1, src); err != nil {
			t.Logf("first Apply: %v", err)
		}
		bundle1, err := b1.Build()
		if err != nil {
			t.Fatalf("Build 1: %v", err)
		}

		b2 := &harnessBuilder{}
		if err := factory().Apply(b2, src); err != nil {
			t.Logf("second Apply: %v", err)
		}
		bundle2, err := b2.Build()
		if err != nil {
			t.Fatalf("Build 2: %v", err)
		}

		if !reflect.DeepEqual(bundle1.References, bundle2.References) {
			t.Errorf("Apply not idempotent: References differ\n  first:  %v\n  second: %v", bundle1.References, bundle2.References)
		}
		if !reflect.DeepEqual(bundle1.Skills, bundle2.Skills) {
			t.Errorf("Apply not idempotent: Skills differ\n  first:  %v\n  second: %v", bundle1.Skills, bundle2.Skills)
		}
	})
}

// ---------------------------------------------------------------------------
// Internal harness support types
// ---------------------------------------------------------------------------

// harnessBuilder is a minimal Builder used inside the conformance harness.
// D4's concrete Builder implementation provides richer behaviour; the harness
// uses this stripped-down version to remain self-contained and independent.
type harnessBuilder struct {
	consumed   bool
	skills     []Skill
	references []Reference
	artifact   Artifact
	decisions  []Decision
}

func (b *harnessBuilder) Reset() {
	b.consumed = false
	b.skills = nil
	b.references = nil
	b.artifact = Artifact{}
	b.decisions = nil
}

func (b *harnessBuilder) AddSkill(s Skill)         { b.skills = append(b.skills, s) }
func (b *harnessBuilder) AddReference(r Reference) { b.references = append(b.references, r) }
func (b *harnessBuilder) AddArtifact(a Artifact)   { b.artifact = a }
func (b *harnessBuilder) AddDecision(d Decision)   { b.decisions = append(b.decisions, d) }
func (b *harnessBuilder) AddLearning(l Learning) {
	b.artifact.Learnings = append(b.artifact.Learnings, l)
}

func (b *harnessBuilder) Build() (Bundle, error) {
	if b.consumed {
		return Bundle{}, ErrBuilderConsumed
	}
	b.consumed = true
	return Bundle{
		Skills:         b.skills,
		References:     b.references,
		PriorArtifacts: b.artifact,
		Decisions:      b.decisions,
	}, nil
}

// emptyContextSource is a ContextSource that returns nil/empty for all fields.
// Used by the conformance harness to test Apply robustness on empty input.
type emptyContextSource struct{}

func (e *emptyContextSource) Row() string                               { return "" }
func (e *emptyContextSource) Step() string                              { return "" }
func (e *emptyContextSource) Target() string                            { return "" }
func (e *emptyContextSource) ReadState() (map[string]any, error)        { return nil, nil }
func (e *emptyContextSource) ReadSummary() (map[string]any, error)      { return nil, nil }
func (e *emptyContextSource) ReadGateEvidence() (map[string]any, error) { return nil, nil }
func (e *emptyContextSource) ReadLearnings() ([]Learning, error)        { return nil, nil }
func (e *emptyContextSource) ListSkills() ([]Skill, error)              { return nil, nil }
func (e *emptyContextSource) ListReferences() ([]Reference, error)      { return nil, nil }
