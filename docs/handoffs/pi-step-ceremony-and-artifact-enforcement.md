# Handoff: pi-step-ceremony-and-artifact-enforcement

## Goal

Implement the next Furrow migration slice so Furrow-in-Pi moves from a thin
command shell toward a workflow-power-preserving orchestration host.

This slice is **not** just adapter promotion. The target is to restore the
supervised staged operating loop in Pi:

- one primary `/work`-like entrypoint concept
- stage-aware ceremony
- create-on-use artifact scaffolding
- supervised checkpoints
- Claude-form blocker baseline
- seed-visible workflow shaping
- backend-canonical mutations only

## Working directory

`/home/jonco/src/furrow`

## Authority files to read first

### Architecture / planning
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/architecture/workflow-power-preservation.md`
- `docs/architecture/pi-parity-ladder.md`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/dual-runtime-migration-plan.md`
- `docs/architecture/host-strategy-matrix.md`
- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml`

### Claude-form Furrow behavior
- `.claude/CLAUDE.md`
- `.claude/rules/cli-mediation.md`
- `.claude/rules/step-sequence.md`
- `commands/work.md`
- `commands/checkpoint.md`
- `commands/review.md`
- `commands/archive.md`
- `commands/status.md`
- `commands/reground.md`
- `references/gate-protocol.md`
- `references/row-layout.md`
- `references/definition-shape.md`
- `references/furrow-commands.md`

### Step skills / ceremony
- `skills/work-context.md`
- `skills/ideate.md`
- `skills/research.md`
- `skills/plan.md`
- `skills/spec.md`
- `skills/decompose.md`
- `skills/implement.md`
- `skills/review.md`
- `skills/orchestrator.md`

### Current Pi / backend implementation
- `.pi/extensions/furrow.ts`
- `internal/cli/app.go`
- `internal/cli/row.go`
- `internal/cli/almanac.go`
- `internal/cli/doctor.go`
- `internal/cli/util.go`
- `internal/cli/app_test.go`

## Non-negotiable constraints

1. `.furrow/` remains canonical.
2. Do not move canonical lifecycle/domain semantics into TypeScript.
3. All supported workflow mutations go through backend/CLI authority.
4. Prefer hard blockers and loud failure where Claude-form Furrow blocks.
5. `supervised` is the default near-term trust mode.
6. Seeds must be visible in the operator flow now, not only in backend plumbing.
7. Artifact existence is never completion.
8. If a needed backend capability is missing, either implement the minimal
   backend support or stop and report the gap clearly.

## Implementation target

Build the next usable Furrow-in-Pi slice around a primary `/work`-like entrypoint.

Minimum expectations:

1. **Primary `/work`-like Pi entrypoint**
   - resolves focused/active row
   - requires explicit choice when multiple active rows exist
   - can initialize a row through supported Furrow mechanisms if needed
   - regrounds into the current stage
   - shows current step, blockers, seed state, and required current-step artifacts
   - scaffolds the active step artifact on use if missing
   - pauses at supervised checkpoints
   - uses backend authority for supported mutations

2. **Create-on-use current-step artifact scaffolding**
   - scaffold only the active step's artifact
   - do not precreate downstream artifacts
   - make scaffolds obviously incomplete templates

3. **Blocker surfacing and supervised confirmation**
   - blocked states prevent advancement
   - supervised boundaries require explicit confirmation
   - do not silently continue past a boundary

4. **Seed-visible operator flow**
   - show seed id/status/title-or-intent when available
   - make missing/closed/inconsistent seed state obvious

5. **Minimal backend support only where necessary**
   - keep backend additions narrow and machine-readable
   - do not fake missing lifecycle semantics in Pi

## Durable artifacts for the implementation session

Use a dedicated row for this work:

- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/`

If a supported row-init/focus path exists, use it.
If it does not, stop and report that gap instead of bypassing canonical state.

Maintain these artifacts during the session:

- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/implementation-plan.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/execution-progress.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md`
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md`

## Validation requirements

At minimum, validate:

- `go test ./...`
- backend commands still work for affected flows
- Pi command(s) work in headless mode when possible
- real blocker cases are surfaced
- supervised confirmation path behaves correctly
- create-on-use scaffolding occurs only for the active step
- no supported flow requires direct `state.json` editing

## If docs/plans drift

If implementation changes planned reality, update:

- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/architecture/pi-parity-ladder.md` if parity level changes
- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml`

## What not to optimize for

- adapter layout cleanup as the main value
- equal Pi/Claude UX
- speculative parity
- polish without enforcement

## What to optimize for

- supervised staged operating loop
- explicit blockers
- artifact discipline
- seed-visible work guidance
- backend-canonical semantics
- Pi feeling more like a Furrow orchestrator than a bag of admin commands

## End-of-session output

Provide:

1. summary of changes
2. exact files changed
3. validation evidence
4. current limitations
5. recommended next slice
