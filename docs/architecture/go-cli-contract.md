# Go CLI Contract

Status: Active
Authority: Canonical contract
Time horizon: Enduring contract with bounded transitional implementation notes

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

The canonical binary is `furrow` for implemented backend behavior. Legacy
wrappers (`frw`, `rws`, `alm`, `sds`) are preserved only as compatibility
aliases or temporary shell-semantic holdouts where no live Go path exists.

### 1. `furrow row`

Owns row lifecycle and per-row state.

Representative subcommands:

- `furrow row init <name>`
- `furrow row status [<name>]`
- `furrow row transition <name> --step <step>`
- `furrow row complete <name>`
- `furrow row checkpoint <name>` (reserved; not implemented)
- `furrow row archive <name>`
- `furrow row summary <name> --regenerate` (reserved; not implemented)
- `furrow row validate <name>` (reserved; not implemented)
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

Current compatibility-collapse status (2026-04-29):

- `alm validate` with no path, plus `alm validate --json`, delegates to
  `furrow almanac validate`. `alm validate <path>` remains shell-specific
  because the Go command validates the full live almanac and does not expose a
  targeted todos/observations file contract.
- `rws status`, `rws list`, `rws focus`, and `rws repair-deliverables` delegate
  to `furrow row status`, `furrow row list`, `furrow row focus`, and
  `furrow row repair-deliverables`. The `rws list` shim preserves the legacy
  no-argument default by adding `--active`.
- `rws load-step` is retired. Runtime context loading is `furrow context
  for-step`; rendered handoffs are `furrow handoff render`.
- `rws transition`, `rws complete-step`, `rws archive`, and `rws init` are not
  compatibility wrappers yet. Their shell implementations still carry
  shell-semantic behavior around gate verdicts, summary mutation, seed/focus
  side effects, or worktree compatibility.

## Transitional migration sequencing

> Transitional sequencing note: this section is about migration order and current
> cutover strategy. It is not itself the enduring contract definition.

To let Pi come online early without breaking teammate compatibility in Claude
Code, implement the Go surface in this order.

### Slice 1 — first shared backend cut

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

> Transitional implementation note: this section records the current repo slice
> so adapters and reviews can operate against reality. It is not the enduring
> definition of the full contract surface.

The current repository implementation lands a **usable first cut** for the five
commands above, and now also includes the narrow row-init/focus/scaffold support
needed for Pi's supervised `/work` loop. This section is the contract truth for
the implemented slice; broader command-group descriptions elsewhere in this
document remain directional for later phases.

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

- exists in the first shared backend cut as the early adapter-facing browse surface
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
- latest gate summary plus transition history
- canonical artifact paths
- current-step artifact expectations plus per-artifact validation results
- required continuation inputs from prior steps, with missing/invalid inputs
  surfaced as blockers
- a minimal artifact contract split into required current-step outputs,
  optional outputs, required continuation inputs, retired artifacts, and
  completion/archive checks
- seed state surface
- blocker list with a backend-owned taxonomy shape
- checkpoint / next-boundary surface, including action and evidence summary
- latest gate evidence summary when a durable evidence file exists
- archive-readiness ceremony summary when the current boundary is `review->archive`
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
semantics. The current implementation now additionally enforces a narrow blocker
baseline before mutation:

- `step_status=completed` required before advancement
- current-step required artifact presence
- incomplete scaffold-template detection
- backend structural validation for the currently supported step artifacts
- required continuation-input validation for prior-step artifacts needed to
  resume honestly at the target checkpoint
- linked-seed validity / sync when a seed is present
- durable checkpoint evidence written under `gates/`

It still does **not** enforce:

- evaluator-grade semantic validation or full gate-engine parity
- full gate-policy enforcement beyond adapter-driven supervised confirmation
- summary regeneration
- conditional/fail outcomes
- broader review orchestration behavior
- richer merge/archive ceremony beyond the narrow archive checkpoint path

> **Reconciliation note (2026-04-25, row `blocker-taxonomy-foundation`)**:
> there is currently scope ambiguity between the not-enforced list above and
> `pi-step-ceremony-and-artifact-enforcement.md:374-388`, which describes
> per-step artifact validation, decompose-artifact validation, and
> review-artifact validation as enforced preconditions. The boundary between
> "narrow blocker baseline" (this contract) and "per-step artifact
> validation" (Pi-step-ceremony doc) is deferred to TODO
> `artifact-validation-per-step-schema` (`.furrow/almanac/todos.yaml`),
> which will define `schemas/step-artifact-requirements.yaml` and bind both
> documents to a single authoritative spec. Until that TODO closes, treat
> per-step artifact validation as in-scope for the backend and
> `pi-step-ceremony-and-artifact-enforcement.md:374-388` as the operative
> description.

> **Update (2026-04-29, row `artifact-validation-and-continuation`)**:
> the current backend now exposes and enforces a minimal artifact contract for
> current-step outputs and continuation inputs through `furrow row status`,
> `complete`, `transition`, and `archive`. The standalone
> `schemas/step-artifact-requirements.yaml` file and prompt/skill binding work
> remain backlog; runtime truth is the backend behavior described in this
> section.

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
- blocks if required current-step artifacts or required continuation-input
  artifacts are missing, still marked as incomplete templates, or fail backend
  artifact validation
- blocks on the same pending-action and linked-seed blockers used by row status
  and transition
