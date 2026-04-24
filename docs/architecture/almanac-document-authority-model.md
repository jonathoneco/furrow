# Almanac document authority model

Status: Proposed
Owner: Furrow migration
Related:
- `docs/architecture/documentation-authority-taxonomy.md`
- `docs/architecture/documentation-cleanup-pass-proposal.md`
- `docs/architecture/pi-almanac-operating-model.md`
- `docs/architecture/migration-stance.md`
- `references/row-layout.md`
- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml`

## Purpose

Define documentation authority as an eventual Furrow/almanac design concept,
not just a migration cleanup concern.

Furrow should eventually understand that not all documents are the same kind of
truth. Some documents are canonical descriptions of the system, some are
transitional migration strategy, some are planning surfaces, and some are
historical execution artifacts produced by rows.

The almanac should eventually manage those distinctions explicitly.

## Why this matters

Without an authority model, Furrow risks repeatedly blending:

- canonical infrastructure/design truth
- migration-specific tactics and shims
- planning/roadmap sequencing
- row-local execution history and review outcomes

That leads to predictable problems:
- transient migration choices being mistaken for enduring design
- roadmap/todos being treated as semantic authority
- row-local conclusions leaking into canonical docs without promotion
- useful row learnings never being promoted into the enduring knowledge layer

## Core idea

Furrow should eventually manage documentation not only by location, but by:

- **authority class**
- **time horizon**
- **promotion/disposition path**

The existing row/artifact model already handles part of this:
- rows own historical execution artifacts
- handoffs and validation preserve row-local truth
- review/archive can already generate follow-up material

Promotion mechanisms already hint at the other part:
- row outputs can be promoted into broader project knowledge
- learnings/rationale/docs can be elevated beyond the row

This design concept makes those pieces explicit and governable.

## Authority classes

The current target taxonomy is:

- **canonical**
  - enduring system or project truth
  - architecture, references, stable contracts, intended design/philosophy
- **transitional**
  - migration/cutover strategy
  - temporary compatibility seams, shims, migration constraints
- **planning**
  - sequencing and prioritization truth
  - roadmap, todos, recommendations, work selection surfaces
- **historical_execution**
  - row-local or slice-local truth
  - implementation plans, validation records, handoffs, post-review outcomes

See `docs/architecture/documentation-authority-taxonomy.md` for the current
migration-facing policy version of this distinction.

## Time horizons

Authority class alone is not enough. Furrow should also understand a document's
intended time horizon:

- **enduring**
  - should still be true after the migration or current row is over
- **transitional**
  - true only during a migration, cutover, or temporary operating mode
- **row_local**
  - produced for one row/slice/session chain and preserved as execution history

## How this maps to Furrow today

### Row artifacts

Rows already own much of the `historical_execution` layer.

Examples:
- implementation plans
- execution progress
- validation records
- row handoffs
- post-review summaries

These artifacts are durable and valuable, but they are not automatically
canonical.

### Promotion

Promotion is how row-local or transitional knowledge becomes broader project
truth.

Examples:
- learnings promoted out of rows
- rationale updates
- architecture doc updates
- future documentation promotion flows

This means the documentation authority model is partly a row-artifact concept
and partly a promotion/disposition concept.

### Almanac

The almanac should eventually become the index and synthesis layer over these
classes rather than treating all docs as one flat knowledge pool.

Representative almanac responsibilities:
- show canonical docs separately from row execution artifacts
- surface migration/transitional docs without confusing them for enduring truth
- expose planning docs as planning authority, not architecture authority
- track promotion candidates and unresolved documentation disposition

## Promotion/disposition model

At review/archive or similar boundaries, Furrow should eventually be able to ask:

- does this row produce enduring design truth?
- if yes, what canonical doc should absorb it?
- does it only produce row-local history?
- does it require a planning update instead of a canonical doc update?
- is this a migration-specific observation that belongs in transitional docs?

That yields explicit outcomes such as:

- remain a row artifact only
- promote into canonical docs
- promote into transitional/migration docs
- promote into planning surfaces
- generate follow-up work without immediate promotion

## Almanac implications

The eventual almanac/documentation model should support queries like:

- what docs are canonical right now?
- what docs are transitional/migration-only?
- what row artifacts are candidates for promotion?
- which canonical docs have accumulated transitional residue?
- which planning docs are being asked to define semantics they should not own?
- what conclusions from completed rows were never promoted?

This is a design target, not a claim that the current almanac already supports
all of it.

## Interaction with planned Furrow work

### `pi-almanac-operating-model`

This concept belongs directly in the long-term Pi/almanac design because Pi
planning surfaces should be able to browse and reason about different authority
classes rather than flattening all documentation into one undifferentiated
layer.

### `ambient-context-promotion`

This concept also belongs in promotion work because promotion is the mechanism
that moves truth between authority classes/scopes.

### Row artifacts / review / archive

Historical execution truth is already partially modeled through row artifacts.
Future review/archive semantics should make documentation disposition more
explicit rather than assuming useful row truth will promote itself.

## Non-goal

This concept does **not** require turning every doc into a heavy schema object
right now.

The point is for Furrow to understand the distinction between:
- canonical truth
- transitional truth
- planning truth
- historical execution truth

The eventual implementation can stay lightweight as long as those authority
boundaries become explicit and operable.

## Success criteria

This concept is in place when Furrow can:

- distinguish canonical vs transitional vs planning vs historical docs
- preserve row-local truth without mistaking it for canonical truth
- support explicit promotion of row-derived knowledge into enduring docs
- prevent planning surfaces from becoming de facto semantic authority
- let the almanac browse and synthesize knowledge by authority class and time
  horizon

## Bottom line

Documentation authority is not just a cleanup concern.
It is an eventual Furrow/almanac capability.

Some of it is already naturally handled by row artifacts.
Some of it is naturally handled by promotion.
The almanac's longer-term job is to make those relationships explicit.
