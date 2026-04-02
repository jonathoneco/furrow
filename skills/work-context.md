# Work Context (Work Layer)

Loaded when a work unit is active. Provides task discovery, state conventions,
and command entry points. Does NOT contain step-specific guidance.

## Commands

| Command | Purpose |
|---------|---------|
| `/work <desc>` | Create or resume a work unit |
| `/work-status` | Show step, deliverable progress, suggested next action |
| `/work-checkpoint` | Save session progress for continuity |
| `/work-reground` | Recover context after break or compaction |
| `/work-review` | Run structured review with specialist agents |
| `/work-archive` | Archive completed work unit |

## Active Task State

Read from `.work/{name}/state.json`:
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

All work units traverse all 7 steps. No steps are skipped. Pre-step evaluation
may determine a step adds no information and record a `prechecked` gate, advancing
without user input (unless `gate_policy: supervised`).

## File Path Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Work unit directory | `.work/{kebab-case}/` | `.work/add-rate-limiting/` |
| Deliverable names | kebab-case | `rate-limiter-middleware` |
| Specialist types | kebab-case | `api-designer` |
| Research files | `research/{topic}.md` | `research/prior-art.md` |
| Spec files | `specs/{component}.md` | `specs/middleware-design.md` |
| Review results | `reviews/{deliverable}.json` | `reviews/rate-limiter-middleware.json` |
| Gate evidence | `gates/{from}-to-{to}.json` | `gates/plan-to-spec.json` |
| Schema fields | snake_case | `step_status`, `created_at` |

## Write Ownership

| File | Writer | Readers |
|------|--------|---------|
| `definition.yaml` | Human or ideation agent | All agents, harness |
| `state.json` | Harness only | All agents (read-only) |
| `plan.json` | Coordinator (write-once) | All agents, harness |
| `summary.md` | Harness + step agent | Next step, reground |
| `reviews/*.json` | Review agent | Harness, human |

## Core Files

Every work unit has: `definition.yaml`, `state.json`, `summary.md`, `reviews/`.
Conditional files created by steps: `plan.json`, `team-plan.md`, `research.md`,
`spec.md`, `gates/`.

## Context Recovery

After compaction or session break, read ONLY:
- `state.json` (step, progress, gates)
- `summary.md` (synthesized context)
- Current step's skill (`skills/{step}.md`)

NEVER re-read: raw research notes, previous handoff prompts, gate evidence, transcripts.

## Platform Plan Mode

CC plan mode (EnterPlanMode) is a tool for planning **within** the current step —
not a replacement for steps or for the harness pipeline.

Correct usage: plan mode coordinates the current step's execution (get clarity
from the user, explore the codebase, design the approach for this step's work).

Incorrect usage: plan mode produces artifacts that span or replace multiple
harness steps (e.g., a single plan that covers spec + decompose + implement).

Each harness step exists to produce a specific artifact with a specific gate.
Plan mode helps you do the current step well. It does not skip steps.

## Step Skill Loading

Each step has a skill at `skills/{step}.md`. Only the current step's skill is active.
At step boundaries, the previous skill is replaced (not appended).

## Component Rationale

Harness components have rationale documented in `_rationale.yaml`.
Run harness-doctor for deletion-readiness audits.

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

Vocabulary:
- `manual`: human reviewed and approved the gate
- `evaluated`: isolated subagent evaluated, trust gradient auto-approved
- `prechecked`: pre-step evaluation determined step not needed

Gate evaluation flow:
1. Phase A (deterministic, shell): `commands/lib/gate-precheck.sh` checks structural criteria
2. Phase B (judgment, isolated subagent): evaluator assesses quality dimensions from `evals/gates/{step}.yaml`
3. Trust gradient (`scripts/evaluate-gate.sh`) applies `gate_policy` to the evaluator's verdict

## Trust Gradient

`gate_policy` in `definition.yaml` controls human oversight of evaluator verdicts
(not whether evaluation happens — evaluation always runs):
- `supervised`: evaluator runs, verdict presented to human for approval (`decided_by: manual`)
- `delegated`: evaluator verdict accepted for most gates (`decided_by: evaluated`); human reviews implement->review and review->archive (`decided_by: manual`)
- `autonomous`: evaluator verdict accepted for all gates (`decided_by: evaluated`)

Pre-step evaluation that determines a step is trivially skippable records `decided_by: prechecked`.

Per-deliverable `gate` field overrides the top-level policy for that deliverable.

## Reference Documents

Detailed protocols live in `references/` (NOT injected — read on demand):
- `references/index.md` — topic-to-file mapping
- `references/gate-protocol.md` — gate evaluation procedures
- `references/review-methodology.md` — Phase A/B review
- `references/eval-dimensions.md` — dimension definitions
- `references/specialist-template.md` — specialist format
- `references/definition-shape.md` — complexity mapping
- `references/deduplication-strategy.md` — context dedup rules
- `references/research-mode.md` — research mode conventions
- `references/work-unit-layout.md` — directory layout conventions
