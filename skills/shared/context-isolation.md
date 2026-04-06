# Context Isolation — Team Context Boundary Rules

## What Sub-Agents Receive

When dispatching specialist sub-agents, the lead agent curates context per these rules:

1. **Full task text** — the complete task description, not a pointer to go read it.
2. **Curated context** — files and symbols selected by the lead, specific to the sub-agent's assignment.
3. **Skill Read instructions** — per the skill injection order (code-quality first, then specialist skills, then step skill, then task skills).
4. **definition.yaml pointer** — for acceptance criteria reference.
5. **File ownership scope** — the glob patterns this agent is responsible for.

## What Sub-Agents Do NOT Receive

- Full session history from the lead agent.
- Other sub-agents' work-in-progress (until their wave completes).
- Raw research from previous steps (they get `summary.md` instead).
- Other deliverables' review results.
- `state.json` — sub-agents do not read or write state.

## Context Curation Using Specialist Templates

The lead agent uses the specialist template's Context Requirements section to guide curation:

- **Required** items from the template are always included in the sub-agent's prompt.
- **Helpful** items are included when they exist and are relevant to this assignment.
- **Exclude** items are never included — they distract the specialist from its domain focus.

## Model Resolution

When dispatching a sub-agent, select the model using this resolution order:

1. **Specialist `model_hint`** — read from the specialist template's YAML frontmatter.
2. **Step `model_default`** — declared in the current step skill's Model Default section.
3. **Project default** — `sonnet` (if neither specialist nor step specifies).

Pass the resolved model as the Agent tool's `model` parameter (valid values: `sonnet`, `opus`, `haiku`).

These are hints, not enforcement. The lead agent may override when task complexity
warrants a different model than the hint suggests.

## Wave Isolation

Within a wave, agents work on independent deliverables concurrently:
- Each agent writes only within its `file_ownership` globs.
- Agents in the same wave do not read each other's outputs.
- When a wave completes, the lead inspects all outputs before launching the next wave.

Between waves:
- Wave N+1 agents can read Wave N outputs (they are complete files).
- The lead agent curates which Wave N outputs each Wave N+1 agent receives.

## Anti-Pattern: Context Leakage

Never pass the lead agent's full conversation to a sub-agent. The lead's context contains decision-making, exploration, and dead ends that are noise for the specialist. Curate, do not copy.
