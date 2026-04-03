# Platform Boundary Analysis

> What is Furrow? What isn't it? How does the dual-runtime constraint
> shape its identity? How does it stay thin and get thinner over time?

---

## Platform Capability Map

### Claude Code (Interactive Runtime)

| Capability | Mechanism | Notes |
|---|---|---|
| Behavioral instructions | CLAUDE.md (project, user, global) | Auto-loaded, <200 lines recommended |
| Procedural knowledge | Skills (SKILL.md format) | Three-tier progressive loading |
| Lifecycle automation | Hooks (24 events, 4 handler types) | Procedural enforcement where CLAUDE.md is advisory |
| Task tracking | TaskCreate/TaskList/TaskUpdate | Per-session, with dependencies |
| Parallel work | Subagents, Agent tool | Multiple agent types available |
| Isolated work | Git worktrees | Per-agent isolation |
| Background execution | Background agents, /loop | Long-running and scheduled work |
| Session management | Resume, fork, compact | Continuity across sessions |
| Progressive tool loading | Tool Search, defer_loading | 85% context reduction |
| Trust management | Auto mode, permissions, sandboxing | 84% permission prompt reduction |
| Distributable bundles | Plugins | Skills + tools + config packaged |

### Agent SDK (Autonomous Runtime)

| Capability | Mechanism | Notes |
|---|---|---|
| Agent loop | Programmable API (Python/TypeScript) | Agent-as-library model |
| Tool execution | Built-in tools + custom tools | Standard tool-calling interface |
| Lifecycle hooks | Callbacks (can_use_tool, etc.) | Can rewrite inputs, not just allow/deny |
| Subagent spawning | Agent API | Nested agent execution |
| External connectivity | MCP integration | Server-side tool provision |
| Permission control | Permission modes | Configurable trust levels |
| Session continuity | Session management API | Cross-session state |

### What Neither Platform Provides

These are the genuine gaps — where Furrow must add value:

| Gap | Why It Matters |
|---|---|
| **Work definition format** | Neither platform has a structured way to express "what needs to be done" with evaluation criteria. Skills say *how to do things*. CLAUDE.md says *what you need to know*. Neither says *what to build and how to judge it*. |
| **Eval infrastructure** | No built-in eval runner in either platform. No standard format for behavioral evals. No feedback loop from eval results to prompt improvement. |
| **Generator-evaluator enforcement** | Neither platform structurally separates generation from evaluation. An agent can self-review, but the seed research shows this fails reliably. |
| **Work-scoped context management** | CLAUDE.md loads everything. The Agent SDK loads what you tell it. Neither has a mechanism for "load exactly the context relevant to this row." |
| **Quality gate orchestration** | No built-in mechanism to route work through evaluation checkpoints with configurable depth (automated tests → LLM review → human review). |
| **Cross-session work continuity** | Claude Code has session resume/compact, but compaction quality for half-implemented features is unreliable. Agent SDK has session continuity but no structured handoff format. |
| **Evaluator calibration** | No built-in mechanism to iterate on evaluator prompts based on divergence from human judgment. |

### What the Platforms Provide That the Harness Should Leverage for Enforcement

Furrow fills the genuine gaps above AND leverages platform primitives for
enforcement of its conventions:

| Platform Primitive | Enforcement Role |
|---|---|
| Claude Code hooks (24 lifecycle events) | Event-driven enforcement of behavioral expectations |
| Agent SDK callbacks (can rewrite inputs) | Same enforcement in autonomous mode |
| Permission systems (both platforms) | Work-scoped trust levels |
| Skill progressive loading (three-tier) | Context management |
| Teams/subagents (both platforms) | Context isolation, generator-evaluator separation, multi-agent execution |
| Schema validation (via hooks/callbacks) | Structural enforcement of work definitions and progress files |

---

## The Harness's Identity

Given the platform map, Furrow occupies a specific niche:

**Furrow is a set of conventions with an enforcement skeleton built from
platform primitives — file formats, directory structures, naming patterns,
evaluation specifications, and hooks/callbacks that make those conventions
trustworthy rather than advisory.**

It is:
- A **work definition format** (what to build, what done looks like)
- An **eval convention** (how to verify, using existing tools)
- A **context routing scheme** (what to load when)
- A **quality gate protocol** (when to evaluate, at what depth)
- An **enforcement skeleton** (hooks/callbacks that make conventions trustworthy, not advisory)
- A set of **thin runtime adapters** (skills for Claude Code, program templates for Agent SDK)

