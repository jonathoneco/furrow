# Work Decomposition & Context Architecture

> How should work be broken down? How should context flow across sessions?
> When should multiple agents be involved? This document addresses research
> questions 1 (decomposition), 2 (context management), and 6 (coordination).

---

## Part 1: Work Decomposition

### The Fundamental Question

Should Furrow prescribe *how* to decompose work, or just *that*
decomposition happens?

The seed research argues both sides:

**For prescribed decomposition:**
- Without structure, agents one-shot (build everything at once and fail)
- Without progress tracking, agents declare premature victory
- V1's depth-based routing was a validated concept
- Anthropic's Effective Harnesses post: feature lists + one-at-a-time discipline

**Against prescribed decomposition:**
- Over-specification hurts: "constrain on deliverables, let them figure out the path"
- Model capability changes what structure is needed (sprint contracts useful for Opus 4.5, unnecessary for Opus 4.6)
- Rigid decomposition can't adapt to what the model discovers during execution
- Live-SWE-agent (75.4% SWE-bench) creates its own decomposition via reflection

### Proposed Model: Outcome-Based with Structural Guardrails

Furrow should define **what** and **when**, not **how**.

A work definition specifies:

1. **Objective** — what the work should produce (natural language, for human and model understanding)
2. **Deliverables** — enumerated, concrete outputs (prevents one-shotting by making scope explicit)
3. **Evaluation criteria** — how to judge each deliverable (links to eval specifications)
4. **Context pointers** — what information is needed (links to relevant files, docs, code)
5. **Constraints** — boundaries the work must stay within (tech choices, scope limits, standards)

Furrow does NOT specify:
- Implementation order (the model decides)
- Decomposition strategy (the model decides)
- Tool usage (the model decides)
- Number of sessions (emergent from the work)

### Structural Guardrails (What the Harness Enforces)

These prevent known failure modes without prescribing approach:

| Guardrail | Prevents | Mechanism |
|---|---|---|
| Deliverable enumeration | One-shotting | Work definition lists concrete outputs |
| Sequential discipline for dependent deliverables | Scattered partial progress | Dependent deliverables complete and evaluate one at a time; independent deliverables execute in parallel via specialist agents |
| Explicit completion claims | Premature victory | Progress file requires explicit "done" per deliverable, subject to evaluation |
| Evaluation at boundaries | Quality drift | Each completion claim triggers evaluation before proceeding |
| Correction limit | Correction spiral | After N failed evaluation cycles on one deliverable, pause for human input |

### Challenging the "Complexity Tiers" Model

V1 used depth-based task routing — different complexity tiers got different
amounts of scaffolding. Should v2?

**Arguments for tiers:**
- A one-line bug fix shouldn't go through the same process as a multi-week initiative
- Overhead should be proportional to risk/complexity
- The Anthropic blog validates this: minimal tooling wins on narrow tasks,
  scaffolding wins on complex open-ended work

**Arguments against explicit tiers:**
- Tier boundaries are arbitrary and model-dependent
- Tier classification is itself error-prone (what if the agent misclassifies?)
- The model should be able to judge appropriate decomposition depth
- Tiers add a classification step that can fail before work even begins

**Proposed resolution: Implicit scaling, not explicit tiers.**

The structural guardrails above scale naturally:

- **Simple work** (bug fix): 1 deliverable, simple evaluation criteria, no
  context pointers needed beyond the bug report. The model completes it in one
  shot, evaluation passes, done. Zero overhead from the guardrails.

- **Medium work** (feature): 3-5 deliverables, each with evaluation criteria,
  context pointers to relevant code and specs. The model works through
  deliverables one at a time, evaluating at each boundary.

- **Complex work** (initiative): 10+ deliverables organized into phases, rich
  evaluation criteria, extensive context. Multiple sessions, handoff artifacts,
  possibly multi-agent.

The *same* work definition format handles all three. The guardrails only activate
when the work definition has multiple deliverables. There's no tier classification
step — the work definition's complexity *is* the tier.

### How This Changes Between Runtimes

