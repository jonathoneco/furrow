# Go CLI Contract

## Purpose

Define the canonical backend contract Furrow should expose before any real Pi
adapter lands. This document uses the agent-host portability research as input,
but deliberately avoids locking in the speculative `adapters/pi/` spike from the
research branch.

The contract target is:

- **Go CLI owns domain logic**
- **`.furrow/` remains canonical state**
- **runtime adapters call the CLI through stable JSON interfaces**
- **Claude Code and Pi get thin, host-native UX layers**

## Design constraints

1. **No direct state mutation outside the CLI.**
   This preserves the existing Furrow invariant from
   `.claude/rules/cli-mediation.md`.
2. **Filesystem state is canonical.**
   Session-local runtime state must never replace `.furrow/`.
3. **Adapter-facing commands must support `--json`.**
   Human-readable text remains useful, but adapters need structured output.
4. **Exit codes must be stable and documented.**
   Adapters should not parse ad-hoc stderr to discover meaning.
5. **Host-specific behavior lives above the CLI.**
   Prompt injection, slash-command registration, hook wiring, and TUI behavior
   belong to adapters, not the backend.

## Command groups

The future canonical binary should be `furrow`, with legacy wrappers (`frw`,
`rws`, `alm`, `sds`) preserved during migration.

### 1. `furrow row`

Owns row lifecycle and per-row state.

Representative subcommands:

- `furrow row init <name>`
- `furrow row status [<name>]`
- `furrow row transition <name> --step <step>`
- `furrow row complete <name>`
- `furrow row checkpoint <name>`
- `furrow row archive <name>`
- `furrow row summary <name> --regenerate`
- `furrow row validate <name>`
- `furrow row list [--active|--archived|--all]`

JSON contract requirements:

- row name
- focused-row status
- lifecycle step/status
- deliverable progress
- gate status / pending blockers
- canonical artifact paths
- next valid transitions
- tolerant handling of heterogeneous row state during read-oriented commands

### 2. `furrow gate`

Owns deterministic and evaluator-facing gate orchestration.

Representative subcommands:

- `furrow gate run <row> [--step <step>]`
- `furrow gate evaluate <row> --gate <gate>`
- `furrow gate status <row>`
- `furrow gate list --step <step>`

JSON contract requirements:

- gate id / step
- phase-a result
- evaluator-required boolean
- verdict
- blocking reasons
- evidence artifact paths

### 3. `furrow review`

Owns review orchestration and review-state bookkeeping.

Representative subcommands:

- `furrow review run <row>`
- `furrow review cross-model <row> [--deliverable <id>]`
- `furrow review status <row>`
- `furrow review validate <row>`

JSON contract requirements:

- review scope
- review artifacts
- findings summary by severity
- disposition status
- pass/fail/conditional verdict

### 4. `furrow almanac`

Owns roadmap, rationale, TODOs, promoted learnings, and validation.

Representative subcommands:

- `furrow almanac validate`
- `furrow almanac todos list`
- `furrow almanac todos add ...`
- `furrow almanac roadmap show`
- `furrow almanac rationale validate`

JSON contract requirements:

- normalized almanac documents
- schema-validation findings
- referenced row/todo linkage
- machine-readable TODO and roadmap records

### 5. `furrow seeds`

Owns seed graph / task primitive once the seeds work lands.

Representative subcommands:

- `furrow seeds create ...`
- `furrow seeds update ...`
- `furrow seeds show <id>`
- `furrow seeds list`
- `furrow seeds close <id>`

### 6. `furrow merge`

Owns worktree-to-main reconciliation and semantic merge support.

Representative subcommands:

- `furrow merge plan <row>`
- `furrow merge run <row>`
- `furrow merge validate <row>`

### 7. `furrow doctor`

Eventually owns environment, install, schema, and adapter-readiness checks.

Current implemented slice scope:
- backend structural readiness only
- `.furrow` root / rows / almanac usability
- focused-row sanity
- almanac validation summary

Representative subcommands:

- `furrow doctor`
- `furrow doctor --json`
- `furrow doctor --host claude-code`
- `furrow doctor --host pi`

### 8. `furrow init`

Owns repo bootstrap and migration into Furrow conventions.

Representative subcommands:

- `furrow init`
- `furrow init --host claude-code`
- `furrow init --host pi`
- `furrow init --migrate-from-work`

