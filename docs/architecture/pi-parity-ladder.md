# Pi parity ladder

## Purpose

Define a practical parity ladder for Furrow's Pi-first migration so the project can distinguish between:

1. **usable now**
2. **next canonical milestone**
3. **later fuller parity**

This document is intentionally operational rather than aspirational. It should help guide sequencing decisions and prevent either of these mistakes:

- declaring parity too early because Pi can already drive some row flows
- delaying Pi usage until every historical Furrow behavior is migrated

## Current strategic frame

Furrow is targeting:

- **backend-canonical** semantics
- **artifact-canonical** workflow state under `.furrow/`
- **Pi-advantaged** primary usage
- **Claude-compatible** teammate support later
- **shared semantics, asymmetric UX**

Parity therefore does **not** mean identical Pi and Claude UX.
Parity means both hosts operate over the same canonical backend semantics and `.furrow/` state where those semantics are shared.

## Level 1 — usable early Pi operation

This level means Pi is already useful as a Furrow host for existing rows.
It does **not** mean full lifecycle parity.

### Required properties

- Pi resolves row context from canonical `.furrow/` state
- Pi reads backend state through Go CLI JSON commands
- Pi can provide explicit next-step guidance for an existing row
- Pi can perform real backend-mediated row transitions
- Pi surfaces validation/warnings before major actions
- Pi points the user at row-scoped artifacts
- Pi avoids duplicating domain semantics in TypeScript

### Current backend slice supporting this level

- `furrow almanac validate --json`
- `furrow row list --json`
- `furrow row status --json`
- `furrow row transition --json`
- `furrow doctor --json`

### Current Pi operating-layer slice supporting this level

- `/furrow-overview`
- `/furrow-next`
- `/furrow-transition`

### What this level allows

A human can sit in Pi and:

- inspect the current work landscape
- resolve the focused/active row
- understand the current step and next likely action
- perform a real backend-mediated step transition
- keep work attached to Furrow artifacts

### What this level does **not** guarantee

- full row lifecycle mutation support
- full gate engine semantics
- review/archive parity
- complete artifact enforcement
- clean elimination of all direct state edits
- dual-host validation parity

### Current project state

Furrow has reached this level.

## Level 2 — canonical Pi Furrow operation

This is the next important milestone.

At this level, Pi should be able to drive normal Furrow row work **without requiring manual `state.json` edits** for supported flows.

### Required properties

Everything in Level 1, plus:

- all supported row-state mutations go through backend commands
- Pi no longer needs direct `state.json` edits for ordinary progress bookkeeping
- the Pi operating layer remains thin and backend-driven
- row progress and completion bookkeeping are exposed through narrow backend commands
  - current narrow command: `furrow row complete --json`
- artifact expectations are clearer and more consistently surfaced after actions

### Immediate blocker revealed by real usage

After a real Pi-driven transition, some row deliverable/completion bookkeeping still required manual `state.json` edits.

That violates the canonical Furrow rule:

> all harness state mutations go through CLI/backend commands, never direct file edits

### Minimum work needed to reach this level

- implement the narrow backend surface needed for row bookkeeping after Pi-driven transitions
- update the Pi operating layer to consume that backend surface
- validate that the supported Pi workflow no longer requires direct row-state edits

### Current project state

Furrow now reaches Level 2 for the currently supported Pi-driven existing-row workflow:

- Pi can inspect rows, guide next actions, transition rows, and complete the narrow bookkeeping path without manual `state.json` edits
- the backend remains the only authority for supported row-state mutation
- deeper review/archive/gate parity still remains intentionally deferred

### Important non-goals for this level

Reaching Level 2 does **not** require:

- full review/archive parity
- full gate engine migration
- complete shell-era doctor parity
- Claude compatibility completion
- equal host UX

### Exit criteria

Furrow can claim Level 2 when:

- Pi can drive the supported row workflow without manual `state.json` edits
- backend remains the only authority for supported state mutation
- row artifacts remain first-class in the flow
- the Pi adapter is still thin and does not carry lifecycle semantics in TS

## Level 3 — fuller Furrow parity

This is the later, broader parity milestone.

At this level, Pi and Claude-compatible flows both operate over a much richer shared backend surface.

### Likely required properties

- richer row lifecycle coverage
  - row init/create
  - progress bookkeeping
  - review/archive lifecycle support
- clearer gate semantics
  - gate inspection/state
  - precondition enforcement
  - structured blocked/fail outcomes
- stronger artifact-aware enforcement
- broader adapter stability and packaging
  - Pi adapter promoted from local extension shape into repo-owned adapter layout
- thin Claude compatibility layer over the same backend
- explicit dual-runtime semantic validation

### What parity means here

Parity still means **shared semantics**, not identical UX.
Pi can remain the more capable or ergonomic runtime as long as:

- `.furrow/` remains canonical
- backend semantics remain shared
- Claude-compatible teammate flows stay viable where intended

## Gap summary

### Already achieved

- early Pi usability over real backend commands
- explicit next-step guidance in Pi
- backend-mediated transitions in Pi
- artifact-aware workflow beginnings
- canonical `.furrow/` state model preserved

### Recently closed gap

- **backend-mediated row bookkeeping**

This was the critical Level 1 -> Level 2 parity step because it removed the remaining manual state-edit requirement from the supported Pi-driven Furrow flow.

### Later gaps

- fuller gate semantics
- review/archive lifecycle semantics
- broader artifact enforcement
- Pi adapter stabilization/promotion
- Claude thin compatibility and dual-runtime validation

## Recommended sequencing

1. Keep using Pi now for existing-row Furrow work
2. Close the backend-mediated row bookkeeping gap
3. Update the Pi operating layer to consume that new backend surface
4. Then continue widening lifecycle coverage only where real usage shows it is needed
5. Validate Claude-compatible flows later, after Pi and backend semantics are more settled

## Decision rule

When deciding what to build next, prefer work that moves Furrow from Level 1 to Level 2:

> eliminate manual row-state edits from Pi-driven Furrow operation before expanding into broader parity work.
