# Documentation authority taxonomy

Status: Active
Authority: Canonical
Time horizon: Enduring
Owner: Furrow migration
Related:
- `docs/architecture/migration-stance.md`
- `docs/architecture/dual-runtime-migration-plan.md`
- `docs/architecture/workflow-power-preservation.md`
- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml`

## Purpose

Prevent Furrow documentation from blending:

1. canonical system truth
2. transitional migration strategy
3. planning/sequencing artifacts
4. row-local execution and post-review truth

A document can be durable without being canonical. That distinction must stay
explicit during the migration.

## Core rule

> Canonical architecture docs must not become a dumping ground for row-local
> migration residue.

And:

> Durable row artifacts and handoffs are historical/execution authority, not
> canonical system-definition authority.

## Authority classes

### 1. Canonical

Use for enduring system truths that should still be true after the migration is
finished.

Questions this class answers:
- what Furrow is
- what invariants define the system
- what the intended architecture is
- what long-lived contracts and philosophies govern behavior

Examples:
- workflow philosophy
- `.furrow/` as canonical state
- backend-owned semantics
- staged workflow model
- artifact-first philosophy
- seeds as canonical work graph, if/when fully adopted

Typical homes:
- `README.md`
- `docs/architecture/`
- `references/`

Canonical docs may mention current implementation status, but only in clearly
bounded sections that do not let transient tactics rewrite the enduring design.

### 2. Transitional / migration

Use for temporary strategy that is true primarily because Furrow is mid-migration.

Questions this class answers:
- how are we getting from the old shape to the target shape
- which shims exist and why
- which compatibility boundaries are intentionally preserved
- what sequencing/cutover constraints are temporary

Examples:
- migration stance
- dual-runtime cutover sequencing
- wrapper preservation policy
- temporary compatibility seams

Typical homes:
- `docs/architecture/dual-runtime-migration-plan.md`
- `docs/architecture/migration-stance.md`
- future `docs/migration/` material if this grows

### 3. Planning

Use for sequencing and prioritization, not for defining the system.

Questions this class answers:
- what should happen next
- how work is grouped into phases/rows
- dependency and scheduling decisions

Examples:
- roadmap phases
- todo definitions
- row grouping and ordering

Typical homes:
- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml`

Planning docs should not become the canonical source of architecture semantics.

### 4. Historical / execution

Use for row-local intent, validation, landed-scope truth, and post-review
reconciliation.

Questions this class answers:
- what this slice planned to do
- what actually landed
- what validation was run
- what changed relative to plan
- what the next session should know about this row

Examples:
- row artifacts
- handoff docs
- post-review summaries
- validation logs

Typical homes:
- `.furrow/rows/<row>/...`
- `docs/handoffs/...`

These artifacts are durable and important, but they are not canonical system
truth.

## Durable vs canonical

This distinction is mandatory.

- durable = worth preserving
- canonical = authoritative description of the system itself

Examples:
- a row validation log is durable, but not canonical
- a post-review handoff is durable, but not canonical
- an architecture contract is both durable and canonical

## Required framing for important docs

Important docs should make these axes obvious, either explicitly in frontmatter
or in the opening section:

- **status**: proposed / active / implemented / historical
- **authority**: canonical / transitional / planning / historical-execution
- **time horizon**: enduring / transitional / row-local

A lightweight convention is enough. Example:

```md
Status: Active
Authority: Transitional
Time horizon: Migration
```

or:

```md
Status: Implemented
Authority: Canonical
Time horizon: Enduring
```

## Placement rules

### Canonical docs should contain
- intended design
- enduring contracts
- philosophy
- stable infrastructure descriptions

### Canonical docs should avoid
- row-specific next-session guidance
- transient workaround instructions
- temporary shim rationale unless explicitly bounded as transitional
- implementation drift notes that belong in row artifacts or migration docs

### Transitional docs should contain
- cutover sequencing
- shim rationale
- compatibility boundaries
- migration stance and guardrails

### Planning docs should contain
- dependency and sequencing decisions
- active vs done work classification
- row grouping

### Historical/execution docs should contain
- planned vs landed scope
- review findings
- validation evidence
- row-local next-session guidance

## Tests for deciding where content belongs

### Test 1
Would this still be true after the migration ends?

- yes → probably canonical
- no → probably transitional or historical

### Test 2
Is this about one row/slice rather than the system?

- yes → historical/execution
- no → canonical, transitional, or planning

### Test 3
Is this primarily sequencing/prioritization rather than system definition?

- yes → planning
- no → canonical or transitional

## Anti-patterns to avoid

### 1. Architecture docs as migration diaries

Avoid repeated “for now / later / currently / eventually” prose that turns an
architecture doc into a transitional changelog.

### 2. Row handoffs as de facto architecture

A post-review handoff may describe what landed, but it should not silently
become the canonical definition of Furrow.

### 3. Planning docs defining semantics

Roadmap/todos should sequence and group work, not replace architecture docs as
semantic authority.

### 4. Migration tactics presented as timeless philosophy

A wrapper, shim, or minimum slice may be necessary now without being part of the
enduring shape of the system.

### 5. Contract-doc precedence rule

**Anti-pattern**: a target-state or implementation-state document states a
scope that exceeds the scope declared in the contract document covering the
same surface, with no explicit temporal qualifier or precedence rule
reconciling them. The contract document appears narrower but the sibling
document's broader claim is never invalidated.

**Examples in this codebase**:
- `pi-almanac-operating-model.md` states "seeds replace TODOs as the
  canonical planning primitive" (forward-leaning target) without temporal
  qualification, conflicting with the Phase 5 deferral in the same file.
- `pi-step-ceremony-and-artifact-enforcement.md:374-388` claims per-step
  artifact validation is enforced; `go-cli-contract.md:392-399` lists those
  behaviors as not-yet-enforced without a reconciling precedence rule.

**Precedence rule**: when scope language in a target-state or
implementation-state document conflicts with scope language in a contract
document, the contract document wins. The broader claim in the sibling
document must add an explicit temporal qualifier (date, phase, or TODO
closure condition) before it supersedes the contract. Until that qualifier
is present, assume the narrower contract scope is operative.

## Documentation policy for the current migration

- keep canonical system truths in canonical docs
- keep transitional migration strategy in migration docs
- keep row/slice truth in row artifacts and handoffs
- keep sequencing in roadmap/todos
- when a doc mixes classes, either split it or add clearly bounded sections
- when in doubt, prefer moving transient implementation residue out of
  canonical docs and into migration or historical/execution docs

## Bottom line

Furrow should preserve:
- canonical truth
- transitional strategy
- planning truth
- historical execution truth

But it should stop blending them into one tone and one document type.
