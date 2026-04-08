# Spec: orchestrator-architecture

## Deliverable Overview
Create the orchestrator skill, update context isolation rules, refactor all 7 step
skills with dispatch metadata, and create model routing reference documentation.

## Artifact 1: skills/orchestrator.md (NEW, ≤100 lines)

### Content Structure

```markdown
# Orchestrator Protocol

## Role
You are the orchestrator. You own user collaboration — presenting findings,
asking targeted questions, iterating on decisions, and managing step transitions.
You NEVER produce deliverable artifacts directly (no file writes to project code,
specs, or plans outside of .furrow/ row artifacts). You dispatch step agents for
execution and curate the context they receive.

## Dispatch Table

| Step | Inline (You) | Dispatched (Agent) | Agent Model |
|------|-------------|-------------------|-------------|
| ideate | 6-part ceremony, all decisions | Fresh reviewer, cross-model (optional) | sonnet |
| research | Source-trust, validation, coverage | Parallel topic investigators | opus |
| plan | Trade-offs, risk, dependency order | Codebase exploration (optional) | sonnet |
| spec | AC precision, edge cases, testability | Component spec writers (multi-deliverable) | sonnet |
| decompose | Wave approval (minimal) | None — write plan.json directly | — |
| implement | Wave orchestration, inspection gates | Specialist agents per wave | per hint |
| review | Phase A checks, synthesis, consent | Phase B isolated evaluators | opus |

## Dispatch Protocol

For each step that dispatches agents:

1. **Prepare context** — read the step skill's Agent Dispatch Metadata section for
   what to include. Always include: step skill content, relevant summary.md sections,
   definition.yaml acceptance criteria, file ownership globs.
2. **Load specialist** (if assigned) — read `specialists/{type}.md`. Extract model_hint
   from frontmatter. Include full template in agent prompt. Follow specialist's
   Context Requirements for curation (Required/Helpful/Exclude).
3. **Resolve model** — specialist model_hint > step model_default > sonnet.
   Pass as Agent tool `model` parameter.
4. **Dispatch** — Agent tool with curated prompt. Include mode overlay from step skill
   if specialist is assigned.
5. **Receive** — agent returns findings or artifacts.
6. **Present** — summarize results to user using step's Collaboration Protocol
   decision categories. Ask targeted questions per the step's high-value examples.
7. **Iterate** — if user requests changes, re-dispatch with updated context.
   Multi-round dispatch/receive is expected within any step.

## Context Curation Rules

What flows to dispatched agents:
- Step skill content (as standalone execution instructions)
- Specialist template (if assigned)
- summary.md (synthesized context from prior steps)
- definition.yaml acceptance criteria for relevant deliverables
- File ownership globs (from plan.json if available)
- Mode overlay from step skill (if specialist assigned)

What does NOT flow:
- This orchestrator skill (agents don't need dispatch instructions)
- Full session conversation history
- Other agents' work-in-progress
- state.json
- Raw research or prior step artifacts (summary.md is the synthesis)

See `skills/shared/context-isolation.md` for full boundary rules.
See `references/model-routing.md` for model resolution rationale.

## Boundary Enforcement

You must NOT:
- Write project files (code, configs, scripts) directly
- Implement review findings — dispatch an agent with the findings as context
- Write specs inline — dispatch a spec agent
- Execute any step's execution instructions yourself
- Skip dispatching by doing "quick" inline work

You MAY:
- Write .furrow/ row artifacts (summary updates via rws, research notes)
- Reason about step content to formulate dispatch prompts
- Synthesize agent outputs for user presentation
- Make collaboration decisions (what to ask, what to present)

## Multi-Round Pattern

Within any step, the dispatch loop may repeat:
1. Dispatch agent(s) for initial investigation/drafting
2. Receive results, present to user
3. User provides feedback or decisions
4. Dispatch agent(s) with refined context incorporating decisions
5. Repeat until user approves step output
6. Run Supervised Transition Protocol
```

### Acceptance Criteria (Refined)
- AC1: Dispatch table covers all 7 steps with inline/dispatched split and agent model
- AC2: Dispatch protocol is a numbered sequence the orchestrator follows per dispatch
- AC3: Context curation rules specify included/excluded items with rationale
- AC4: Boundary enforcement lists explicit DO/DO NOT rules
- AC5: Multi-round pattern shows the iterate loop within a step
- AC6: Total line count ≤ 100 (references model-routing.md for details)
- AC7: No references to specific file paths that would break in consumer projects

