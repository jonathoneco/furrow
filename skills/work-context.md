---
layer: operator
---
# Work Context (Operator Layer)

Loaded when a row is active. Provides the operator's per-row context: task
discovery, state conventions, and command entry points.

Per-step context is NOT loaded here. It is obtained at runtime via:
```sh
furrow context for-step <step> --target operator --row <row> --json
```
This delegates to D4's context-routing CLI, which filters skills by layer and
assembles the structured bundle for the current step.

## Commands

| Command | Purpose |
|---------|---------|
| `/work <desc>` | Create or resume a row |
| `/work-status` | Show step, deliverable progress, suggested next action |
| `/work-checkpoint` | Save session progress for continuity |
| `/work-reground` | Recover context after break or compaction |
| `/work-review` | Run structured review with specialist agents |
| `/work-archive` | Archive completed row |

## Active Task State

Read from `.furrow/rows/{name}/state.json`:
- `step`: current step in the 7-step sequence
- `step_status`: `not_started` | `in_progress` | `completed` | `blocked`
- `deliverables`: map of deliverable name to status/wave/corrections
- `gates[]`: append-only audit trail of step transitions
- `mode`: `code` | `research`
- `force_stop_at`: step name or null

## Step Sequence

```
ideate -> research -> plan -> spec -> decompose -> implement -> review
```

All rows traverse all 7 steps. No steps are skipped. Pre-step evaluation
may determine a step adds no information and record a `prechecked` gate, advancing
without user input (unless `gate_policy: supervised`).

## Operator Responsibilities

The operator is the only layer that:
- Addresses the user directly
- Calls `rws`/`alm`/`sds` CLI commands
- Reads and mutates row state
- Spawns and primes phase drivers
- Presents phase results per `skills/shared/presentation-protocol.md` (D6)
- Requests step transitions after user approval

See `skills/shared/layer-protocol.md` for the full 3-layer boundary contract.

## Driver Dispatch

For each step, the operator spawns a phase driver and primes it:

1. Load driver context: `furrow context for-step <step> --target driver --json`
2. Persist driver handoff: `furrow handoff render --target driver:{step} --write`
3. Spawn driver (runtime-specific — see `commands/work.md` for Claude and Pi branches)
4. Prime driver with context bundle via `message` primitive
5. Receive phase result (EOS-report) from driver
6. Present to user; request `rws transition`

## File Path Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Row directory | `.furrow/rows/{kebab-case}/` | `.furrow/rows/add-rate-limiting/` |
| Deliverable names | kebab-case | `rate-limiter-middleware` |
| Specialist types | kebab-case | `api-designer` |
| Research files | `research/{topic}.md` | `research/prior-art.md` |
| Spec files | `specs/{component}.md` | `specs/middleware-design.md` |
| Review results | `reviews/{deliverable}.json` | `reviews/rate-limiter-middleware.json` |
| Gate evidence | `gates/{from}-to-{to}.json` | `gates/plan-to-spec.json` |
| Handoff artifacts | `handoffs/{step}-to-{target}.md` | `handoffs/plan-to-driver.md` |
| Schema fields | snake_case | `step_status`, `created_at` |

## Write Ownership

| File | Writer | Readers |
|------|--------|---------|
| `definition.yaml` | Human or ideation agent | All agents, Furrow |
| `state.json` | Harness only | All agents (read-only) |
| `plan.json` | Coordinator (write-once) | All agents, Furrow |
| `summary.md` | Harness + step agent | Next step, reground |
| `reviews/*.json` | Review agent | Harness, human |
| `handoffs/*.md` | Furrow CLI (`--write`) | Drivers, engines |

## Core Files

Every row has: `definition.yaml`, `state.json`, `summary.md`, `reviews/`.
Conditional files created by steps: `plan.json`, `research.md`,
`spec.md`, `gates/`, `handoffs/`.

Note: `team-plan.md` is retired. Engine teams are composed at dispatch-time
by drivers, not at planning-time by the operator. See `skills/shared/layer-protocol.md`.

## Context Recovery

After compaction or session break, read ONLY:
- `state.json` (step, progress, gates)
- `summary.md` (synthesized context)
- Reload operator bundle: `furrow context for-step <step> --target operator --json`

NEVER re-read: raw research notes, previous handoff prompts, gate evidence, transcripts.

## Platform Plan Mode

CC plan mode (EnterPlanMode) is a tool for planning **within** the current step —
not a replacement for steps or for the Furrow pipeline.

Correct usage: plan mode coordinates the current step's execution (get clarity
from the user, explore the codebase, design the approach for this step's work).

Incorrect usage: plan mode produces artifacts that span or replace multiple
Furrow steps (e.g., a single plan that covers spec + decompose + implement).

## Step Skill Loading

Each step has a driver brief at `skills/{step}.md`. Only the current step's brief
is injected into the driver's context. At step boundaries, the previous brief is
replaced (not appended). The operator's per-step skill is filtered from the bundle
by `--target operator`.

## Component Rationale

Harness components have rationale documented in `.furrow/almanac/rationale.yaml`.
Run furrow-doctor for deletion-readiness audits.

## Summary Format

`summary.md` is regenerated at every step boundary. Required sections:
Task, Current State, Artifact Paths, Settled Decisions, Context Budget.
Agent-written sections: Key Findings, Open Questions, Recommendations.

## Gate Records

Step transitions produce gate records in `state.json.gates[]`:
- `boundary`: `"{from}->{to}"`
- `outcome`: `pass` | `fail` | `conditional`
- `decided_by`: `manual` | `evaluated` | `prechecked`
- Append-only — never modified after creation.

Gate evaluation flow:
1. Phase A (deterministic, shell): `rws gate-check` checks structural criteria
2. Phase B (judgment, isolated subagent): evaluator assesses quality dimensions from `evals/gates/{step}.yaml`
3. Trust gradient (`frw evaluate-gate`) applies `gate_policy` to the evaluator's verdict

## Trust Gradient

`gate_policy` in `definition.yaml` controls human oversight of evaluator verdicts:
- `supervised`: evaluator runs, verdict presented to human for approval (`decided_by: manual`)
- `delegated`: evaluator verdict accepted for most gates (`decided_by: evaluated`)
- `autonomous`: evaluator verdict accepted for all gates (`decided_by: evaluated`)

## Reference Documents

Detailed protocols live in `references/` (NOT injected — read on demand):
- `references/index.md` — topic-to-file mapping
- `references/gate-protocol.md` — gate evaluation procedures
- `references/review-methodology.md` — Phase A/B review
- `references/eval-dimensions.md` — dimension definitions
- `references/specialist-template.md` — specialist format
- `references/definition-shape.md` — complexity mapping
- `references/research-mode.md` — research mode conventions
- `references/row-layout.md` — directory layout conventions
