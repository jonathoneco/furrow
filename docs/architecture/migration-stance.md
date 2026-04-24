# Migration stance

Status: Active
Authority: Transitional / migration
Time horizon: Transitional
Owner: Furrow migration
Related:
- `docs/architecture/dual-runtime-migration-plan.md`
- `docs/architecture/core-adapter-boundary.md`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/workflow-power-preservation.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/architecture/documentation-authority-taxonomy.md`
- `docs/architecture/documentation-cleanup-pass-proposal.md`
- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml`

## Purpose

Set a concrete migration stance so Furrow stops treating migration strategy
choices as if they were core truths of the system.

The migration should be:

- **conservative about invariants**
- **aggressive about cutovers and simplification**

Furrow is a relatively small codebase. Migration overhead, duplicate paths,
partial slices that never quite finish the real boundary, and prolonged shims
can become more expensive than decisive target-shape changes.

## Decision summary

### Be conservative about

- canonical `.furrow/` state
- backend/CLI authority for supported workflow mutations
- backend ownership of lifecycle and domain semantics
- durable row artifacts as workflow inputs and outputs
- staged workflow and explicit human decision surfaces
- shared semantics across hosts where behavior is meant to match

### Be aggressive about

- deleting or freezing superseded paths
- using the existing target adapter/backend path rather than building parallel paths
- collapsing duplicate surfaces
- finishing real workflow boundaries end-to-end
- rewriting stale planning language once implementation reality changes
- refusing migration shims that exist only to postpone obvious target-shape decisions

## Hard invariants

These must remain true across the migration.

### 1. `.furrow/` remains canonical

Durable workflow truth lives in repo state and row artifacts, not in host-local
session memory or adapter-private state.

### 2. Supported mutations go through backend/CLI authority

Canonical workflow state must not depend on direct file edits or adapter-owned
mutation semantics.

### 3. Lifecycle/domain semantics are backend-owned

Rows, transitions, blockers, checkpoints, reviews, archives, and seed semantics
belong in backend contracts, not in TypeScript or prompt-only conventions.

### 4. Durable artifacts remain first-class

Artifacts are not chat exhaust. They are real workflow inputs/outputs that later
stages consume.

### 5. Furrow remains staged and ceremony-driven

The workflow must remain recognizably stageful rather than collapsing into a
single unstructured task loop.

### 6. Human decision points remain real

Where Furrow says a boundary is supervised, blocked, or dispositioned by a
human, that must remain explicit.

### 7. Shared semantics across hosts remain real

Pi and Claude-compatible flows do not need identical UX, but they should not
silently diverge on canonical workflow semantics.

## Non-invariants

These are important implementation choices, but they are not core truths of the
system.

Examples:

- exact adapter file layout
- whether help is exposed through `row help` or `row init --help`
- whether a wrapper still exists during migration
- whether a slice was implemented via one large cut or several smaller cuts
- exact wording in roadmap/todos before truth-sync
- whether a command lives in a legacy shell entrypoint or directly in Go

These may matter, but they should not be protected with the same caution as the
hard invariants above.

## Migration policy

### 1. Prefer target-shape implementation over transitional shims

If the target path is clear and does not violate an invariant, prefer building
or extending that path directly.

Example:
- use the existing Furrow Pi adapter in `adapters/pi/furrow.ts`
- do not create a parallel Pi adapter just to keep options open

### 2. Keep only shims that protect an active compatibility boundary

A shim is justified only when it protects a real near-term boundary such as:

- teammate Claude compatibility
- durable canonical state during cutover
- a narrow backend contract seam that is actively being consumed

If a shim exists only because the migration is hesitant to commit to the target
shape, it should be avoided or removed.

### 3. Finish real workflow boundaries end-to-end

When a boundary is touched, prefer completing a real vertical slice rather than
landing another partial surface that still needs prompt glue or manual truth
reconciliation.

Examples:
- a `/work` loop should be treated as a real operating boundary
- review/archive semantics should eventually be folded back into that same loop
  rather than living forever as disconnected secondary paths

### 4. Do not deepen superseded paths

Once the intended path exists:

- freeze or minimize the old path
- stop adding significant new semantics to it
- keep it only as long as its compatibility purpose is still real

### 5. Reconcile planning truth after landing

Every meaningful landed slice should disposition:

- what was planned
- what actually landed
- what was deferred
- what the next slice now is

Roadmap/todos should then be updated as reconciliation artifacts, not left in a
pre-landing aspirational state.

### 6. Treat roadmap rows as scope authority

Recommendations for the next session should normally be expressed as emphasis
within an existing roadmap row/todo boundary, not as silently invented new
tracks.

If a new row or renamed slice is truly needed, it should be called out as a
planning change rather than smuggled in through handoff wording.

## Planning truth hierarchy

For migration work, use this authority order:

1. repo implementation reality
2. row validation / post-review truth
3. row slice spec / original handoff
4. roadmap and todos

This does **not** make roadmap/todos unimportant. It means they must be kept in
sync with landed reality rather than treated as self-justifying truth once the
repo has moved.

## Questions to ask before adding a shim or partial slice

1. What invariant does this caution protect?
2. Is that invariant real, or is it just a migration preference?
3. Is there already an intended target path we should extend directly?
4. Will this leave behind another partial surface that future sessions must
   mentally translate?
5. Would a decisive cut be cheaper overall in a codebase this size?

If those questions do not identify a real invariant or active compatibility
boundary, prefer the more direct cut.

## Immediate implications for the current migration

- keep `.furrow/` canonical
- keep backend semantics canonical
- use the existing Furrow Pi adapter in `adapters/pi/furrow.ts`
- preserve Claude compatibility where it serves real teammate use
- avoid parallel adapter paths and long-lived prompt-only semantics
- prefer stronger backend-owned workflow boundaries over repeated partial-slice
  staging once the operating path is already real

## Bottom line

Furrow should not be reckless.
But it should stop paying large-system migration costs for small-system changes.

The correct stance is:

- **strict on invariants**
- **strict on canonical authority**
- **aggressive on simplification**
- **aggressive on decisive cutovers**
- **aggressive on planning-truth reconciliation**