## Shared output contract

Every adapter-facing command should support:

- `--json` for machine-readable output
- `--format text|json` as a future-compatible alias if needed
- stable exit codes

Recommended exit-code baseline:

- `0` success
- `1` usage / invocation error
- `2` blocked by policy or gate
- `3` validation failure
- `4` subcommand / dependency failure
- `5` not found

Each JSON response should include:

```json
{
  "ok": true,
  "command": "furrow row status",
  "version": "v1alpha1",
  "data": {}
}
```

Error responses should include:

```json
{
  "ok": false,
  "command": "furrow row transition",
  "version": "v1alpha1",
  "error": {
    "code": "gate_blocked",
    "message": "review gate failed",
    "details": {}
  }
}
```

## Compatibility wrappers

During migration, keep these wrappers as compatibility shims:

- `bin/frw`
- `bin/rws`
- `bin/alm`
- `bin/sds`

They should translate legacy invocations to the canonical Go binary rather than
preserve independent domain logic.

## Pi-first implementation order

To let Pi come online early without breaking teammate compatibility in Claude
Code, implement the Go surface in this order.

### Slice 1 — minimum shared backend

Make these commands real first:

- `furrow almanac validate --json`
- `furrow row list --json`
- `furrow row status --json`
- `furrow row transition --json`
- `furrow doctor --json`

Why first:

- enough backend reality for a Pi adapter to begin consuming the contract
- enough shared semantics to avoid Pi-only workflow logic
- enough real operability to avoid getting stuck in a read-only halfway state
- small enough surface to stabilize quickly

### Slice 1 — current implemented behavior

The current repository implementation lands a **usable minimum** for the five
commands above. This section is the contract truth for the implemented slice;
broader command-group descriptions elsewhere in this document remain directional
for later phases.

#### `furrow almanac validate --json`

Current behavior:

- validates these canonical files:
  - `.furrow/almanac/todos.yaml`
  - `.furrow/almanac/observations.yaml`
  - `.furrow/almanac/roadmap.yaml`
- returns a JSON envelope with:
  - per-file status
  - per-file document summary
  - structured findings
  - global error/warning counts
- validates the **current live repo document shapes**, not stale historical
  schema text

Current finding categories include:

- duplicate TODO IDs
- dangling TODO `depends_on` references
- invalid enum-like values on supported TODO fields
- malformed observation trigger data
- observation references to missing rows
- roadmap references to missing TODOs
- roadmap references to missing observations
- basic roadmap structural/type issues for the current roadmap shape

Current exit behavior:

- `0` valid
- `3` validation findings
- `5` `.furrow` root or required almanac file missing

#### `furrow row list --json`

Current behavior:

- exists in the minimum slice as the early adapter-facing browse surface
- reads `.furrow/rows/*/state.json` tolerantly
- skips unreadable row JSON with warnings rather than failing the whole listing
- supports:
  - `--active`
  - `--archived`
  - `--all`
- **current default is `all`** to maximize adapter browse usefulness in the
  first Pi operating layer

Current returned fields per row include:

- `name`
- `title`
- `step`
- `step_status`
- `archived`
- `focused`
- `updated_at`
- `branch`
- deliverable counts

#### `furrow row status --json`

Current behavior:

- resolves rows in this order:
  1. explicit row argument
  2. `.furrow/.focused`
  3. latest active row fallback
- exits `5` if no explicit row, usable focused row, or active row can be found
- reads row state tolerantly and normalizes the response for adapters rather
  than dumping raw `state.json`
- includes warnings when focused-row or row-list fallback behavior matters

Current returned data includes:

- resolution source
- row metadata
- deliverable counts and per-deliverable items
- latest gate summary
- canonical artifact paths
- next valid transitions
- warnings

Current exit behavior:

- `0` success
- `1` usage error
- `3` targeted invalid row JSON / invalid row state for the requested read
- `5` row or `.furrow` root not found

#### `furrow row transition --json`

Current behavior is **narrow but real**:

- active rows only
- adjacent forward transitions only
- explicit `--step <next-step>` required
- atomic write to `state.json`
- unknown fields preserved during mutation
- writes a minimal gate-like record into `gates[]`

Current mutation updates:

- `step`
- `step_status`
- `updated_at`
- append-only minimal transition/gate-like record in `gates[]`

