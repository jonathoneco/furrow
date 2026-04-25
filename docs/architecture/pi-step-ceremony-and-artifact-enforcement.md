# Pi step ceremony and artifact enforcement

Status: Implemented (minimum usable slice)
Authority: Canonical operating-shape spec with bounded transitional implementation notes
Time horizon: Enduring operating shape with current migration notes
Owner: Furrow migration
Related:
- `docs/architecture/workflow-power-preservation.md`
- `docs/architecture/pi-parity-ladder.md`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/dual-runtime-migration-plan.md`
- `.claude/CLAUDE.md`
- `.claude/rules/cli-mediation.md`
- `.claude/rules/step-sequence.md`
- `commands/work.md`
- `commands/checkpoint.md`
- `commands/review.md`
- `references/gate-protocol.md`

## Purpose

Furrow-in-Pi must evolve from a thin command shell into a Pi-hosted
orchestration layer over backend-canonical Furrow state.

The goal of this slice is to preserve Furrow's workflow power, not merely
expose backend row mutations through Pi commands.

This slice is the first concrete step toward restoring:

- a single primary `/work`-like operating loop
- stage-aware ceremony
- create-on-use artifact scaffolding
- supervised checkpoints
- Claude-form blocker semantics
- seeds-visible workflow shaping

## Why this exists

The current Pi Furrow operating layer preserves backend authority and canonical
row bookkeeping for a supported existing-row flow, but it under-preserves
Furrow's workflow power.

Current strengths:
- backend-canonical row state
- structured `--json` CLI outputs
- Pi-side transition/complete flow
- no required direct `state.json` edits in the supported path

Current gaps:
- no primary `/work`-like operating loop
- weak stage ceremony
- weak system-shaped artifact scaffolding
- weak blocker surfacing/enforcement parity
- seeds not visible in the operator flow
- supervised checkpoints not yet restored as the canonical loop
- Pi session behaves more like a task shell than a Furrow orchestrator

This slice addresses those gaps directly.

## Locked requirements

The following are normative:

1. **Workflow power over command parity**
   - preserve Furrow's operating power, not literal Claude command mimicry

2. **Single primary work entrypoint**
   - Pi must converge toward one primary `/work`-like entrypoint concept
   - supporting commands remain secondary

3. **`.furrow/` remains canonical**
   - Pi session state is not the source of truth

4. **Backend remains canonical for mutation**
   - supported workflow mutations go through backend/CLI authority only

5. **Supervised is the default**
   - delegated/autonomous are future-proofing, not the near-term main path

6. **Claude-form blockers are the baseline**
   - if Claude-form Furrow blocks something, Pi should also block it unless
     explicitly revised

7. **Seeds are early-critical**
   - seeds must visibly shape workflow now, not only future backend design

8. **Parallelization is fast follow**
   - not required to complete this slice, but preserved as part of the
     architecture target

## Scope

### In scope

- introduce a primary `/work`-like Pi entrypoint concept
- preserve the fixed 7-step sequence:
  - `ideate -> research -> plan -> spec -> decompose -> implement -> review`
- create current-step artifacts on use
- surface seed state/context in the operator flow
- surface blockers before advancement
- require explicit supervised approval at canonical boundaries
- keep backend canonical for mutation
- preserve durable Furrow artifacts for this implementation slice itself

### Out of scope

- full Pi/Claude UX parity
- full seeds parity across all commands
- tmux/worktree/parallel launch implementation
- full evaluator/gate engine parity
- repo layout promotion as the primary goal
- adapter polish detached from ceremony/enforcement restoration

## Target operator model

## Primary command: `/work`

Pi should converge toward a single primary command conceptually equivalent to
`/work`.

A `/work` turn should be able to:

1. resolve focused/active row
2. require row selection when multiple active rows exist
3. initialize a row if needed through supported Furrow mechanisms
4. reground into canonical current step
5. show:
   - current row
   - current step
   - step status
   - blockers
   - seed state/context
   - required current-step artifacts
6. scaffold the current-step artifact on use if missing
7. orient the session into the active stage
8. pause at supervised checkpoints
9. delegate supported mutations to backend commands only

Secondary commands such as `/status`, `/checkpoint`, `/review`, `/archive`, and
transitional `/furrow-*` commands may remain, but are subordinate to the
primary work entrypoint.

## Session role

The active Pi session should act as a Furrow orchestrator.

Required session behavior:
- stage-aware regrounding
- context routing into the current step
- blocker surfacing before advancement
- explicit supervised approval prompts
- artifact-aware continuation
- seed-aware framing
- later extension toward coordination and parallelization

## Stage model

The canonical stage sequence remains:

1. `ideate`
2. `research`
3. `plan`
4. `spec`
5. `decompose`
6. `implement`
7. `review`

Stage invariants:
- steps are not casually skipped
- progression remains explicit and stageful
- earlier artifacts become later inputs
- artifact existence alone does not imply completion
- Pi should present the active stage as the current operating context

## Artifact model

## Row-init scaffold

Row init should create only canonical scaffold:
- row directory
- `state.json`
- `reviews/`
- seed linkage/creation
- minimal row metadata

## Create-on-use step artifacts

Artifacts should be scaffolded when the step is actually entered/used, not
precreated wholesale.

Examples:
- `ideate` -> `definition.yaml`
- `research` -> research artifact(s)
- `plan` -> planning artifact(s)
- `spec` -> `spec.md`
- `decompose` -> decomposition/team/wave artifact(s)
- `implement` -> implementation tracking artifacts as needed
- `review` -> review artifacts

## Completion semantics

Artifact existence is never sufficient.

Advancement should depend on:
- required structure present
- minimum content present
- validations passing
- gate requirements satisfied
- explicit human approval where required

## Seeds model

Seeds are first-class workflow input.

### At row init

Row creation should:
- require/create/link seed
- fail loudly if seed machinery is unavailable
- preserve current Furrow semantics

### In the operator loop

The operator flow should surface:
- seed id
- seed status
- seed title/intent if available
- mismatches/blockers
- how current stage work relates to seed intent

### At boundaries

Transitions should block where required for:
- missing seed
- closed seed
- invalid linkage
- inconsistent seed state

Even before full seeds parity lands, prompt framing and operator guidance should
already be seed-shaped.

## Supervised checkpoint model

Near-term canonical Furrow-in-Pi is supervised.

Explicit human approval is required at:

1. `ideate -> research`
2. `research -> plan`
3. `plan -> spec`
4. `spec -> decompose`
5. `decompose -> implement`
6. `implement -> review`
7. `review -> archive`

Additional decision points to preserve:
- explicit row selection when multiple active rows exist
- pending user action resolution before advancement
- archive sub-decisions:
  - learnings promotion
  - component promotion
  - TODO extraction/disposition
  - source TODO resolution semantics
- explicit launch decisions for future parallel flows
- consent isolation between separate decisions

## Blocker baseline

**Canonical code registry: `schemas/blocker-taxonomy.yaml`.**

The taxonomy is the single source of truth for every blocker code, category,
severity, message template, remediation hint, confirmation path, and (where
applicable) step scoping. The Go loader (`internal/cli/blocker_envelope.go`
`LoadTaxonomy`) validates the registry on every binary start; the schema is
documented in `schemas/blocker-taxonomy.schema.json`.

This document does **not** duplicate the registry contents. To see the
authoritative list of hard-blocker codes spanning state-mutation, gate,
archive, scaffold, summary, ideation, seed, artifact, definition, and
ownership categories, read `schemas/blocker-taxonomy.yaml` directly or run:

```sh
yq -r '.blockers[] | [.severity, .category, .code] | @tsv' schemas/blocker-taxonomy.yaml
```

Severity is fixed per code in the registry. Codes carry `severity: block`
for hard blockers (host emits exit 2 + stderr), `severity: warn` for
non-blocking notices (host emits exit 0 with stderr), and `severity: info`
for silent informational telemetry. Warnings are explicitly classified, not
silently downgraded blockers.

Known warning examples that may remain warnings initially:
- wave conflict detection
- summary regeneration failure after validation

The following are never sufficient by themselves:
- artifact file exists
- summary file exists
- seed is merely linked
- assistant says `done`
- placeholder-only content
- previous approval reused for a later decision

## Backend implications

The backend must provide machine-readable support for:
- row resolution
- current step/status
- transition validation
- blocker reporting
- checkpoint/completion bookkeeping
- seed state and validation surfaces
- archive preconditions
- next-allowed-action style reporting where possible

Backend semantics remain canonical.

## Pi adapter implications

Pi should own:
- primary `/work` UX
- row selection interaction
- supervised confirmation UI
- stage-aware reground/orientation
- artifact scaffolding UX
- seed visibility in the operator loop
- blocker/warning presentation
- orchestration feel

Pi should not own canonical row/domain semantics.

## Acceptance criteria for this slice

This slice is complete when:

- a primary `/work`-like entrypoint exists in Pi
- `/work` can resolve/select/init rows through supported Furrow mechanisms
- `/work` shows current step, blockers, and seed state
- `/work` scaffolds missing current-step artifacts on use
- supervised boundary advancement requires explicit confirmation
- blocked states prevent advancement
- supported Pi workflow does not require direct `state.json` edits
- implementation work itself leaves durable Furrow artifacts on disk
- docs/roadmap/todos are updated if implementation changes planned reality

## Transitional sequencing note

> Transitional sequencing note: this section explains migration ordering for this
> slice family. It is not the enduring operating-shape definition.

This slice takes priority over adapter promotion as a standalone goal.

The next-value target is not `move .pi/extensions/furrow.ts into adapters/pi/`.
The next-value target is restoring Furrow's supervised staged operating loop in
Pi.

Adapter promotion should remain subordinate to workflow-power preservation.

## Implemented minimum slice notes

> Transitional implementation note: this section records what the current repo
> has landed for this migration slice. It should not silently redefine the
> enduring operating model described above.

The current repository implementation now lands the minimum usable slice this
document called for, plus a deeper boundary-hardening pass:

- Pi exposes a primary `/work` command over backend-canonical row state
- the Go backend now supports row init, focus, seed visibility, blocker
  reporting, current-step artifact scaffolding, and narrow row archive
  preconditions
- `/work` resolves or initializes rows, scaffolds only the active step's
  artifact on use, surfaces seed/blocker/checkpoint state, and requires
  explicit confirmation before supervised advancement
- current-step artifacts now expose backend validation data, and
  `row complete` / `row transition` block on validation failures rather than
  only missing files or incomplete scaffold sentinels
- the plan step now has a scaffoldable/validatable `implementation-plan.md`
  artifact in the same backend contract surface
- coordinated `implement` rows now validate carried decompose artifacts such as
  `plan.json` and `team-plan.md` before allowing the boundary to review
- `review` rows now treat durable review artifacts under `reviews/` as
  first-class current-step artifacts and require recognizable passing review
  evidence before archive can proceed
- the backend now also exposes `furrow review status --json` and
  `furrow review validate --json` read surfaces that normalize review artifacts
  into Phase A / Phase B / overall verdict summaries, synthesized-override
  detection, severity summaries, and follow-up/disposition signals
- `furrow row status` now exposes checkpoint action/evidence, latest gate
  evidence, archive-readiness ceremony summary, and gate history
- backend transitions/archive write durable evidence files under `gates/`
- `/work` can now consume the richer backend `review->archive` checkpoint
  through the existing adapter rather than requiring a parallel lifecycle path

What is still intentionally narrow:

- review artifact validation is semantically richer now, but review execution is
  still artifact-backed rather than a full isolated evaluator-orchestration path
- review execution itself still does not have mature per-deliverable evaluator
  orchestration or full gate-engine parity
- archive semantics inside `/work` now surface follow-up/disposition signals,
  but they still do not perform the full learnings/component/TODO promotion ceremony

## Fast follow after this slice

After this slice, next preserved-power targets include:
- fuller semantic review-quality validation beyond the now-landed implement/review artifact checks
- fuller review execution/evidence surfaces beyond the current pass-backed checkpoint and review-artifact evidence
- archive ceremony expansion from richer readiness evidence into actual promotion/disposition flows
- continued blocker/enforcement taxonomy alignment across Pi and Claude-compatible flows
- seeds parity expansion
- tmux/worktree/session launch surfaces
- within-row and phase-level parallel orchestration
- richer specialist/wave coordination
