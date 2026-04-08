# Step: Implement

## What This Step Does
Execute decomposed work items against specs using specialist agents.

## What This Step Produces
Code mode: code changes in git. Research mode: knowledge artifact in deliverables/.

## Model Default
model_default: sonnet

## Step-Specific Rules
- Each specialist works within its `file_ownership` boundaries.
- All acceptance criteria from `definition.yaml` must be addressed.
- Read `summary.md` for decompose context and wave assignments.

## Shared References
- `skills/shared/red-flags.md` — before any file write
- `skills/shared/git-conventions.md` — before any commit
- `skills/shared/learnings-protocol.md` — when capturing learnings
- `skills/shared/context-isolation.md` — when coordinating agent teams
- `skills/shared/summary-protocol.md` — before completing step

## Specialist Loading (Mandatory)
Before starting implementation, validate that every deliverable's `specialist`
field in `plan.json` references an existing file in `specialists/`. Surface
any missing specialists as errors and STOP — do not proceed with unresolved
specialist assignments.

Before dispatching any agent for a deliverable, you MUST read and load the
specialist template from `specialists/{specialist}.md` as assigned in plan.json.
If the file does not exist, STOP and surface the error. This is a blocking
requirement, not guidance.

Two consumption paths:
- **Solo work**: invoke the specialist as a skill to load domain framing
  into the current agent's context.
- **Multi-agent**: include the specialist template content in the Agent
  tool's `prompt` parameter when dispatching a subagent.

When dispatching a sub-agent, read the specialist's `model_hint` from its
YAML frontmatter and pass it as the Agent tool's `model` parameter.
Resolution order: specialist `model_hint` > step `model_default` > project default (sonnet).

### Step-Level Specialist Modifier
When working with a specialist during implementation, emphasize incremental
correctness, testability, and adherence to the spec over exploratory design.
The specialist's reasoning patterns apply to implementation decisions: which
pattern to use, how to structure the code, what anti-patterns to avoid.

## Agent Dispatch Metadata
- **Dispatch pattern**: Specialist agents per deliverable per wave (plan.json-driven)
- **Agent model**: Per specialist model_hint (see references/model-routing.md)
- **Context to agent**: Specialist template, spec for deliverable, file ownership globs, summary.md, definition.yaml ACs. Curate per specialist Context Requirements.
- **Context excluded**: Other waves' WIP, orchestrator conversation, state.json
- **Returns**: Implemented code/artifacts within file_ownership scope

## Team Planning
Write `team-plan.md` if not created during decompose. Ownership: each
specialist works ONLY within `plan.json` globs (no overlap within a wave).
Unplanned changes are warnings, not blocks — Phase A review audits them.
Wave execution: launch concurrently, inspect outputs between waves.
Skill injection order: code-quality, specialist skills, implement, task.

## Step Mechanics
Transition out: gate record `implement->review` with `pass` required.
No pre-step evaluation — implementation always runs. Post-step gate evaluates
artifact presence, acceptance criteria, and quality dimensions.
Reference: `evals/gates/implement.yaml` post_step, per `skills/shared/gate-evaluator.md`.
Next step expects: all deliverables implemented, status updated in state.json.

## Supervised Transition Protocol
Before requesting a step transition:
1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
2. Present work to user per `skills/shared/summary-protocol.md`.
3. Ask explicitly: "**Ready to advance to review?** Yes / No"
4. Wait for user response. Do NOT proceed without explicit approval.
5. On "yes": call `rws transition <name> pass manual "<evidence summary>"`.
6. On "no": ask what needs to change, address feedback, return to step 2.

## Learnings
Append reusable insights to `.furrow/rows/{name}/learnings.jsonl`.
Read `skills/shared/learnings-protocol.md` for schema and categories.

## Research Mode
When `state.json.mode` is `"research"`:
- Output to `.furrow/rows/{name}/deliverables/` (not git working tree).
- One markdown file per deliverable (kebab-case). Use template from
  `templates/research-{format}.md` per the spec step's chosen format.
- Every factual claim cites a source via `[N]` with `## References`.
- Update `research/sources.md` as sources are discovered.
- Unsourced claims marked `[unverified]` or `[assumption]`.
- Read `references/research-mode.md` for citation format and source types.
- Research mode: no pre-step evaluation — implementation always runs.
