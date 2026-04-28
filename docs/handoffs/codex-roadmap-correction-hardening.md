# Codex Handoff: Roadmap Correction And Hardening

Mode: out-of-harness Codex session
Recommended branch/worktree: same worktree as Session 2 unless the Phase 1-4
corrections are already large enough to split
Prerequisite: Session 1 row truth gates completed or available as a manual
rubric

## Mission

Audit the remaining roadmap after the Phase 1-4 truth audit and reshape it so
every planned row moves Furrow toward the clean end state.

The roadmap must not merely validate. It must stop encoding future vaporware.

## Operating Rule

A planned row is unsound if it adds a replacement without removing what it
replaces, introduces a transitional mode without a graduation trigger, creates a
second canonical source of truth, or depends on a prerequisite that is not
declared and scheduled.

## Scope

Audit all planned phases after Phase 4, currently Phases 5-15.

Focus on whether the plan converges, not whether the YAML is well-formed.

## Non-Goals

- Do not regenerate `roadmap.yaml` from `alm triage`.
- Do not rewrite the entire roadmap for style.
- Do not add broad new ambitions unless they are required to make existing
  claims true.
- Do not bury blockers as TODOs when they invalidate a phase claim.

## Required Audit Passes

### R1: Clean Cutover Pass

For every row that ports, replaces, normalizes, migrates, or introduces a new
surface, identify the old surface and the removal point.

Failing examples:

- "Port X to Go" without "remove shell X."
- "Add canonical schema" without "delete or adapt old schema."
- "Render adapter output" without "stop backend writing runtime-specific
  artifacts."

Required result:

- Each replacement row either performs the cutover itself or depends on a
  scheduled cutoff row.
- Cutoff rows name the exact files, commands, schemas, or hooks that disappear.

### R2: Transitional Mode Pass

Find planned language that says transitional, compatibility, fallback,
dual-mode, legacy, bridge, shim, or temporary.

Required result:

- Each transitional mechanism has a graduation trigger.
- Each compatibility shim has a removal trigger.
- Anything without a trigger is either removed from the plan or converted into a
  bounded migration row.

### R3: Source-Of-Truth Pass

Find places where two files, schemas, CLIs, or adapters can both define the same
canonical data.

Known pattern to watch:

- `todos.yaml` versus `seeds.jsonl`.

Required result:

- Roadmap states the canonical source, the generated/derived surfaces, and the
  row that deletes or freezes any old source.

### R4: Dependency Truth Pass

Check every row's `depends_on`, rationale, and work description.

Required result:

- A row that relies on another row declares it.
- A row that depends on a bug fix, invariant, or cleanup has that prerequisite
  in the roadmap or in the current correction scope.
- No TODO says "after X" unless X is an actual row, phase, or committed
  correction.

### R5: Phase Batchability Pass

The existing parallel-batch invariant catches intra-phase dependencies. It does
not catch shared-file collision risk or semantic interference.

Required result:

- Rows in the same phase do not plan to edit the same high-risk files unless
  the collision is intentionally accepted and documented.
- High-overlap rows are split into single-row phases or sequenced phases.
- Adapter/backend boundary work is not split across rows in a way that creates
  contradictory ownership.

### R6: Surface Optionality Pass

Audit options that create pain without useful flexibility.

Examples to examine:

- `work_units` versus `rows`.
- `branch_name` versus `branch`.
- Runtime-specific terms leaking into core schema fields.

Required result:

- Keep optionality only when it buys real capability.
- Collapse redundant names where one canonical term is enough.
- If cleanup is too large for Session 2, add a roadmap row with explicit
  removal semantics, not a TODO.

### R7: Adapter Boundary Pass

Use the Phase 1-4 adapter-bleed audit as a planning gate.

Required result:

- Backend roadmap rows describe Furrow business logic and normalized contracts.
- Claude/Pi roadmap rows describe runtime translation, installation, discovery,
  hook registration, UI affordances, and runtime-specific templates.
- No future backend row owns `.claude`, `.pi`, Claude transcript formats, or Pi
  tool-call syntax except through adapter-neutral test fixtures.

### R8: Review And Ceremony Pass

Check whether the roadmap itself encodes process fixes from Session 1.

Required result:

- Row archive includes PR prep.
- Testing is represented as a primitive, not only row-local acceptance criteria.
- Completion checks include spirit-of-law verdicts.
- Deferrals that block the real ask cannot pass archive.
- Specialists are described as skills loaded into general agents, not registered
  subagent types.
- Research rows use scout/dive when the useful output is option discovery.

## Deliverables

1. `docs/integration/roadmap-truth-hardening-audit.md`
   - Summarize each finding.
   - Label items `VAPORWARE-IN-PLANNING`, `CUTOVER-MISSING`,
     `DUAL-SOURCE`, `DEPENDENCY-GAP`, `COLLISION-RISK`, or
     `OPTIONALITY-DRIFT`.
   - For each item, say whether it was fixed in roadmap or requires a row.

2. `roadmap.yaml` corrections
   - Remove or rewrite unsound planned rows.
   - Add cutoff/removal rows where needed.
   - Add missing dependencies.
   - Split phases where collision risk makes batching dishonest.

3. Verification notes
   - `furrow almanac validate`
   - `frw doctor` parallel-batch invariant
   - Manual collision notes for rows the invariant cannot reason about.

## Exit Criteria

Roadmap hardening is complete when:

- All completed Phase 1-4 claims are true, downgraded, or marked failed.
- Every remaining planned row names how it advances the clean end state.
- Every replacement has a cutover or depends on one.
- Every compatibility shim has a removal trigger.
- Every dual-source period has a canonical source and an ending row.
- Every dependency required for truth is declared.
- The roadmap can be used by future rows without preserving the drift that this
  correction pass found.