### Test Scenarios

**WHEN** orchestrator.md is loaded into a session at any step
**THEN** the dispatch table tells the orchestrator what to dispatch and at what model
**VERIFY** `grep -c '|' skills/orchestrator.md` shows table rows for all 7 steps

**WHEN** a step needs agent dispatch
**THEN** the dispatch protocol provides a numbered sequence to follow
**VERIFY** Dispatch protocol section contains numbered steps 1-7

**WHEN** orchestrator.md is measured
**THEN** it fits within the context budget
**VERIFY** `wc -l skills/orchestrator.md` ≤ 100

---

## Artifact 2: skills/shared/context-isolation.md (MODIFY)

### Changes Required

Add new section **## Orchestrator/Agent Boundary** after the existing "Anti-Pattern: Context Leakage" section (after line 56). Content:

```markdown
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
```

### Acceptance Criteria (Refined)
- AC1: New section documents orchestrator vs step agent roles
- AC2: Boundary rule stated: orchestrator does not produce deliverable artifacts
- AC3: Step agent isolation: agents don't know they were dispatched
- AC4: Total file stays ≤ 75 lines (currently 56 + ~17 new = ~73)

### Test Scenarios

**WHEN** context-isolation.md is read by a dispatched agent
**THEN** the agent finds curation rules but NOT dispatch instructions
**VERIFY** `grep -c 'orchestrator.md' skills/shared/context-isolation.md` = 0 in the sub-agent sections

---

## Artifact 3: references/model-routing.md (NEW)

### Content Structure

```markdown
# Model Routing

## Resolution Order

When dispatching an agent, resolve the model in this order:
1. **Specialist model_hint** — from `specialists/{type}.md` YAML frontmatter
2. **Step model_default** — from the current step skill's Model Default section
3. **Project default** — `sonnet`

The lead agent passes the resolved model as the Agent tool's `model` parameter.

## Per-Step Rationale

| Step | Default | Rationale |
|------|---------|-----------|
| ideate | sonnet | Brainstorm, definition writing — structured, not novel |
| research | opus | Multi-source investigation, synthesis across domains |
| plan | sonnet | Synthesize decisions from research — structured application |
| spec | sonnet | Structured writing from plan decisions |
| decompose | sonnet | Formulaic wave mapping given plan |
| implement | sonnet | Execute against specs (specialists may override to opus) |
| review | opus | Quality judgment, cross-deliverable evaluation |

## Specialist Model Hints

| Hint | When Used | Current Specialists |
|------|-----------|-------------------|
| opus | Multi-step reasoning, novel problems, cross-component decisions | systems-architect, complexity-skeptic, security-engineer, accessibility-auditor, prompt-engineer |
| sonnet | Well-scoped execution, single-domain, established patterns | All others (15 specialists) |
| haiku | Trivial boilerplate | None currently |

## Override Rules

The lead agent MAY override model hints when:
- Task complexity clearly exceeds the hinted model's capability
- Multiple specialists collaborate and need aligned reasoning depth
- A specialist is doing atypically complex work for its domain

Overrides should be documented in the dispatch rationale, not silent.
```

### Acceptance Criteria (Refined)
- AC1: Resolution order documented with all 3 tiers
- AC2: Per-step rationale table covers all 7 steps with reasoning
- AC3: Specialist model hint summary with current assignments
- AC4: Override rules specify when and how to deviate from hints

### Test Scenarios

**WHEN** a new specialist is added to the project
**THEN** references/model-routing.md provides clear guidance on choosing model_hint
**VERIFY** `grep 'opus\|sonnet\|haiku' references/model-routing.md` returns hint definitions

---

## Artifact 4: Step Skill Refactoring (MODIFY all 7)

### Changes Per Step Skill

For each of the 7 step skills, add an **## Agent Dispatch Metadata** section.
Insert it after the existing Collaboration Protocol section (or after Step-Specific Rules
if no Collaboration Protocol exists).

#### ideate.md — Agent Dispatch Metadata (insert after line 60, before Shared References)