| Aspect | Interactive (Claude Code) | Autonomous (Agent SDK) |
|---|---|---|
| Work definition creation | Human writes it, or model proposes and human approves | Pre-defined, or model creates from a higher-level objective |
| Deliverable ordering | Model proposes, human can redirect | Model decides autonomously |
| Evaluation execution | Model proposes completion → eval runs → human reviews if needed | Model proposes completion → eval runs → automated decision |
| Correction limit | Human decides when to intervene | Configurable threshold triggers pause/notification |
| Scope changes | Human can modify work definition mid-flight | Work definition is fixed unless programmatic scope change is built in |

---

## Part 2: Context Architecture

### Revisiting the Three-Tier Model

The seed observation identified three context tiers by lifespan:

1. Project-level (months) — conventions, architecture, priorities
2. Work-level (days–weeks) — specs, design decisions, scope
3. Record-level (hours) — checkpoints, logs, progress

This observation is empirically valid but needs refinement along two axes:
**management mechanism** and **loading strategy**.

### Refined Context Model

| Tier | What | Managed by | Storage | Loading |
|---|---|---|---|---|
| **Ambient** | Project conventions, tool config, behavioral rules, team standards | Platform | CLAUDE.md, hooks, skill metadata | Always loaded (cached, low marginal cost) |
| **Work** | Current work definition, eval specs, design decisions, related research, progress state | Harness | Structured files in work directory | Loaded at work start, unloaded at work end |
| **Session** | Conversation history, tool results, intermediate reasoning, ephemeral state | Platform | Context window, task system | Created during execution, compacted or lost at session boundary |

**Key changes from the seed observation:**

1. **Renamed "record-level" to "session."** The original "record-level" mixed two
   things: ephemeral session state and persistent audit records. These have
   different management needs. Persistent audit records (what was done, when, by
   whom) are better handled by git history than by a custom record format.

2. **Clarified management responsibility.** Furrow manages the work tier.
   The platform manages ambient and session tiers. This is the minimal-footprint
   ownership model.

3. **Made loading strategy explicit.** Ambient context is always present (prompt
   caching makes this nearly free). Work context is loaded on demand. Session
   context is ephemeral.

### Work Context: The Harness's Core Responsibility

The work tier is where Furrow adds the most value. Neither platform has a
mechanism for "load exactly the context relevant to this row."

**Work context includes:**

- The work definition itself (objective, deliverables, criteria)
- Eval specifications for the work
- Relevant design decisions and research
- Progress state (which deliverables are done, evaluation results)
- Handoff artifacts from previous sessions (if multi-session)

**Work context does NOT include:**

- The codebase (available via tools on demand)
- Project conventions (ambient tier handles this)
- Conversation history (session tier handles this)
- Git history (available via git on demand)

### The Loading Problem: How Much Context at Session Start?

The seed research documents a tension:

- V1 injected 849 lines per session — too much, creates context tax
- Zero pre-loading means agents spend cycles rediscovering context — wasteful
- Compaction doesn't reliably preserve half-implemented feature context

**Proposed approach: Structured handoff + progressive loading.**

At session start, load:
1. **Ambient context** (platform-managed, automatic): ~50-100 tokens of CLAUDE.md
2. **Work summary** (Furrow-managed): ~200-500 tokens — objective, current state,
   next deliverable, key decisions. NOT the full work definition.
3. **Nothing else** — all other context retrieved on demand via tools.

The work summary is the critical artifact. It should be:
- Auto-generated at session end (or compaction boundary) from the full work context
- Human-reviewable (natural language, not opaque state)
- Sufficient to orient the model without loading everything

This is the "structured handoff" pattern from v1, refined. The handoff artifact
is a summary, not a full dump. The model can retrieve full details as needed.

### Session Boundaries: Proactive Context Management

The seed research identifies multiple signals for session boundaries:

- Context filling → performance degradation (context anxiety)
- Model-dependent: Opus 4.6 handles long context better than earlier models
- Compaction loses detail on half-implemented work
- Fresh context for evaluation is a feature (independent evaluator perspective)

