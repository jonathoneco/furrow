# Pi almanac operating model

Status: Proposed
Authority: Canonical operating model
Time horizon: Enduring target with transitional sequencing notes
Owner: Furrow migration
Related:
- `docs/architecture/workflow-power-preservation.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/dual-runtime-migration-plan.md`
- `docs/architecture/host-strategy-matrix.md`
- `docs/architecture/pi-native-capability-leverage.md`
- `docs/architecture/documentation-authority-taxonomy.md`
- `docs/architecture/almanac-document-authority-model.md`
- `.furrow/almanac/todos.yaml` (`seeds-concept`)
- `commands/work.md`
- `commands/next.md`
- `references/row-layout.md`

## Purpose

Define how Furrow's planning and knowledge surfaces should operate in Pi without
recreating split-brain task tracking.

This document answers four questions:

1. what the almanac is for once Pi becomes the primary host
2. how almanac, rows, and seeds divide responsibility
3. what Pi should expose as planning surfaces beyond `/work`
4. how Furrow should converge away from `todos.yaml` toward a seed-backed work
   graph

## Decision summary

The target model is:

- **`/work` stays primary**
- **explicit planning surfaces exist as secondary Pi entrypoints**
- **seeds replace TODOs as the canonical planning primitive**
- **seeds are typed graph nodes across multiple scopes**
- **each row has exactly one primary seed plus optional related seeds**
- **roadmap becomes an almanac projection over the seed graph**
- **almanac becomes memory + synthesis, not the canonical task registry**
- **roadmap guidance is a strong default with explicit override, not a cage**
- **Pi should ship command-first planning surfaces, with richer widgets/resources
  and presets as fast follow**

## Core responsibility split

### Rows

Rows remain Furrow's execution and ceremony unit.

Rows own:
- staged work (`ideate -> research -> plan -> spec -> decompose -> implement -> review`)
- row artifacts
- gate and review lifecycle
- row-local orchestration context
- session-to-session continuation of active execution work

### Seeds

Seeds become Furrow's canonical work graph.

Seeds own:
- work-item identity
- hierarchy / parent-child relationships
- dependency edges
- scheduling and readiness state
- row linkage
- decomposition into independently meaningful work units
- follow-up work produced by review/archive
- the substrate for kanban / ADO / Trello-like planning inside Furrow

### Almanac

The almanac remains Furrow's planning and knowledge layer, but not the long-term
canonical task registry.

The almanac owns:
- `roadmap.yaml`
- `rationale.yaml`
- `observations.yaml`
- promoted learnings
- docs/history/specialists indexes and related knowledge surfaces
- planning summaries, rendered views, handoffs, and recommendation outputs
- eventual indexing/synthesis over documentation authority classes

In the target model, the almanac reads and synthesizes canonical work state from
seeds rather than owning a parallel TODO registry.

It should also eventually understand that not all documents are the same kind of
truth. Some are canonical, some transitional, some planning, and some row-local
historical execution artifacts. The almanac should eventually help Furrow browse
and synthesize those classes explicitly rather than flattening them into one
undifferentiated documentation layer.

### Pi

Pi owns host-native operator experience.

Pi should provide:
- the primary `/work` loop
- explicit planning surfaces for browsing, creating, triaging, and selecting work
- roadmap and knowledge visibility
- supervised confirmations and selection UX
- richer host-native planning affordances later

Pi should **not** become the source of truth for task semantics.

## `/work` vs explicit planning surfaces

Pi should support both:

1. **primary `/work`**
   - the main front door for execution
   - almanac-aware and seed-aware
   - able to orient the user to current work, roadmap context, blockers, and
     next likely action

2. **secondary planning surfaces**
   - for browsing roadmap and work graph state
   - creating work items
   - triaging and reshaping the roadmap
   - inspecting rationale/learnings/history
   - selecting what to start next when no row is already in flight

`/work` remains primary. Planning surfaces should support it, not compete with
it.

