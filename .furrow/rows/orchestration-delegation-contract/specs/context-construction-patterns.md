# D5 — Context Construction Patterns (Spec)

Deliverable: `context-construction-patterns` (W1, ships before D4).
Specialist: harness-engineer.

<!-- spec:section:goals -->
## Goals

Binding architectural reference for context construction in Furrow. D5 ships only the contract (interfaces + conformance harness + structural test + audit doc); D4 implements against it in W3. Outcomes:

- Three canonical interfaces (`Builder`, `Strategy`, `ChainNode`) naming the pattern and intent in godoc (AC #1).
- Exported conformance harness any plug-in opts into (AC #2).
- Structural test that fails fast on step↔strategy drift (AC #3).
- Audit doc enumerating every ad-hoc context-loading site with file:line, mechanism, target pattern, owner (AC #4, #5).

Without an enforced contract, D4 ships another bespoke loader and the migration fails.

<!-- spec:section:non-goals -->
## Non-goals

- No strategy implementations (D4 owns `strategies/{step}.go`).
- No CLI wiring (`furrow context for-step` is D4).
- No bundle schema (`schemas/context-bundle.schema.json` is D4).
- No runtime-specific concerns (Claude/Pi adapters).
- No state mutation; pure interfaces + tests + docs.
- No retrofit of `bin/frw.d/scripts/` loaders — audited only; migration owners assigned per-row vs follow-up.

<!-- spec:section:approach -->
## Approach

Four files:

1. `internal/cli/context/contracts.go` — interface + value-type definitions only. No registry instance (D4 owns `registry.go`).
2. `internal/cli/context/contracts_test.go` — exported `TestStrategyConformance`, `TestBuilderConformance`, `TestChainNodeConformance` harnesses + in-test fakes proving the harness non-vacuous.
3. `internal/cli/context/structure_test.go` — reads `evals/gates/*.yaml`; asserts strategy file presence + interface uniqueness + no orphans.
4. `docs/architecture/context-construction-patterns.md` — six sections + audit table.

Build order: (1) audit context-loading sites first — drives both the structural-test step list and the doc table; grep `commands/work.md`, `skills/work-context.md`, `skills/{step}.md`, `bin/frw.d/scripts/*`, `internal/cli/*`. (2) write `contracts.go`. (3) `contracts_test.go` against in-test fakes. (4) `structure_test.go` with env-gated strict mode (see Structural Test). (5) architecture doc. (6) `go test ./... && go vet ./...`; commit.

Approximate sizes: contracts.go ~180 LOC, contracts_test.go ~250 LOC, structure_test.go ~150 LOC, doc ~400 lines.

<!-- spec:section:interfaces -->
## Interfaces

Verbatim signatures for `internal/cli/context/contracts.go` (AC #1). Implementers MUST match exactly.

```go
// Package context: canonical contract for Furrow context construction.
// Three patterns cooperate: Builder (assemble Bundle), Strategy (per-step
// rules), ChainNode (Chain of Responsibility for layered overrides:
// defaults -> step -> row overrides -> target filter). D5 ships ONLY this
// contract; D4 ships strategies + registry.
package context

// Bundle: assembled output for operator/driver/engine targets. Field shape
// mirrors schemas/context-bundle.schema.json (D4-owned); D5 fixes names only.
type Bundle struct {
    Row                  string                 `json:"row"`
    Step                 string                 `json:"step"`
    Target               string                 `json:"target"`
    Skills               []Skill                `json:"skills"`
    References           []Reference            `json:"references"`
    PriorArtifacts       Artifact               `json:"prior_artifacts"`
    Decisions            []Decision             `json:"decisions"`
    StepStrategyMetadata map[string]any         `json:"step_strategy_metadata"`
}

type Skill struct {
    Path    string `json:"path"`
    Layer   string `json:"layer"`
    Content string `json:"content"`
}

type Reference struct {
    Path    string `json:"path"`
    Content string `json:"content,omitempty"`
}

type Artifact struct {
    State           map[string]any `json:"state"`
    SummarySections map[string]any `json:"summary_sections"`
    GateEvidence    map[string]any `json:"gate_evidence"`
    Learnings       []Learning     `json:"learnings"`
}

type Decision struct {
    // Reconciled with D4's gate-transition extraction (T3 finding).
    // The regex `^- \*\*([a-z_]+)->([a-z_]+)\*\*: (pass|fail) — (.*)$` produces
    // FromStep/ToStep/Outcome/Rationale; Source distinguishes settled-decisions
    // section vs key-findings fallback; Ordinal preserves first-occurrence
    // position for de-dup last-wins.
    Source    string `json:"source"`     // "settled_decisions" | "key_findings_prose"
    FromStep  string `json:"from_step"`
    ToStep    string `json:"to_step"`
    Outcome   string `json:"outcome"`    // "pass" | "fail" | "unknown"
    Rationale string `json:"rationale"`
    Ordinal   int    `json:"ordinal"`
}

type Learning struct {
    ID                 string `json:"id"`
    Body               string `json:"body"`
    BroadlyApplicable  bool   `json:"broadly_applicable"`
}

// ContextSource: read surface a Strategy consults. Concrete reader is D4.
type ContextSource interface {
    Row() string
    Step() string
    Target() string
    ReadState() (map[string]any, error)
    ReadSummary() (map[string]any, error)
    ReadGateEvidence() (map[string]any, error)
    ReadLearnings() ([]Learning, error)
    ListSkills() ([]Skill, error)
    ListReferences() ([]Reference, error)
}

// Builder (Builder Pattern): stateful assembly of a Bundle.
// Reset MUST zero state; Build returns the assembled Bundle.
// Build twice without Reset MUST return ErrBuilderConsumed.
// Intent: Strategies never construct Bundle literals directly — Bundle
// schema evolution stays single-sourced through Builder.
type Builder interface {
    Reset()
    AddSkill(s Skill)
    AddReference(r Reference)
    AddArtifact(a Artifact)
    AddDecision(d Decision)
    AddLearning(l Learning)
    Build() (Bundle, error)
}

// Strategy (Strategy Pattern): one impl per workflow step. Step() must
// match an entry in evals/gates/. Apply MUST be idempotent: twice on a
// freshly-Reset Builder with the same source produces equal Bundles.
// Intent: per-step logic plugs into a single dispatch surface (registry,
// D4-owned) without conditional ladders.
type Strategy interface {
    Step() string
    Apply(b Builder, src ContextSource) error
}

// ChainNode (Chain of Responsibility): layered overrides applied in
// sequence. Next() == nil terminates. Apply MUST NOT walk Next itself —
// the caller (D4's runner) walks the chain.
// Intent: each override layer is self-contained; new layers (e.g.,
// per-runtime adapter filter) plug in by node insertion.
type ChainNode interface {
    Next() ChainNode
    Apply(b Builder, src ContextSource) error
}
```

Errors: `ErrBuilderConsumed`, `ErrStrategyStepUnknown`, `ErrChainTerminated` declared as package-level `errors.New(...)` sentinels.

<!-- spec:section:conformance-harness -->
## Conformance Harness

`internal/cli/context/contracts_test.go` (AC #2) exports three harness entry points. D4's `strategies_test.go` calls them per step; the harness is the binding contract for D4 review sign-off.

```go
// TestBuilderConformance asserts the Builder contract holds for the
// builder produced by factory(). Sub-tests:
//   - reset_zeros_state
//   - build_returns_added_items
//   - double_build_returns_err_consumed
//   - reset_after_build_allows_reuse
//   - add_methods_preserve_insertion_order
func TestBuilderConformance(t *testing.T, factory func() Builder)

// TestStrategyConformance asserts the Strategy contract holds for the
// strategy produced by factory(). Caller supplies a ContextSource fixture.
// Sub-tests:
//   - step_matches_registered_gate (looks up Step() in evals/gates/)
//   - apply_idempotent (apply twice on Reset builders -> equal bundles)
//   - apply_does_not_panic_on_empty_source
//   - apply_returns_err_when_source_missing_required_field
func TestStrategyConformance(t *testing.T, factory func() Strategy, src ContextSource)

// TestChainNodeConformance asserts the ChainNode contract holds:
//   - next_nil_terminates
//   - apply_does_not_walk_chain
//   - apply_idempotent_when_source_unchanged
func TestChainNodeConformance(t *testing.T, factory func() ChainNode, src ContextSource)
```

Verification command D4 must pass during W3 review:

```sh
go test -run 'TestStrategyConformance|TestBuilderConformance|TestChainNodeConformance' ./internal/cli/context/...
```

Sub-test names are stable; D4's strategies_test.go calls these harness functions per step in table-driven form.

<!-- spec:section:structural-test -->
## Structural Test

`internal/cli/context/structure_test.go` (AC #3) asserts:

1. **Step coverage**: parse `evals/gates/*.yaml`; for each step (filename stem), assert `internal/cli/context/strategies/{step}.go` exists. Failure: `step "X" has gate definition but no strategy file at internal/cli/context/strategies/X.go — add it or remove the gate`.
2. **Strategy coverage**: walk `strategies/`; every non-test `.go` must correspond to a gate. Orphans fail.
3. **Interface uniqueness**: AST-scan `internal/cli/context/`; assert only `contracts.go` declares interface types named `Builder`, `Strategy`, `ChainNode`.

Fail-fast gating: while D4 has not landed, default `FURROW_STRUCTURE_TEST_REQUIRE_STRATEGIES=0` so assertion #1 is skipped (#2, #3 still run). W3 flips to `1`, making D4 step omissions hard-fail.

Verify: `go test -run TestStructure ./internal/cli/context/...`

<!-- spec:section:audit-table-format -->
## Audit Table Format

`docs/architecture/context-construction-patterns.md` Section 6 (AC #4, #5). Four columns; sites enumerated exhaustively (no "..."):

| File:line | Current Mechanism | Target Pattern | Migration Owner |
|-----------|-------------------|----------------|-----------------|
| `commands/work.md:NN-MM` | inline markdown reads `skills/{step}.md` | Strategy via `furrow context for-step --target operator` | D4 (W3) |
| `skills/work-context.md:NN` | static doc on per-row context | Builder result `--target operator` | D4 (W3) |
| `bin/frw.d/scripts/foo.sh:NN` | shell `cat skills/$STEP.md` | Strategy + ChainNode (target filter) | follow-up TODO `migrate-frw-d-context-loaders` |
| `internal/cli/.../bar.go:NN` | hard-coded path concat | ContextSource reader | D4 (W3) or follow-up |

Rules: `file:line` MUST be grep-able (verify by `grep -n` per row). Mechanism is one-line factual. Pattern column cites only Builder / Strategy / ChainNode / ContextSource reader. Owner is `D4 (W3)` or `follow-up TODO <slug>` — slugs added to `.furrow/almanac/todos.yaml` at row close. Every non-migrated site gets an explicit follow-up row.

<!-- spec:section:acceptance -->
## Acceptance Scenarios

### AC #1 — Interfaces declared

WHEN a contributor reads `contracts.go` THEN each interface has a godoc paragraph naming pattern + architectural intent.
Verify: `go doc ./internal/cli/context Builder Strategy ChainNode` prints pattern names; `gofmt -l` empty.

### AC #2 — Conformance harness exported

WHEN a strategy `_test.go` calls `context.TestStrategyConformance(t, factory, src)` THEN the harness exercises Step(), Apply idempotency, empty-source robustness.
Verify: `go test -run TestStrategyConformance ./internal/cli/context/...` runs against the in-test fake.

### AC #3 — Structural test fails fast on missing strategy

WHEN `evals/gates/newstep.yaml` exists, `strategies/newstep.go` does not, and `FURROW_STRUCTURE_TEST_REQUIRE_STRATEGIES=1` THEN `go test -run TestStructure ./internal/cli/context/...` fails with the message in Structural Test #1.
Verify: a sub-test sets up a fixture overlay, asserts failure; cleanup, asserts pass.

### AC #4 — Doc has six sections

WHEN a reviewer opens the architecture doc THEN sections (1)-(6) appear in order with `##` headers.
Verify: `grep -c '^## ' docs/architecture/context-construction-patterns.md` >= 6.

### AC #5 — Audit table concrete

WHEN a reviewer reads Section 6 THEN every row has real file:line, one-line mechanism, pattern citation, owner. No TBD.
Verify: shell loop runs `grep -n` per `file:line`; missing anchors fail review.

### AC #7 — Review coupling

WHEN W3 review begins THEN D4's strategies_test.go invokes the harness for all 7 steps and passes; D5 sign-off is held until green. See review-coupling section.

### AC #8 — Build hygiene

WHEN `go test ./...` and `go vet ./...` run THEN both exit 0. CI gate.

<!-- spec:section:open-questions -->
## Open Questions

1. **`step_strategy_metadata` typing** — `map[string]any` for forward compat; if D4 needs a typed sub-shape, widen via assertions or re-spec a sealed interface. Default: leave as map unless D4's W3 plan documents a concrete need.
2. **Structural-test gating** — env var (`FURROW_STRUCTURE_TEST_REQUIRE_STRATEGIES`) vs build tag (`//go:build furrow_d4`). Default env var; switch to build tag if CI cannot inject per-wave envs. Resolve before W1 commit.
3. **`Bundle.Learnings` placement** — D4's AC has only `prior_artifacts.learnings`, no top-level. Resolution: drop top-level `Learnings` from `Bundle`; keep only `Artifact.Learnings`. **(Already applied in interface block.)**
4. **`ContextSource` ownership** — D5 defines (Strategy.Apply references it); D4 ships the concrete reader. Confirmed split.

None block W1 implementation; defaults documented above.

<!-- spec:section:review-coupling -->
## Review Coupling

D5 review sign-off is partially gated on D4 passing the conformance harness (AC #6, #7).

1. **W1 review** (D5 alone): green when AC #1-#5, #8 pass. Harness MUST exist and be callable; an in-test fake strategy proves it non-vacuous. No production strategy required.
2. **W3 review** (D4): re-review touchpoint on D5. Reviewer runs `go test -run 'TestStrategyConformance|TestBuilderConformance|TestChainNodeConformance' ./internal/cli/context/...` against D4's strategies. Failure routes a defect to the right deliverable; D5 re-opens (`rws transition` back) only if the contract is under-specified — not for D4 implementation bugs.
3. **Contract-gap signal**: if 2+ D4 strategies need the same workaround, classify as a D5 contract gap. Single-strategy workarounds are D4 bugs.
4. D5 final sign-off recorded in W3 review evidence with harness-run output attached.

D5 ships in W1; its review record stays open across two waves.