It is *not*:
- An agent loop or framework (it uses the platform's)
- A state machine (it uses structured files + hooks)
- A tool manager (it uses the platform's)
- A session manager
- A subagent orchestrator

It *does* use platform primitives for enforcement and isolation:
- It uses the platform's permission system for work-scoped trust
- It uses subagent/team boundaries for context isolation and generator-evaluator separation
- It uses hooks/callbacks for procedural enforcement where CLAUDE.md is advisory

---

## The Dual-Runtime Pattern

### Design Principle: Shared Declarations, Separate Adapters

Furrow defines work in a runtime-agnostic format. Each runtime has a thin
adapter that knows how to load and execute that format.

```
                    ┌─────────────────────────┐
                    │   Harness Conventions    │
                    │                          │
                    │  - Work definitions      │
                    │  - Eval specifications   │
                    │  - Context contracts     │
                    │  - Quality gate configs  │
                    └────────┬────────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
    ┌───────────▼──────────┐  ┌──────────▼───────────┐
    │   Claude Code        │  │   Agent SDK           │
    │   Adapter            │  │   Adapter             │
    │                      │  │                       │
    │  - Skills that load  │  │  - Programs that load │
    │    work definitions  │  │    work definitions   │
    │  - Hooks that run    │  │  - Hooks that run     │
    │    quality gates     │  │    quality gates      │
    │  - Human gates via   │  │  - Automated gates    │
    │    conversation      │  │    with higher        │
    │                      │  │    scrutiny           │
    └──────────────────────┘  └──────────────────────┘
```

### What the Adapters Do

**Claude Code adapter** (skills + hooks):
- A skill that reads a work definition and sets up the session
- Hooks that enforce behavioral expectations at lifecycle events (session start, completion claims, eval triggers, session end)
- Hooks that enforce structural conventions (schema validation, progress file integrity)
- Convention: human is present and can be consulted for ambiguous quality judgments

**Agent SDK adapter** (program templates + callbacks):
- A program that reads a work definition and configures the agent loop
- Callbacks that enforce behavioral expectations at tool-call boundaries
- Callbacks that enforce structural conventions (schema validation, progress file integrity)
- Convention: human is absent; automated evaluation thresholds are stricter

### What Stays the Same Across Runtimes

- Work definition files (what to build, evaluation criteria, context pointers)
- Eval specification files (runnable tests, LLM-judge criteria)
- Progress tracking files (structured state, completion claims)
- Quality gate configuration (which gates, at what thresholds)

### What Differs Between Runtimes

| Concern | Claude Code | Agent SDK |
|---|---|---|
| Work loading | Skill reads work def at session start | Program reads work def at startup |
| Enforcement | Hooks at lifecycle events | Callbacks at tool-call boundaries |
| Quality gate execution | Hook triggers gate; human can override | Callback triggers gate; automated only |
| Human escalation | Direct conversation | Notification + pause (or policy-based auto-decision) |
| Context injection | CLAUDE.md + skill progressive loading | System prompt + programmatic context loading |
| Progress visibility | Task system (user-visible) | Log files + structured state |

---

## Shrinkability: Designing for Deletion

### The Deletion Test

Every harness component should pass this test periodically:

1. Remove the component
2. Run the full eval suite
3. If evals still pass → the component is no longer needed, delete it permanently
4. If evals degrade → the component is still load-bearing, keep it

This requires the eval suite to be comprehensive enough to detect behavioral
regressions. Which reinforces the eval-first constraint: you can't safely delete
components without evals that would catch the regression.

### Component Annotation Pattern

Each component in Furrow has an entry in `_rationale.yaml` with two fields:
the reason it exists (what limitation it addresses) and the condition under which
it can be safely removed. Example:

```yaml
# _rationale.yaml (single manifest, not injected into context)
components:
  - path: skills/implement.md
    reason: "Model X doesn't reliably [specific limitation]"
    removal_condition: "Model can [specific capability] without this guidance"
```

This makes the deletion test concrete: when a new model drops, check each
component's removal condition against the new model's capabilities.

### Enforcement Skeleton Shrinkability

The enforcement skeleton itself is designed for deletion. Each hook/callback
encodes an assumption about model behavior — that the model will not reliably
follow a convention without procedural enforcement. When models reliably follow
conventions without procedural enforcement, the hooks can be removed. The same
deletion test applies: remove the hook, run the eval suite, keep or delete based
on results.

### Predicted Shrinkage Vectors

Based on platform trajectory and model improvement patterns:

| Component | Likely to be absorbed by | Timeframe signal |
|---|---|---|
| Work decomposition guidance | Model capability (already improving) | Models reliably avoid one-shotting without prompting |
| Progress tracking format | Platform task systems (already emerging) | Claude Code tasks gain cross-session persistence |
| Context routing | Platform context management | CLAUDE.md gains scoped loading or Agent SDK adds auto-context |
| Evaluator prompts | Model self-evaluation (long-term) | Models reliably catch their own errors without structural separation |
| Cross-session handoff | Platform session management | Compaction quality reaches structured-handoff quality |
| Quality gate orchestration | Platform lifecycle hooks | Hooks gain conditional evaluation and routing |

Furrow components most likely to *persist* are the ones encoding user
preferences rather than model limitations: what "good" looks like for this
specific developer, what quality standards apply to this specific project.
Capability uplift shrinks; encoded preference persists.

---

## Implications for Architecture

1. **File conventions first, enforcement skeleton second, custom code last.**
   If something can be expressed as a file convention (naming pattern, directory
   structure, YAML schema), prefer that over code. If a convention needs
   enforcement (failure severity High/Critical), use platform-native
   hooks/callbacks. Only write custom code for genuine gaps (eval runner, trace
   normalization). Conventions have zero runtime, zero dependencies, and are
   trivially portable across runtimes.

2. **Adapters are disposable.** The Claude Code adapter (skills/hooks) and the
   Agent SDK adapter (program templates) should be thin enough that rewriting
   them for a new runtime is trivial. The value is in the conventions, not the
   adapters.

3. **Furrow gets smaller over time.** Each component should be designed
   with its own obsolescence in mind. The maintenance model is periodic deletion
   testing, not feature addition.

4. **Platform-native when possible.** If Claude Code adds cross-session task
   persistence, delete Furrow's progress tracking convention. If the Agent
   SDK adds structured eval hooks, delete Furrow's eval runner adapter.
   Always prefer the platform primitive.

5. **Furrow uses the platform for enforcement, not just execution.** Hooks
   and callbacks are as much part of the convention layer as file formats and
   directory structures. They are declarative, lightweight, and deletable — not
   a departure from the convention-layer identity, but its procedural
   complement.
