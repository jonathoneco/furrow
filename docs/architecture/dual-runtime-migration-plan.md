# Dual-Runtime Migration Plan

## Decision

Furrow should migrate **in-repo**, but under a contract-first, backend-first
plan that explicitly resists runtime-shaped drift.

The target is **not** equal-runtime product parity.
The target is:

- **backend-canonical**
- **artifact-canonical**
- **Pi-advantaged for the primary authoring workflow**
- **Claude-compatible for teammate participation**

This keeps the real history, artifacts, and architectural continuity inside the
`furrow` repository while avoiding a repeat of the speculative portability
spike.

## Why keep the migration in `furrow`

Benefits:

- preserves the real commit history of the rewrite
- keeps design docs, contracts, and backend changes close to the code they
  govern
- lets the existing harness artifacts continue to document decisions
- avoids a second repo becoming the de facto source of truth

Risk:

- building inside the repo can bias decisions toward the current Claude-shaped
  implementation and its habits

Mitigation:

- freeze the architecture and CLI contracts before broad implementation
- keep Pi research/docs archived outside the repo as reference, not as code
- require adapter decisions to justify themselves against the backend contract
- treat current shell/Claude behavior as compatibility input, not as the target
  architecture

## Target architecture

```text
                    +---------------------------+
                    |       .furrow/ state      |
                    | rows / almanac / seeds    |
                    +-------------+-------------+
                                  |
                                  v
                    +---------------------------+
                    |   Go backend / furrow CLI |
                    | row / gate / review /     |
                    | almanac / seeds / merge   |
                    +------+------+-------------+
                           |      |
                 JSON CLI   |      | JSON CLI
                 contract   |      |
                           v      v
               +----------------+  +----------------+
               | Claude adapter |  |   Pi adapter    |
               | commands/hooks |  | package/ext/UI  |
               | wrappers       |  | events/subagents|
               +----------------+  +----------------+
```

## Core principles

1. **`.furrow/` stays canonical**
   - runtime session state is never authoritative
2. **Go owns workflow semantics**
   - row lifecycle
   - gates
   - reviews
   - almanac
   - seeds
   - merge/archive
3. **Adapters stay thin**
   - registration
   - hook/event wiring
   - host-native rendering
   - host-specific invocation shims
4. **Shared semantics, asymmetric UX**
   - same semantics and artifacts across hosts
   - different runtime delivery and ergonomics are acceptable
5. **Pi is allowed to be better**
   - Pi may gain stronger UX and runtime-native affordances without waiting for
     equivalent Claude UX
6. **Claude compatibility is preserved where cheap and non-distorting**
   - `frw`, `rws`, `alm`, `sds` remain available while delegating to Go over time
   - teammate viability matters; equal UX does not

## Migration phases

### Phase A — architecture freeze

Outputs:

- `docs/architecture/core-adapter-boundary.md`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/host-strategy-matrix.md`
- this migration plan

Goal:

- remove ambiguity before major implementation

### Phase B — Go backend contract implementation

Goal:

- make the `furrow` binary real enough to become the canonical backend surface
- unlock Pi early through a minimal but real shared backend slice

Initial target:

- `furrow almanac validate`
- `furrow row list`
- `furrow row status`
- `furrow row transition`
- `furrow doctor`
- JSON envelopes
- stable exit codes

Current status note:

- the first usable minimum slice is now implemented for those commands
- `row transition` is intentionally narrow-real rather than full-lifecycle
- the next session should build the first Pi operating layer on top of that
  backend slice rather than widening the backend speculatively

### Phase C — Pi-primary adapter implementation

Goal:

- build a fresh Pi adapter as soon as the backend is stable enough to consume
- let the primary authoring workflow move onto Pi early
- avoid waiting for full Claude delegation before Pi becomes useful

Inputs:

- Go JSON contract
- boundary rules
- archived portability research
- Pi baseline extensions and manual exploration findings

### Phase D — Claude compatibility preservation

Goal:

- keep Furrow usable in Claude Code for teammates while core logic moves into Go

Mechanism:

- keep shell wrappers
- gradually delegate from shell entrypoints to Go subcommands
- preserve shared artifact and workflow semantics without demanding equal UX

### Phase E — shared-backend validation

Goal:

- verify that Claude and Pi both operate correctly over the same backend and
  `.furrow/` state
- validate semantic compatibility, not identical runtime experience

## Operating model during migration

This is the key practical decision.

### Recommendation: backend-canonical, Pi-early operating mode

Use **Furrow in-repo** for:

- roadmap work
- TODO management
- architecture docs
- Go backend implementation
- repository-local artifacts and decision history

Use **Pi as early as backend calls are stable enough to consume** for:

- primary implementation work
- UX experiments
- extension testing
- validating Pi-native strengths against the real backend

Use **Claude Code** for:

- teammate participation
- compatibility validation
- ongoing work against the same backend and artifacts

Do **not** rely on either runtime to own semantics outside the backend.

## Why this operating mode is the right compromise

### Why not keep Claude as the primary rewrite environment?

Because the current harness still carries Claude-shaped assumptions and can bias
implementation choices away from Pi's strengths.

### Why not let Pi own semantics immediately?

Because Pi-side quality should ride on a stable Furrow backend, not on
extension-local logic that becomes the accidental source of truth.

### So what should happen?

- let the backend stay authoritative
- let Pi become the primary authoring runtime as soon as backend calls are real
- keep Claude viable for teammates through thin compatibility layers
- validate shared semantics across hosts after the adapter and backend are both
  real enough to test

## Practical rule of thumb

### Must be shared across hosts

- `.furrow/` state
- CLI semantics
- artifact formats
- row/gate/review behavior
- schema and validation rules

### Can diverge across hosts

- command registration
- hook/event names
- compaction delivery
- UI/widgets/status surfaces
- subagent orchestration details

### Can be Pi-only if they do not change shared semantics

- stronger TUI affordances
- runtime-native shortcuts and modes
- Pi-specific helper extensions
- richer personal workflow ergonomics

## Guardrails against bad in-repo decisions

1. **No adapter implementation without contract reference**
   - adapter work should point back to the Go CLI contract and boundary docs
2. **No domain logic in TypeScript adapters**
   - if it mutates `.furrow/` semantics, it belongs in Go
3. **No revival of the old portability spike as code**
   - use the archived research as design input only
4. **Prefer compatibility shims over parallel logic**
   - avoid split-brain shell/TS/Go semantics
5. **Keep manual parity claims labeled as provisional**
   - until exercised against real backend commands

## Immediate next actions

1. finalize the target architecture doc set
2. finalize the first Go CLI contract surface
3. implement the minimum shared backend slice (`almanac validate`, `row list`,
   `row status`, `row transition`, `doctor`)
4. lock the backend slice to reality in docs and handoff artifacts
5. begin the first Pi operating layer as soon as that slice is stable enough to
   consume
6. preserve Claude usability through wrapper delegation, but do not block Pi on
   full Claude parity
7. continue deepening backend semantics only when real dual-runtime usage shows
   that the backend contract is too thin

## Recommendation summary

- **Yes**, land the migration in `furrow`
- **No**, do not let the repo location implicitly decide the architecture
- **Treat the backend and artifacts as the shared contract**
- **Move onto Pi early once backend calls are stable enough**
- **Keep Claude compatible for teammates where that remains thin and cheap**
- **Validate shared semantics across hosts; do not require equal UX**
