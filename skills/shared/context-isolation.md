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

### Between-Wave Curation Protocol

When preparing context for wave N+1 agents from wave N outputs, follow this
protocol. The goal: give each next-wave agent exactly the upstream context it
needs, at minimum size, with no orchestrator noise.

**Step 1: Classify each wave N output by relevance.**
For each wave N+1 deliverable, check its specialist's Context Requirements.
Cross-reference against wave N deliverables. An output is relevant if:
- The N+1 deliverable's `file_ownership` globs overlap with or depend on files
  produced by a wave N deliverable (e.g., imports, shared interfaces).
- The N+1 specialist's Context Requirements list the output type as Required or Helpful.

Irrelevant wave N outputs are excluded entirely.

**Step 2: Choose pass-through vs summary for each relevant output.**

| Output type | Action | Size guidance |
|-------------|--------|---------------|
| Interface definitions, type signatures, API contracts | Pass verbatim | Include the full file — these are compact and must be exact |
| Configuration files (YAML, JSON, TOML) | Pass verbatim | Include the full file — partial configs are unusable |
| Implementation files (<100 lines) | Pass verbatim | Small enough that summarizing loses more than it saves |
| Implementation files (>=100 lines) | Summarize | Write a structured summary: public API, key functions with signatures, important side effects, file path. Target ~30 lines per file |
| Test files | Summarize | List test names and what they cover. Include exact assertions only if the next agent must match them |
| Documentation / research artifacts | Summarize | Extract claims and decisions relevant to the next deliverable. Drop sourcing details unless the next agent needs to verify |

**Step 3: Assemble the context block.**
For each wave N+1 agent prompt, insert a `## Wave N Outputs` section containing:
- Verbatim files as fenced code blocks with file paths as headers.
- Summaries as structured markdown (not prose paragraphs).
- Nothing from the orchestrator's decision-making, dead ends, or retries.

**Size target:** The wave N outputs section should not exceed 40% of the agent's
total prompt. If it does, convert more verbatim outputs to summaries until the
budget is met. Interface definitions and contracts are the last to be summarized.

## Anti-Pattern: Context Leakage

Never pass the lead agent's full conversation to a sub-agent. The lead's context contains decision-making, exploration, and dead ends that are noise for the specialist. Curate, do not copy.

## Reintegration Handoff Artifact

When a worktree completes, the canonical handoff to `/furrow:merge` is `.furrow/rows/<row>/reintegration.json` (schema: `schemas/reintegration.schema.json`). Pass this JSON — never the markdown view — to the merge agent. Read it via `rws get-reintegration-json <row>`.

## Orchestrator/Agent Boundary

The orchestrator session and step agents have distinct roles:

- **Orchestrator** (main session): owns user collaboration, step transitions,
  and dispatch decisions. Runs at opus. Reads `skills/orchestrator.md`.
- **Step agents** (dispatched): own execution — producing artifacts, writing code,
  investigating topics. Run at the model specified by dispatch table. Read step
  skill as standalone instructions.

The boundary rule: the orchestrator does not produce deliverable artifacts.
It dispatches agents who produce them. The orchestrator presents results to the
user, iterates on decisions, and dispatches again if needed.

Step agents do not:
- Reference the orchestrator skill or dispatch protocol
- Know they were dispatched (they execute step instructions as if they are the session)
- Access the orchestrator's conversation history or decision-making context