```markdown
## Agent Dispatch Metadata
- **Dispatch pattern**: Optional — fresh reviewer subagent for dual outside voice
- **Agent model**: sonnet (reviewer is structured evaluation, not novel reasoning)
- **Context to agent**: Problem framing summary, definition.yaml draft, review dimensions
- **Context excluded**: Full 6-part ceremony conversation, user decision history
- **Returns**: Structured review findings for orchestrator synthesis
```

#### research.md — Agent Dispatch Metadata (insert after line 39, before Shared References)

```markdown
## Agent Dispatch Metadata
- **Dispatch pattern**: Parallel agents per research topic
- **Agent model**: opus (multi-source investigation requires deep reasoning)
- **Context to agent**: Research question, definition.yaml deliverable names, source hierarchy rules, summary.md context from ideation
- **Context excluded**: Source-trust decisions from other topics, user validation conversations
- **Returns**: Per-topic research document with Sources Consulted section
```

#### plan.md — Agent Dispatch Metadata (insert after line 38, before Shared References)

```markdown
## Agent Dispatch Metadata
- **Dispatch pattern**: Optional — codebase exploration agent for architecture investigation
- **Agent model**: sonnet (structured codebase reading, not architectural reasoning)
- **Context to agent**: Exploration question, file/symbol targets, research findings summary
- **Context excluded**: Trade-off discussions, risk tolerance decisions
- **Returns**: Codebase findings (file structures, patterns, dependencies)
```

#### spec.md — Agent Dispatch Metadata (insert after line 44, before Shared References)

```markdown
## Agent Dispatch Metadata
- **Dispatch pattern**: Parallel agents per component (multi-deliverable)
- **Agent model**: sonnet (structured spec writing from plan decisions)
- **Context to agent**: Plan decisions for this component, definition.yaml ACs, relevant research findings, specialist template (if assigned)
- **Context excluded**: Other components' specs, plan trade-off discussions
- **Returns**: Component spec with refined ACs and test scenarios
```

#### decompose.md — Agent Dispatch Metadata (insert after line 18, before Shared References)

```markdown
## Agent Dispatch Metadata
- **Dispatch pattern**: None — orchestrator writes plan.json and team-plan.md directly
- **Agent model**: N/A
- **Rationale**: Decomposition is a small coordination task that reads specs and produces a wave map. Dispatching an agent adds overhead without value.
```

#### implement.md — Agent Dispatch Metadata (insert after line 50, before Team Planning)

```markdown
## Agent Dispatch Metadata
- **Dispatch pattern**: Specialist agents per deliverable per wave (plan.json-driven)
- **Agent model**: Per specialist model_hint (see references/model-routing.md)
- **Context to agent**: Specialist template, spec for deliverable, file ownership globs, summary.md, definition.yaml ACs. Curate per specialist Context Requirements.
- **Context excluded**: Other waves' WIP, orchestrator conversation, state.json
- **Returns**: Implemented code/artifacts within file_ownership scope
```

#### review.md — Agent Dispatch Metadata (insert after line 26, before Shared References)

```markdown
## Agent Dispatch Metadata
- **Dispatch pattern**: Phase B isolated evaluators (fresh Claude + cross-model)
- **Agent model**: opus (quality judgment requires deep reasoning)
- **Context to agent**: Review prompt template, artifact paths, eval dimensions ONLY
- **Context excluded**: summary.md, state.json, conversation history, CLAUDE.md (generator-evaluator separation)
- **Returns**: Per-deliverable review verdict with dimension scores
```

### Acceptance Criteria (Refined)
- AC1: All 7 step skills have ## Agent Dispatch Metadata sections
- AC2: Each section specifies dispatch pattern, agent model, context included, context excluded, returns
- AC3: Step skills remain functional as standalone agent instructions (no "the orchestrator will..." language in execution sections)
- AC4: No net increase >10 lines per step skill (dispatch metadata is concise)

### Test Scenarios

**WHEN** a step skill is loaded into a dispatched agent
**THEN** the agent can execute the step without referencing orchestrator.md
**VERIFY** `grep -c 'orchestrator' skills/{step}.md` = 0 in execution sections (only in Agent Dispatch Metadata)

**WHEN** Agent Dispatch Metadata is read by the orchestrator
**THEN** it provides enough information to construct the Agent tool call
**VERIFY** Each metadata section contains: dispatch pattern, agent model, context included/excluded
