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
- `/furrow-complete`

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

Furrow now reaches a stronger Level 2 for the currently supported Pi-driven workflow:

- Pi can inspect, focus, initialize, scaffold, complete, and advance rows through backend commands without manual `state.json` edits in the supported path
- Pi now exposes a primary `/work` loop that regrounds the active stage, surfaces blockers / seed state / checkpoint state / current-step artifacts, scaffolds only the active step artifact on use, and requires explicit confirmation before supervised advancement
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
  - deeper review/archive lifecycle support inside the same operating loop, beyond the narrow archive checkpoint now supported
- clearer gate semantics
  - gate inspection/state
  - precondition enforcement
  - structured blocked/fail outcomes
  - stronger checkpoint evidence surfaces
- stronger artifact-aware enforcement
  - per-step validation beyond scaffold-presence and incomplete-template detection, especially in implement/review
- explicit blocker taxonomy shared across Pi and Claude-compatible flows
- broader adapter stability and packaging
  - continued stabilization of the repo-owned `adapters/pi/` surface
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
- backend-mediated row bookkeeping
- backend-mediated row init / focus / active-step scaffold support
- a primary Pi `/work` loop over canonical backend state
- active-step artifact scaffolding on use
- supervised confirmation before supported advancement
- canonical `.furrow/` state model preserved

### Current remaining gaps

- fuller review execution and gate semantics beyond the now-landed narrow archive checkpoint/evidence path
- richer implement/review artifact validation beyond the structural checks now in the backend
- fuller archive ceremony beyond backend preconditions and archival evidence
- Claude thin compatibility and dual-runtime validation

## Recommended sequencing

1. Keep using Pi now for backend-canonical staged Furrow work
2. Use the landed `/work` loop as the default operating path for supported flows
3. Continue hardening backend-canonical work-loop boundaries:
   - deepen per-step artifact validation where the current backend checks are still structural
   - strengthen checkpoint / gate evidence toward fuller review semantics
   - expand archive ceremony beyond narrow backend preconditions
   - validate and normalize the shared blocker taxonomy across hosts
4. Validate Claude-compatible flows later, after those backend semantics are more settled
5. Expand Pi-native leverage and seed-backed planning after the boundary semantics are trustworthy

## Decision rule

When deciding what to build next, prefer work that strengthens backend-canonical boundary enforcement inside the landed `/work` loop before expanding into broader parity or host-native polish.
