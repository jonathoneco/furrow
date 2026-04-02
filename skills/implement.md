# Step: Implement

## What This Step Does
Execute decomposed work items against specs using specialist agents.

## What This Step Produces
Code mode: code changes in git. Research mode: knowledge artifact in deliverables/.

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

## Specialist Loading
Two consumption paths for specialist templates in `specialists/`:
- **Solo work**: invoke the specialist as a skill to load domain framing
  into the current agent's context.
- **Multi-agent**: include the specialist template content in the Agent
  tool's `prompt` parameter when dispatching a subagent.

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

## Learnings
Append reusable insights to `.work/{name}/learnings.jsonl`.
Read `skills/shared/learnings-protocol.md` for schema and categories.

## Research Mode
When `state.json.mode` is `"research"`:
- Output to `.work/{name}/deliverables/` (not git working tree).
- One markdown file per deliverable (kebab-case). Use template from
  `templates/research-{format}.md` per the spec step's chosen format.
- Every factual claim cites a source via `[N]` with `## References`.
- Update `research/sources.md` as sources are discovered.
- Unsourced claims marked `[unverified]` or `[assumption]`.
- Read `references/research-mode.md` for citation format and source types.
- Research mode: no pre-step evaluation — implementation always runs.