## Roadmap discipline

Roadmap guidance in Pi should be a **strong default with explicit override**.

That means:
- Pi should recommend roadmap-aligned work first
- Pi should make off-roadmap work explicit and visible
- Pi should not silently discard roadmap structure
- Pi should not trap the operator in roadmap-only operation when an intentional
  override is needed

The right behavior is:
- **default to roadmap discipline**
- **allow explicit operator override**
- **record divergence clearly**

## Seed-backed planning model

## Seeds replace TODOs

Furrow should converge to **A1**:
- seeds replace TODOs as the canonical planning primitive
- `todos.yaml` is retired rather than preserved as a permanent parallel system
- roadmap and triage read from the seed graph
- almanac stops being the canonical task registry

> **Transitional authority rule (authoritative until Phase 5 cutover)**:
> `todos.yaml` remains the authoritative planning registry until the Phase 5
> seed cutover. Rows MUST read TODOs and MAY consult seeds; rows MUST NOT
> operate seeds-only. The "seeds replace TODOs" target above describes the
> post-cutover end state, not the current authority. See "Sequencing" below
> for the cutover gate.

`todos.yaml` may remain temporarily only as migration compatibility, but Pi
should not be designed around it as the long-term model.

## Seeds are typed graph nodes

Seeds should grow beyond simple ticket records.

They should be able to represent multiple scopes of work such as:
- initiative / epic
- roadmap item
- row-backing work item
- decomposed work unit
- deliverable
- follow-up task
- watch / observation-derived work item
- deferred work

This is the substrate that lets Furrow unify:
- planning
- decomposition
- delegation
- dependency tracking
- review follow-up
- parallelization

## One primary seed per row, plus related seeds

Each row should continue to have exactly one **primary backing seed**.

A row may also reference related seeds such as:
- child seeds
- dependent seeds
- blocked-by seeds
- spawned follow-up seeds
- upstream epic/initiative seeds

This preserves the row-as-execution-unit model while allowing richer graph
relationships around it.

## Operationalization rule

The key seed rule is:

> **If Furrow is going to orchestrate it, it must exist as a seed.**

This is the balance between fluid thinking and strong enforcement.

Decomposition may begin as local scratch thinking, but once a work unit becomes
operational, it must be materialized as a seed before proceeding.

A work unit is operational when it is going to be:
- delegated
- parallelized
- independently reviewed
- handed off to another session / agent / worktree
- roadmap-scheduled
- tracked as a meaningful deliverable or sub-deliverable

Derived enforcement rule:

> **No delegation, parallel launch, or independent review without a seed-backed
> work unit.**

This keeps seeds from becoming pure bureaucracy while still making them the
canonical unit of orchestration legitimacy.

## Review/archive follow-up

When review or archive generates follow-up work, Furrow should propose new seeds
for confirmation in supervised mode, then create them canonically once approved.

That keeps follow-up work in the graph instead of falling back to loose notes or
ad hoc TODO extraction.

## Pi surfaces: required first slice

The first Pi almanac slice should be treated as **required**, not optional
polish.

Required capabilities:
- browse roadmap state
- browse work-item / seed state in detail
- show next-work recommendations
- initialize rows from roadmap/seed context
- show almanac validation status
- create new work items through canonical seed-backed flows
- triage / regenerate roadmap through canonical backend flows
- surface rationale and learnings when relevant to current planning or work

This first slice should be **command-first**.

Widgets, dynamic resources, presets, prompt templates, and custom UI are useful
Pi-native fast follow, but they should not delay the core planning surface.

## Pi planning behavior

Pi's planning surfaces should help the operator:
- understand current project direction
- inspect what is ready / blocked / active
- choose the right next seed or row
- create new work intentionally
- reshape the roadmap through triage
- start execution with the correct context
- feed review/archive outcomes back into the graph and almanac memory

