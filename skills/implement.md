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
Before dispatching any agent for a deliverable, you MUST attempt to load the
specialist template from `specialists/{specialist}.md` as assigned in plan.json.
If the file does not exist, warn on stderr and proceed without it — this is
degraded mode, not normal operation. Note the missing specialist in the
deliverable's review evidence so the review step can flag it.

### Step-Level Specialist Modifier
When working with a specialist during implementation, emphasize incremental
correctness, testability, and adherence to the spec over exploratory design.
The specialist's reasoning patterns apply to implementation decisions: which
pattern to use, how to structure the code, what anti-patterns to avoid.

## Dispatch Decision Tree

Read `plan.json`. Count deliverables and inspect their assignments. Follow the
first matching branch — do not skip ahead.

```
plan.json has 1 deliverable?
  YES → SOLO execution.
         Load specialist as a skill into current agent context.
         Execute the deliverable directly.

plan.json has >1 deliverable, ALL share the same specialist, ALL in wave 1?
  YES → SOLO execution with specialist skill loaded.
         Execute deliverables sequentially in the current agent.
         NOTE: Branch 2 applies only when all deliverables are in wave 1.
         Any plan with multiple waves falls through to branch 3 regardless
         of specialist diversity.

plan.json has >1 deliverable with DIFFERENT specialists OR >1 wave?
  YES → MULTI-AGENT dispatch.
         Follow the Dispatch Checklist below.
```

No other paths exist. Every plan.json falls into exactly one branch.

## Agent() Tool Call Example

When dispatching a sub-agent for a deliverable, use this pattern. Every field
shown is required — omitting any field is a dispatch error.

> **Note**: The block below is pseudocode showing prompt composition structure,
> not literal tool syntax. Substitute `{placeholders}` with actual values before
> invoking the Agent tool.

```
Agent(
  prompt="""
You are a {specialist_name} implementing the "{deliverable_name}" deliverable.

## Specialist Domain
{contents of specialists/{specialist}.md — full markdown body}

## Your Assignment
Deliverable: {deliverable_name}
File ownership (you may ONLY write to these paths):
{one glob pattern per line from plan.json assignments[deliverable].file_ownership}

## Acceptance Criteria (from definition.yaml)
{paste the acceptance_criteria entries for this deliverable}

## Context
{summary.md contents — Key Findings and Recommendations sections}
{curated files per specialist Context Requirements: Required items always, Helpful items when relevant}

## Rules
- Write ONLY within your file_ownership globs. Any write outside is a violation.
- Read skills/shared/red-flags.md before any file write.
- Read skills/shared/git-conventions.md before any commit.
- Do not read or write state.json.
- Do not reference other deliverables or other agents' work.
""",
  model="{resolved_model}"
)
```

**Model resolution order** (use first non-empty value):
1. Specialist template YAML frontmatter `model_hint`
2. Step `model_default` (sonnet)
3. Project default (sonnet)

Valid model values: `opus`, `sonnet`, `haiku`.

## Dispatch Checklist

Execute these steps in exact order. Do not skip or reorder.

1. **Read plan.json.** Parse `waves` array. Store wave count and all assignments.

2. **Validate wave ordering.** Waves must execute in numeric order (wave 1, then
   wave 2, etc.). Deliverables within a wave execute concurrently.

3. **For each wave** (in order, wave 1 first):

   a. **For each deliverable in this wave** (concurrently):
      - Read `specialists/{specialist}.md` for this deliverable's assigned specialist.
      - If the specialist file is missing: warn on stderr, record in review evidence,
        proceed without specialist template (degraded mode).
      - Read the specialist's `model_hint` from YAML frontmatter.
      - Curate context per the specialist's Context Requirements section:
        Required items always included, Helpful items when relevant, Exclude items omitted.
      - Build the Agent prompt using the Agent() example above.
      - Spawn the agent. Pass `model` using the model resolution order.

   b. **Wait for all agents in this wave to complete.**

   c. **Run Wave Inspection Protocol** (below) before advancing to the next wave.

4. **After all waves complete:** verify every deliverable in plan.json has been
   addressed. Update deliverable statuses via `rws complete-deliverable`.

## Wave Inspection Protocol

Run after each wave completes, before launching the next wave.

### 1. Verify deliverable artifacts exist (blocking)
For each deliverable in the completed wave:
- List the files matching its `file_ownership` globs.
- Confirm at least one file was created or modified.
- If no artifacts found: flag the deliverable as incomplete. Do not proceed to next wave.
  **Step 1 failures block the next wave.**

### 2. Check for file_ownership violations (non-blocking)
- Run `git diff --name-only` for the wave's changes.
- For each changed file, confirm it falls within exactly one deliverable's
  `file_ownership` globs for this wave.
- A file changed outside all ownership globs is a violation. Log it as a
  warning in review evidence. It does not block the next wave but must be
  reported in the implement-to-review gate evidence.
  **Step 2 violations are warnings, not blocks.**

### 3. Curate context for the next wave
- For each deliverable in wave N+1, determine which wave N outputs it needs.
- Follow the between-wave curation protocol in `skills/shared/context-isolation.md`.
- Summarize wave N results into the next wave's agent prompts. Do not pass
  the orchestrator's full conversation.

## Team Planning
Write `team-plan.md` if not created during decompose. Ownership: each
specialist works ONLY within `plan.json` globs (no overlap within a wave).
Unplanned changes are warnings, not blocks — Phase A review audits them.
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

## Worktree-Complete Hook
When a tmux session exits after worktree work, `launch-phase.sh` fires `rws generate-reintegration <row>` via `tmux set-hook session-closed`. This produces `.furrow/rows/<row>/reintegration.json` — the handoff artifact for `/furrow:merge`. Do not run `rws generate-reintegration` manually during implement; it runs automatically on session close.

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