**Approach: Furrow manages context proactively, not reactively.**

Rather than letting context accumulate until something breaks, Furrow uses
structural mechanisms to keep context bounded:

1. **Deliverable sizing** — deliverables should be completable in a single focused
   session. If a deliverable requires deep cross-cutting context or many rounds
   of iteration, it's too large and should be decomposed further.

2. **Correction limits** — after N failed eval/fix cycles on one deliverable, the
   agent pauses rather than accumulating more context. This is Level B enforcement
   (hook-enforced).

3. **Multi-agent context isolation** — when each deliverable executes in its own
   specialist's context, context bloat is per-specialist and bounded by agent
   lifetime, not cumulative across the row.

4. **Progressive loading** — session-start hook loads only the work summary
   (~200-500 tokens). Everything else retrieved on demand.

5. **Work state in files** — work definition, progress state, and eval results
   live on disk. Context compaction or session loss doesn't destroy work state.

The work summary is auto-generated at session/deliverable boundaries (Level B
enforcement via hook). Session boundaries remain emergent, but Furrow
prevents the conditions that make unplanned boundaries catastrophic.

---

## Part 3: Agent Coordination

### Default Execution Model: Multi-Agent Teams

The seed research provides clear quantitative evidence:

**Multi-agent advantages:**
- Context isolation: 4.4x error containment with centralized coordination (vs. 17.2x for independent agents)
- Research tasks: 90.2% improvement with multi-agent over single-agent
- Parallel execution: 90% time reduction when work is truly independent
- Specialization: domain-prompted agents catch issues generalists miss

**Reported costs:**
- 3-10x token overhead, 40% pilot failure rate within 6 months

**Why costs don't change the default:**
- Token overhead is irrelevant on a flat-rate Max plan — cost is not a decision factor
- The 40% pilot failure rate reflects poor coordination patterns (independent agents),
  not centralized coordination (4.4x error containment)
- Both platforms (Claude Code teams, Agent SDK) provide first-class team primitives
  that handle coordination mechanics

**Default: For any work with 2+ deliverables, the execution model is a multi-agent team.**

### Four-Role Architecture

**Planner** — reads the objective, produces the work definition (deliverables,
eval criteria, dependency graph, specialist assignments, context pointers). In
supervised mode, human collaborates. In delegated mode, human approves. In
autonomous mode, scope-check eval validates.

**Coordinator (lead)** — manages execution: reads work definition, spawns
specialists (parallel where dependencies allow), tracks progress.json, handles
failures, synthesizes results. Coordinator's context stays lean — it holds work
definition, progress state, and result summaries, never execution context.

**Specialist executor(s)** — domain-specific agents per deliverable. Named and
prompted for their domain (`auth-specialist`, `database-architect`,
`frontend-specialist`). The work definition maps deliverables to specialist
types. Quality through specialization: domain-prompted agents catch issues
generalists miss.

**Evaluator** — fresh-context review of each deliverable. Structurally isolated
from execution reasoning. **Cross-model by default** for 2+ deliverable work
(Claude + Gemini captures 91% of five-model ceiling). Single-model only for
trivial work.

### Parallel by Default

Independent deliverables execute concurrently. The coordinator reads the
dependency graph, identifies the parallelizable frontier, spawns specialists
concurrently for independent deliverables, and sequences dependent ones.

```
Deliverables:  [A] ──→ [C] ──→ [E]
               [B] ──→ [D] ──╱

Execution:     Wave 1: A, B (parallel)
               Wave 2: C, D (parallel, after A, B respectively)
               Wave 3: E (after C, D)
```

### When Single-Agent Remains Appropriate

- **1-deliverable work** — no team needed; eval still runs as a separate
  cross-model agent for non-trivial work
- **Supervised mode with tight human interaction** — human provides context
  protection and quality review directly

### The Human as Coordinator

The seed research identifies a critical finding: "The human becomes the
bottleneck" and "brain fry managing parallel agents." This is especially
relevant for a solo developer.