A Pi operator should not need to spelunk YAML manually to answer:
- what should I work on next?
- why is this prioritized?
- what does this depend on?
- what rationale or learnings should shape this?
- what row should I start from this work item?

## Documentation authority as an almanac concept

The eventual almanac should manage documentation by more than location.
It should eventually understand:

- authority class
  - canonical
  - transitional
  - planning
  - historical execution
- time horizon
  - enduring
  - migration/transitional
  - row-local
- promotion/disposition path
  - stay row-local
  - promote to canonical docs
  - promote to migration docs
  - promote to planning surfaces

This does not mean every document needs a heavy schema immediately. It means
Furrow should eventually know the difference between:
- canonical architecture/reference truth
- migration/cutover truth
- roadmap/planning truth
- row execution truth

Some of this is already naturally handled by row artifacts.
Some of it is handled by promotion flows.
The almanac's future role is to make those relationships explicit and usable.
See `docs/architecture/almanac-document-authority-model.md`.

## Almanac scope after TODO retirement

Once seeds are canonical, the almanac should stay focused on:
- roadmap projections and renders
- rationale
- observations
- promoted learnings
- docs/history/specialists knowledge surfaces
- handoff and synthesis outputs

The almanac should **not** remain a second canonical store of open work items.

This makes the concept cleaner:
- **seeds = canonical work graph**
- **rows = execution ceremony**
- **almanac = memory + synthesis**

## Transitional rule

Current Furrow still has TODO-backed almanac surfaces. During migration:
- existing TODO-backed commands may remain as compatibility shims
- new long-term Pi planning UX should be designed against the seed-backed target
- no major new investment should deepen `todos.yaml` as a permanent authority

If a temporary TODO-backed Pi surface is needed before seeds lands, it should be
labeled as transitional and shaped to collapse cleanly into seed-backed flows.

## Backend implications

The backend will need seed-backed planning surfaces rich enough for Pi to stay
thin.

Representative backend needs include:
- seed list/show/create/update/close/query operations
- graph edge operations and readiness queries
- roadmap generation from seed graph state
- next-work recommendation surfaces
- row-init linkage from a selected seed
- machine-readable planning validation
- rationale/learnings/observations lookup surfaces
- archival follow-up creation/proposal flows

The backend should own planning semantics the same way it owns row semantics.
Pi should consume structured outputs rather than invent planning rules in TS.

## Pi-native fast follow after the first slice

After the command-first planning surface is solid, Pi-native leverage can make
almanac work much better through:
- richer roadmap/status widgets
- dynamic resources for active planning context
- presets and prompt templates for triage/replanning/review follow-up
- custom UI for seed graph browsing and selection
- planning-aware system prompt shaping
- package/distribution ergonomics

These are advantages, not excuses to move canonical semantics out of the
backend.

## Success criteria

The target model is in place when:
- `/work` is visibly almanac-aware and seed-aware
- Pi provides explicit planning surfaces in addition to `/work`
- seeds are the canonical source of planned work
- roadmap is generated from and justified by seed graph state
- each row links to one primary seed and may reference related seeds
- delegated/parallel/independently reviewed work cannot proceed without seed
  identity
- review/archive follow-up work becomes seed-backed rather than loose TODOs
- the almanac can distinguish canonical vs transitional vs planning vs
  historical execution documentation rather than flattening them into one pool
- almanac remains the planning/knowledge synthesis layer rather than a duplicate
  task registry

## Sequencing

> Transitional sequencing note: this section explains how the target model
> should be phased during migration. It is sequencing guidance, not a redefinition
> of the enduring planning model above.

This document does **not** change the immediate priority:
- first restore Pi's staged `/work` loop and ceremony (`Phase 3`)

But it does change the target shape of later planning work:
- seeds should land as the canonical work graph (`Phase 5`)
- Pi almanac/planning surfaces should be built against that seed-backed model
- TODO-backed planning should be treated as transitional compatibility only
- post-parity Pi-native leverage should build on top of this split, not replace
  it
