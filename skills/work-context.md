---
layer: operator
---
# Work Context (Operator Layer)

Loaded only while a row is active. Keep this as the operator's compact contract:
row state, layer duties, context routing, and truth gates. Step-specific details
belong in `skills/{step}.md` or lazy references.

## Commands

| Command | Purpose |
|---------|---------|
| `/work <desc>` | Create or resume a row |
| `/work-status` | Show progress and next action |
| `/work-checkpoint` | Save continuity state |
| `/work-reground` | Recover context after break or compaction |
| `/work-review` | Run structured review |
| `/work-archive` | Archive completed row |

## Core Contract

- Rows live in `.furrow/rows/{kebab-case}/`.
- Core files: `definition.yaml`, `state.json`, `summary.md`, `reviews/`.
- Conditional files: `research.md` or `research/`, `spec.md` or `specs/`,
  `plan.json`, `gates/`, `handoffs/`, completion-evidence artifacts.
- `state.json` is harness-owned. Read it; mutate state only through CLI.
- Sequence is fixed: `ideate -> research -> plan -> spec -> decompose -> implement -> review`.
- No step is skipped; prechecked gates still leave an audit record.
- `team-plan.md` is retired. Drivers compose engines at dispatch time.

## Operator Duties

- Address the user directly and present phase results.
- Load the current bundle with `furrow context for-step <step> --target operator --row <row> --json`.
- Spawn and prime phase drivers with only their current-step bundle.
- Request user decisions for scope, claims, irreversible state, or unresolved blockers.
- Transition steps only after required evidence and approval are present.
- Preserve real ask, evidence, context bundle, layer boundaries, handoff isolation,
  checkpoint continuity, and archive readiness.

## Layer Boundary

- Operator: user-facing orchestration, row state, transitions, presentation.
- Driver: one phase contract, step artifacts, EOS-report to operator.
- Engine: isolated execution or review; no Furrow state mutation.
- Full boundary rules: `skills/shared/layer-protocol.md`.

## Driver Dispatch

1. Load driver bundle: `furrow context for-step <step> --target driver --row <row> --json`.
2. Persist handoff when needed: `furrow handoff render --target driver:{step} --write`.
3. Spawn the driver with the bundle and current row objective.
4. Receive the driver's EOS-report.
5. Present the result per `skills/shared/presentation-protocol.md`.
6. Complete or transition with the supported Furrow/compatibility CLI.

## Context Recovery

After compaction or session break, read only:
- `state.json` for step, progress, gates, mode, force stop, and deliverables.
- `summary.md` for synthesized context.
- Current operator bundle from `furrow context for-step`.

Do not reload raw research notes, old handoffs, gate evidence, or transcripts
unless the current decision specifically requires them.

## Gate Records

Step transitions append to `state.json.gates[]`:
- `boundary`: `"{from}->{to}"`
- `outcome`: `pass` | `fail` | `conditional`
- `decided_by`: `manual` | `evaluated` | `prechecked`

Gate flow is deterministic checks, isolated evaluator when configured, then
`gate_policy` trust handling. Procedures are lazy references:
- `references/gate-protocol.md`
- `skills/shared/gate-evaluator.md`
- `skills/shared/eval-protocol.md`

## Lazy References

- Row layout: `references/row-layout.md`
- Definition schema: `references/definition-shape.md`
- Review method: `references/review-methodology.md`
- Research mode: `references/research-mode.md`
- Specialist format: `references/specialist-template.md`
- Rationale inventory: `.furrow/almanac/rationale.yaml`
