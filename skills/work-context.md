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

All work units traverse all 7 steps. No steps are skipped. Auto-advance may
resolve trivially-completing steps without user input (unless `gate_policy: supervised`).

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
- `decided_by`: `human` | `evaluator` | `auto-advance`
- Append-only — never modified after creation.

## Trust Gradient

`gate_policy` in `definition.yaml` controls the trust level:
- `supervised`: human approves every gate
- `delegated`: evaluator judges most gates; human approves critical transitions
- `autonomous`: evaluator judges all gates

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