**For interactive mode (Claude Code):** The human is the natural coordinator.
Claude Code's teams/subagents handle the mechanics. Furrow's role is to
make coordination decisions explicit in the work definition: which deliverables
can be parallelized, which need sequential treatment, which need specialized
agents.

**For autonomous mode (Agent SDK):** The coordinator agent manages execution
programmatically. Furrow provides the four-role architecture: planner
produces the work definition, coordinator reads it and spawns specialists,
evaluator reviews deliverables. The work definition's structure drives
coordination automatically.

### Communication Convention

Agents communicate through the filesystem:

```
work/
  current-feature/
    definition.yaml          # Work definition (read by all agents)
    progress.json            # Progress state (updated by coordinator)
    context/                 # Work-scoped context
    eval/                    # Evaluation results
      deliverable-a.json     # Eval result per deliverable
      deliverable-b.json
    specialists/             # Specialist agent workspaces
      auth-specialist/
        output.md            # Specialist's results
        status.json          # Specialist's status
      database-architect/
        output.md
        status.json
      frontend-specialist/
        output.md
        status.json
```

- Specialists write to their own directory
- Coordinator reads all specialist directories
- No shared mutable state between agents
- JSON for machine-readable state, Markdown for human-readable output
- Evaluator writes to eval/ directory, structurally separate from specialist output

---

## Resolved Decisions

These questions were identified during research and are now resolved based on
the evidence gathered above.

### 1. Work Definition Schema

**Decision: YAML.** Five required fields:

- **objective** — what the work should produce
- **deliverables** — enumerated outputs, each with eval criteria, dependency
  declarations, and specialist type assignment
- **context_pointers** — references to specific files, symbols, or sections
- **constraints** — boundaries the work must stay within
- **evaluation** — gate types (per-deliverable, final), model configuration
  (cross-model default for 2+ deliverables)

YAML because it's human-readable, supports comments, and both runtimes parse it
trivially. The dependency graph is expressed inline per deliverable (e.g.,
`depends_on: [deliverable-a]`), not as a separate structure.

### 2. Handoff Artifact Generation

**Decision: Auto-generated by hook at session end or deliverable completion.**

The hook reads progress.json and recent file changes to produce a work summary.
The model CAN write a richer summary, but the hook-generated one is the floor.
This is Level B enforcement — the model doesn't need to remember to do this.

The summary includes: objective, completed deliverables with eval results,
current deliverable and its state, key decisions made, and next actions. This
is the ~200-500 token artifact loaded at session start.

### 3. Evaluation Trigger Mechanism

**Decision: Completion claim in progress.json, detected by hook (Claude Code)
or callback (Agent SDK).**

The hook validates the claim structure, then triggers the eval runner. Fallback:
periodic check after N tool calls if no completion claim has been made. Works
identically in both runtimes — the trigger is a file mutation, not a runtime
event.

The eval runner spawns a fresh-context evaluator agent (cross-model by default
for 2+ deliverable work). The evaluator reads the deliverable's eval criteria
from the work definition and the specialist's output, produces a pass/fail with
reasoning, and writes the result to `eval/deliverable-name.json`.

### 4. Work-Level Context Discovery

**Decision: Explicit pointers in the work definition.**

Context pointers reference specific files, symbols, or sections — not whole
directories. Specific pointers encourage targeted retrieval and model the
progressive loading pattern. The model can discover additional context via
tools, but the work definition provides the starting set.

Example:
```yaml
context_pointers:
  - path: src/auth/middleware.go
    symbols: [AuthMiddleware, ValidateToken]
    note: "Current auth implementation to extend"
  - path: docs/api-spec.yaml
    sections: ["/users/{id}", "/users/{id}/roles"]
    note: "Endpoints affected by this change"
```

### 5. Coordination Decision

**Decision: Automated from work definition properties.**

- 2+ deliverables → multi-agent team (default)
- 1 deliverable → single-agent
- Dependencies between deliverables → coordinator manages sequencing
- No dependencies → parallel execution

The work definition's structure IS the coordination specification. Human
override available in supervised mode (e.g., forcing single-agent for a
2-deliverable row where tight coupling makes multi-agent wasteful).
