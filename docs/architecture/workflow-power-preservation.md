# Workflow power preservation

Status: Active
Authority: Canonical
Time horizon: Enduring

## Purpose

Protect Furrow's migration from succeeding structurally while atrophying functionally.

The current migration has already preserved important fundamentals:

- `.furrow/` remains canonical
- backend semantics are moving into the Go CLI
- Pi is becoming a thin host adapter rather than a second source of truth
- durable row artifacts continue to exist on disk

Those are necessary, but they are not the whole value of Furrow.

Furrow is not just rows, state files, and commands. Its real value is that an
active session can act as an orchestration layer over:

- stage-aware workflow progression
- context-aware artifact production and consumption
- evaluator/review separation
- human-in-the-loop decisions
- explicit coordination of parallel work
- durable auditability of decisions and outcomes

If the migration preserves only canonical state and thin adapters, Furrow can
become cleaner but weaker. This document defines the workflow power that must be
preserved explicitly.

## Core preservation principle

The migration must preserve not only:

- canonical state
- backend-owned semantics
- thin host adapters

but also:

- **stage-aware ceremony**
- **artifact-driven continuation**
- **review and evaluator separation**
- **human-in-the-loop decision surfaces**
- **coordination and parallelization primitives**
- **context routing across stages and actors**

## What Furrow's power actually is

### 1. The active session is an orchestration layer

The active chat session should not merely mutate state. It should orchestrate:

- what stage the row is in
- what context matters for that stage
- what artifacts are required now
- what prior artifacts should be consumed now
- what decision points require human review or explicit approval
- when review/evaluator flows should be invoked
- when parallel work should be launched or coordinated

This does not require the host to own semantics. It does require the host to
make those semantics operational.

### 2. Rows are stage-shaped, not just task-shaped

A row is not complete just because it has a title and state file. A row is a
progressive workflow through stages such as:

- ideate
- research
- plan
- spec
- decompose
- implement
- review

Each stage should have:

- clear purpose
- expected artifacts
- expected context inputs
- a recognizable definition of "done enough to advance"

### 3. Artifacts are not just outputs; they are workflow inputs

The migration should preserve the fact that Furrow artifacts are used to drive
later work, not merely to document it afterward.

Examples:

- ideation artifacts shape research
- research artifacts shape planning and spec
- plan/spec/decompose artifacts shape implementation
- review artifacts shape correction and human decisions
- handoff artifacts shape the next session's startup context

### 4. Review and evaluator separation are core, not optional polish

Furrow's workflow power includes keeping generation and evaluation distinct.
That includes:

- review as a structurally separate activity
- evaluator logic not collapsing into the generator path
- review outputs feeding back into the workflow as explicit evidence

### 5. Human-in-the-loop surfaces are part of the workflow

Furrow should preserve explicit points where a human is expected to:

- approve or reject progression
- choose between alternatives
- disposition review findings
- unblock external actions
- provide feedback that re-enters the workflow

### 6. Coordination and parallelism are first-class power

Furrow is not only for single-threaded row progression.
Its coordination power includes:

- decomposition inside a row
- wave-structured parallel work within a row
- multiple rows active within a roadmap phase where appropriate
- launch and coordination surfaces such as worktrees and tmux-based orchestration
- explicit ownership and reintegration rather than ad hoc multitasking

### 7. Context routing must remain intentional

The migration should preserve Furrow's ability to load the right context for the
right stage or actor, rather than relying on the model to remember everything.

That includes:

- ambient project context
- row-scoped context
- step-specific context
- review/evaluator context
- handoff context

## What must not atrophy

The following are migration-critical powers, not future nice-to-haves.

### A. Step-aware ceremony

Pi and future adapters should preserve the sense that the workflow is stageful.

Needed behaviors include:

- explicit statement of current stage
- explicit statement of what that stage expects
- expected artifacts surfaced by stage
- warnings or blockers when stage discipline is too thin
- no casual skipping of ideation/research/plan/spec simply because backend
  mutation is available

### B. Artifact scaffolding and filling-in

Artifacts should not exist only because a handoff prompt happened to ask for
them. The system should move toward:

- creating/scaffolding expected artifacts when a row or stage begins
- surfacing missing artifacts as part of the active workflow
- using artifacts as first-class context inputs for later stages

### C. CLI as lived workflow surface, not only mutation API

The Go CLI should become the canonical operational surface for workflow state,
validation, and eventually more orchestration semantics.

The migration should resist a split where:

- backend only offers minimal state mutation
- meaningful workflow behavior survives only in manual prompts

### D. Seeds-backed work graph preservation

Seeds are not just a future feature. They are the planned coordination primitive
for deterministic work decomposition and dependency management.

The migration should continue treating seeds as part of Furrow's preserved power:

- cross-row graph semantics
- within-row decomposition
- dependency-aware orchestration
- reducing reliance on ad hoc reasoning for ordering

### E. Parallel orchestration preservation

The migration must preserve the capability to:

- plan parallel work within a row
- launch or coordinate parallel rows in a roadmap phase
- use runtime surfaces such as worktrees and tmux where they materially improve
  Furrow's leverage
- reintegrate work with explicit audit trails

### F. Enforcement, not only guidance

Warnings are not enough. Some Furrow value comes from structural enforcement.
The migration should preserve or rebuild enforcement around:

- canonical state mutation paths
- stage transitions
- gate/review boundaries
- human decision checkpoints
- artifact expectations where appropriate

## Responsibility split

Preserving workflow power does not mean pushing everything into TypeScript.

### Backend should own

- canonical state and lifecycle semantics
- validation and transition rules
- review/gate/archive semantics as they mature
- seed graph semantics
- machine-readable contract data that adapters consume

### Adapters should own

- making stage-aware ceremony operational in the host
- surfacing expected artifacts and next actions
- lightweight orchestration UX
- human decision prompts and confirmations
- launch/coordination surfaces for parallel work
- using backend/artifact state as runtime context

The rule is:

- **semantics stay backend-owned**
- **workflow operation must still feel like Furrow in the host**

## Migration review questions

Future migration work should be reviewed against both of these questions.

### Structural question

- Does this preserve canonical backend semantics and `.furrow/` state?

### Workflow-power question

- Does this preserve or strengthen Furrow's orchestration power?
  - stage-aware ceremony
  - artifact-driven continuation
  - review/evaluator separation
  - human-in-the-loop decisions
  - context routing
  - coordination/parallelization

If a change helps the first question while weakening the second, it should be
considered incomplete.

## Immediate implications

The current migration should explicitly protect and track at least these areas:

1. **Pi step ceremony and artifact enforcement**
   - make early-stage workflow feel mandatory and structured again
2. **Artifact-driven stage orchestration**
   - use artifacts as inputs, not only outputs
3. **Parallel row and wave orchestration preservation**
   - keep Furrow's coordination power visible and operational
4. **Human-in-the-loop and review decision surfaces**
   - preserve the explicit decision points that make Furrow trustworthy
5. **Seeds-backed orchestration continuity**
   - keep the future graph-based coordination model connected to the migration,
     rather than treating it as unrelated later work

## Bottom line

A successful Furrow migration is not merely:

- backend-canonical
- artifact-canonical
- Pi-usable

It must also remain:

- **workflow-power preserving**
- **stage-aware**
- **artifact-driven**
- **review-aware**
- **human-in-the-loop aware**
- **coordination-capable**

That is the difference between preserving Furrow's shape and preserving its
actual power.