- marks `step_status=completed`
- marks object-shaped deliverables as `status=completed`
- preserves unknown fields
- uses atomic writes
- idempotent if the row is already complete for this bookkeeping shape

What it does **not** imply:

- review approval semantics
- full archive ceremony semantics
- gate evaluation/orchestration parity
- summary regeneration
- generic mutation/patch support

Current exit behavior:

- `0` success
- `1` usage error
- `2` blocked row (for example archived)
- `3` invalid row state / invalid row JSON
- `4` write failure
- `5` row or `.furrow` root not found

#### `furrow row archive --json`

Current behavior is narrow but real:

- active rows only
- explicit row argument required
- requires:
  - `step=review`
  - `step_status=completed`
  - no current blockers from the shared blocker taxonomy
  - an existing passing `->review` gate record
  - passing current-step review artifacts under `reviews/`
  - passing required continuation inputs from prior steps
- writes `archived_at` and `updated_at`
- appends a narrow `review->archive` gate record to `gates[]`
- writes a durable archive checkpoint evidence file under `gates/`
- returns archive-readiness evidence summarizing review artifacts, source-link context, and learnings presence

What it does **not** imply:

- full learnings/component/TODO promotion mutations
- broader review orchestration or disposition tracking
- summary regeneration
- seed-graph archival follow-up semantics

Current exit behavior:

- `0` success
- `1` usage error
- `2` blocked row / unmet archive precondition
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

#### `furrow row init --json`

Current behavior is intentionally narrow but real:

- creates the row directory plus `state.json` and `reviews/`
- resolves defaults from `.claude/furrow.yaml` when available
- creates or links a seed and aligns it to the current ideation step
- can link/backfill canonical `source_todos` seed references when needed, while
  tolerating historical `source_todo` state during migration reads
- reads the live canonical almanac planning file through the same tolerant YAML path used by almanac validation, so supported row init stays aligned with repo truth
- does **not** precreate downstream step artifacts

#### `furrow row focus --json`

Current behavior:

- reads the current focused row
- sets focus to an active row
- clears focus with `--clear`
- blocks focusing archived rows

#### `furrow row scaffold --json`

Current behavior:

- only scaffolds the **current** step's scaffoldable artifacts
- currently supports narrow templates for:
  - `ideate` -> `definition.yaml`
  - `research` -> `research.md`
  - `plan` -> `implementation-plan.md`
  - `spec` -> `spec.md`
  - `decompose` -> `plan.json`
- returns refreshed artifact validation data for the current step
- marks templates with an explicit incomplete-scaffold sentinel so artifact
  existence alone never satisfies completion or transition checks
- does not precreate downstream artifacts

### Slice 2 — work-loop boundary hardening

> Transitional implementation note: this subsection describes the current repo's
> migration progress inside the broader contract trajectory.

This slice is now **more fully landed, but still intentionally partial** in the current repo:

- richer per-step artifact validation beyond incomplete-scaffold detection
- `row init` source-link handling aligned with the live canonical almanac document shape
- stronger checkpoint / gate evidence surfaces in `furrow row status`
- shared blocker taxonomy suitable for both Pi and future Claude-compatible flows
- coordinated `implement` rows now validate the carried decompose plan artifact (`plan.json`) at the boundary to review
- `review` rows now validate durable review artifacts under `reviews/` rather than relying only on a prior `->review` gate record
- review artifacts are now normalized semantically enough for backend-owned `furrow review status --json` and `furrow review validate --json` surfaces, including Phase A / Phase B verdict summaries, synthesized-override detection, severity summaries, and follow-up/disposition signals
- archive-readiness evidence now includes latest gate evidence plus review-summary / follow-up / source-link / learnings surfaces inside the same operating loop
- `furrow row archive --json` as a real backend archive boundary surface with richer evidence payloads

Representative follow-on commands still likely include:

- `furrow gate status --json`
- fuller `furrow review run --json` / review-execution orchestration

Remaining work in this slice:

- deeper review execution/evaluator orchestration beyond the now-landed artifact-backed semantic review normalization and status/validate surfaces
- fuller archive ceremony and disposition mutations (learnings/components/follow-up extraction), not just backend-derived follow-up signals in archive evidence
- dual-host validation once the boundary contract settles further

### Slice 3 — Claude compatibility delegation

After the first two slices are stable, delegate only where live Go parity
exists:

- `frw validate-definition` calls into `furrow validate definition`
- `rws status`, `rws list`, `rws focus`, and `rws repair-deliverables` call into
  `furrow row ...`
- `alm validate` remains shell-owned until its path-specific validation behavior
  is either ported or retired
- `sds` remains shell-owned because `furrow seeds` is reserved

Why third:

- Pi can move early
- Claude remains usable for teammates without forcing Claude-first sequencing
- shell-semantic behavior stays in shell until parity is proven by loaded
  runtime paths

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

For early contract slices, prefer **narrow but real** semantics.

Example:

- `furrow row transition --json` should support a tightly bounded mutation path
  if implemented now:
  - active rows only
  - adjacent forward transitions only
  - explicit limitations documented
  - no implication that full gate/review/seed semantics are already complete

What should still be deferred:

- full semantic artifact validation across every step all at once
- seed-backed planning/almanac semantics beyond the current row-linked slice
- summary regeneration
- broader merge/parallel orchestration behavior
- complete review/archive lifecycle parity in one jump

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
