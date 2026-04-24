# Documentation cleanup pass proposal

Status: Proposed
Authority: Transitional / migration
Time horizon: Transitional
Owner: Furrow migration
Related:
- `docs/architecture/documentation-authority-taxonomy.md`
- `docs/architecture/migration-stance.md`
- `docs/architecture/dual-runtime-migration-plan.md`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/pi-parity-ladder.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/handoffs/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/handoffs/post-review-pi-step-ceremony-and-artifact-enforcement.md`

## Purpose

Make the current docs easier to trust by reducing blending between:

- canonical infrastructure/design docs
- transitional migration docs
- planning docs
- historical/execution docs

This is a cleanup proposal, not a hidden architecture rewrite.

## Cleanup goals

1. make authority class obvious per document
2. remove row-local migration residue from canonical docs
3. keep migration strategy explicit without letting it masquerade as timeless architecture
4. preserve historical execution truth without treating it as canonical system definition
5. reduce the amount of mental translation required to answer: “is this the enduring design, a migration tactic, a plan, or a row artifact?”

## Recommended authority classification for current docs

### Canonical / enduring (keep as canonical)

- `README.md`
- `docs/architecture/workflow-power-preservation.md`
- `docs/architecture/core-adapter-boundary.md`
- `docs/architecture/pi-almanac-operating-model.md`
- `docs/architecture/pi-native-capability-leverage.md`
- most of `references/`

Action:
- keep these focused on enduring truth
- trim temporary migration residue when it accumulates

### Transitional / migration (keep as transitional)

- `docs/architecture/dual-runtime-migration-plan.md`
- `docs/architecture/migration-stance.md`
- `docs/architecture/host-strategy-matrix.md`
- parts of `docs/architecture/pi-parity-ladder.md`

Action:
- make transitional status explicit
- allow temporary sequencing/cutover material here instead of leaking it into canonical docs

### Canonical docs with mixed current-state residue (tighten)

- `docs/architecture/go-cli-contract.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/architecture/pi-parity-ladder.md`

Action:
- keep the enduring contract/design content
- confine current-implemented-status material to bounded sections like:
  - `Current implemented status`
  - `Current repo notes`
  - `Temporary migration note`
- do not let those sections spread through the whole doc tone

### Historical / execution (preserve, but do not treat as canonical)

- `.furrow/rows/*`
- `docs/handoffs/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/handoffs/post-review-pi-step-ceremony-and-artifact-enforcement.md`

Action:
- preserve both the original durable slice spec and the post-review handoff
- keep them clearly identified as execution/history docs
- avoid copying their row-local conclusions into canonical architecture docs unless those conclusions are promoted deliberately

### Planning (keep as planning)

- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml`

Action:
- use these for sequencing and prioritization only
- avoid letting them become the primary authority for architecture semantics

## Concrete cleanup pass

### Pass 1 — add authority framing to key docs

Add a short authority line or equivalent to major docs.

Priority files:
- `README.md`
- `docs/architecture/dual-runtime-migration-plan.md`
- `docs/architecture/migration-stance.md`
- `docs/architecture/go-cli-contract.md`
- `docs/architecture/pi-parity-ladder.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/handoffs/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/handoffs/post-review-pi-step-ceremony-and-artifact-enforcement.md`

Suggested shape:
- Status
- Authority
- Time horizon

### Pass 2 — tighten mixed canonical docs

#### `docs/architecture/go-cli-contract.md`

Problem:
- mixes enduring contract shape, current implemented slice notes, and migration sequencing in one long document

Proposal:
- keep the command-group and contract sections as canonical-facing contract material
- keep current implemented behavior in clearly bounded `Current implemented slice` sections
- move any broader migration stance language out to `migration-stance.md` or `dual-runtime-migration-plan.md`

#### `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`

Problem:
- serves as both enduring operating-shape doc and implemented-slice status note

Proposal:
- keep purpose, stage/ceremony model, artifact philosophy, blocker philosophy, and acceptance shape as the canonical operating-spec part
- keep `Implemented minimum slice notes` bounded and clearly transitional/historical in tone
- avoid letting later slice-by-slice residue accumulate here indefinitely

#### `docs/architecture/pi-parity-ladder.md`

Problem:
- useful doc, but naturally blends migration progress with longer-lived parity framing

Proposal:
- treat it as transitional/migration authority, not pure canonical architecture
- explicitly say that its purpose is migration-state framing

### Pass 3 — protect handoffs from becoming canonical by accident

#### `docs/handoffs/pi-step-ceremony-and-artifact-enforcement.md`
- keep as the original durable slice spec / implementation handoff

#### `docs/handoffs/post-review-pi-step-ceremony-and-artifact-enforcement.md`
- keep as post-review execution truth

Proposal:
- do not collapse them back into one file
- do not let later architecture edits silently absorb row-local conclusions from them without an explicit promotion step

### Pass 4 — reduce architecture docs carrying row-local next-step language

Problem:
- architecture docs can slowly accumulate “the next session should…” language

Proposal:
- next-session guidance should prefer:
  - row handoff docs
  - post-review handoffs
  - roadmap/todos
- architecture docs may describe likely sequencing, but should not become session-operator instructions unless they are explicitly transitional migration docs

### Pass 5 — planning docs should reference, not redefine

Problem:
- roadmap/todos can start restating architecture in their own language

Proposal:
- roadmap/todos should point to architecture docs for meaning
- they should focus on:
  - sequencing
  - status
  - scope boundaries
  - successor work
- when wording drifts, prefer tightening it rather than expanding their semantic burden

## Suggested execution order

1. land `documentation-authority-taxonomy.md`
2. add authority framing to major docs
3. tighten the most mixed docs:
   - `go-cli-contract.md`
   - `pi-step-ceremony-and-artifact-enforcement.md`
   - `pi-parity-ladder.md`
4. preserve paired handoff docs as distinct execution artifacts
5. do a smaller follow-up pass on roadmap/todos wording where it still sounds like canonical architecture

## Non-goals

This cleanup pass should not:
- rewrite the migration architecture from scratch
- collapse all migration docs into architecture docs
- remove useful current-state notes entirely
- turn row artifacts into disposable notes
- force every file into a new folder immediately

## Success criteria

This pass is successful when a reader can quickly answer:

- is this enduring system truth?
- is this a migration tactic?
- is this a planning/sequencing artifact?
- is this row-local execution history?

without having to infer it from tone alone.

## Bottom line

The goal is not less documentation.
The goal is clearer authority boundaries between:

- canonical
- transitional
- planning
- historical/execution

That should make Furrow’s docs easier to trust during the rest of the migration.