That record is intentionally provisional and does **not** imply full lifecycle
semantics. The current implementation does **not** enforce:

- artifact validation
- full gate-policy enforcement
- seed sync
- summary regeneration
- conditional/fail outcomes
- review/archive lifecycle semantics
- broader gate-engine behavior

Current exit behavior:

- `0` success
- `1` usage error
- `2` blocked transition
- `3` invalid row state / invalid row JSON
- `4` write failure
- `5` row or `.furrow` root not found

#### `furrow row complete --json`

Current behavior is intentionally narrow bookkeeping, not broader lifecycle
semantics.

- active rows only
- explicit row argument required
- marks `step_status=completed`
- marks object-shaped deliverables as `status=completed`
- preserves unknown fields
- uses atomic writes
- idempotent if the row is already complete for this bookkeeping shape

What it does **not** imply:

- review approval semantics
- archive semantics
- gate validation or enforcement
- summary regeneration
- generic mutation/patch support

Current exit behavior:

- `0` success
- `1` usage error
- `2` blocked row (for example archived)
- `3` invalid row state / invalid row JSON
- `4` write failure
- `5` row or `.furrow` root not found

#### `furrow doctor --json`

Current behavior is intentionally backend-scoped, not shell-parity scoped.

It currently answers:

- can the Go backend find `.furrow`?
- are the canonical rows/almanac directories present?
- are required almanac files present?
- do row state files parse?
- is the focused row usable / stale / archived?
- does `furrow almanac validate --json` pass structurally?

It does **not** currently attempt broad shell-era `frw doctor` parity such as:

- install checks
- repo hygiene audits
- command/hook registration parity
- historical Furrow lint passes

Current exit behavior:

- `0` hard checks passed
- `3` hard backend-readiness checks failed
- `5` `.furrow` root not found

### Slice 2 — Pi-enabling backend calls

Next, implement:

- `furrow row init --json`
- `furrow gate status --json`
- `furrow review status --json`

Why second:

- gives Pi enough project and row introspection for a usable authoring workflow
- still avoids deep merge/review orchestration work too early

### Slice 3 — Claude compatibility delegation

After the first two slices are stable, begin delegating:

- `frw` wrapper calls into `furrow`
- `rws` wrapper calls into `furrow row ...`
- `alm` wrapper calls into `furrow almanac ...`
- `sds` wrapper calls into `furrow seeds ...`

Why third:

- Pi can move early
- Claude remains usable for teammates without forcing Claude-first sequencing

### Slice 4 — deeper workflow semantics

Then implement:

- gate execution/evaluation
- review orchestration
- merge/archive semantics
- seed graph behavior

This is where the backend becomes fully load-bearing for both runtimes.

## Narrow-real semantics rule

Avoid two failure modes:

1. **preflight-only surfaces that leave the backend unusably half-real**
2. **fake completeness that claims more lifecycle authority than is actually implemented**

For the minimum slice, prefer **narrow but real** semantics.

Example:

- `furrow row transition --json` should support a tightly bounded mutation path
  if implemented now:
  - active rows only
  - adjacent forward transitions only
  - explicit limitations documented
  - no implication that full gate/review/seed semantics are already complete

What should still be deferred:

- artifact validation
- seed sync
- summary regeneration
- full gate-policy enforcement
- review/archive lifecycle parity

## Sequencing rule

If a capability is needed for:

- shared `.furrow/` semantics
- stable adapter contracts
- teammate compatibility in Claude

then it belongs in the backend queue.

If a capability is only needed for:

- Pi UX richness
- host-native status/widgets
- personal ergonomics

then Pi may implement it earlier as an adapter feature, provided it still calls
through the backend for semantics.

## Derived guidance from the portability research

The portability research is still useful here, but only at the contract level:

- keep the host interface **thin**
- normalize tool/gate/review payloads at the adapter boundary
- preserve host parity through JSON contracts, not prompt duplication
- treat host-specific command registration and lifecycle hooks as adapter work
- avoid committing to the speculative TypeScript interface from the research
  branch until the real Go CLI exists

## Non-goals

This contract intentionally does **not** define:

- the Pi extension API shape
- Claude Code hook file layout
- TUI widgets or slash-command UX
- exact subagent extension composition

Those are adapter concerns and should stay replaceable.
