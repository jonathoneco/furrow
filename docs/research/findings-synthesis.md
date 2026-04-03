# Research Synthesis & Decision Map

> This document synthesizes findings from all six seed documents and identifies
> the key insights, tensions, and decision dependencies that should drive
> architectural choices. It is the entry point — read this first.

---

## Eight Key Insights

### 1. The Harness is a Convention Layer, Not an Engine

V1 reimplemented ~70% of what Claude Code provides natively. The platforms have
converged — Claude Code, Agent SDK, and every major framework now offer agent
loops, tool management, subagents, session management, and lifecycle hooks.

**Furrow's job is not to provide infrastructure.** It is to define:

- **What** work looks like (decomposition and definition)
- **How** to evaluate work (eval framework)
- **Where** context lives and how it flows (context architecture)
- **When** to involve humans or specialized reviewers (quality gates)

Everything else should be delegated to the platform. If Furrow is doing
something Claude Code or the Agent SDK already does, that component should be
deleted.

The convention layer includes an **enforcement skeleton built from platform
primitives**:

- **Hooks** (Claude Code) and **callbacks** (Agent SDK) for event-driven enforcement
- **Schema validation** for structural enforcement of work definitions and progress files
- **Subagent/team boundaries** for context isolation and generator-evaluator separation
- **Permission scoping** for work-scoped trust levels

These are platform-native, lightweight, and deletable. They ARE conventions —
declarative lifecycle bindings, not a custom engine. The false binary is "custom
framework vs. file conventions" when the actual spectrum includes conventions
enforced by platform primitives.

### 2. The Dual-Runtime Constraint Forces Abstraction Above the Runtime

Claude Code (interactive, human-in-loop, skills/hooks) and Agent SDK
(autonomous, programmatic, callback-based) are fundamentally different execution
models. The only way to serve both is to define Furrow at a level *above*
the runtime:

- Work definitions (what needs to be done)
- Quality criteria (what "done" means)
- Context contracts (what information is needed)
- Eval specifications (how to measure outcomes)

These are all **declarative**. The runtime-specific binding — how a Claude Code
skill loads a work definition vs. how an Agent SDK program loads the same
definition — is a thin adapter, not a core concern.

### 3. Eval-First Means Evals Define Behavior

The eval-first constraint and the spec-driven development trend converge: the
eval *is* the specification. You don't write a spec and then write an eval for
it. You write an eval that defines what correct behavior looks like, then
optimize prompts against it.

This simplifies the stack: **eval** (authoritative, runnable) + **description**
(explanatory, for humans) + **prompt** (operational, for the model). The eval is
the source of truth. The description explains intent. The prompt is optimized
against the eval. No prose spec to maintain separately.

The Red Hat finding reinforces this: "the approach only appeared to work because
we had overfit the prompt to our limited manual tests." Without evals, you can't
distinguish working from appearing-to-work.

Evals define behavior — build them first. The bootstrap sequence is accelerated:

- **Phase 0**: Existence checks + trace infrastructure (trace is a fixed cost that blocks behavioral evals — build it first)
- **Phase 1**: Deterministic + behavioral trace evals
- **Phase 2**: LLM-judge gating + cross-model eval
- **Phase 3**: Calibration refinement + self-evolving eval proposals
- **Phase 4**: Deletion testing of harness components against eval suite

### 4. Context Tiers Are Real But Should Map to Management Mechanisms

The three-tier observation from v1 experience is valid:

| Tier | Lifespan | Examples |
|------|----------|----------|
| Ambient | Months | Conventions, architecture, tool config |
| Scoped | Days–weeks | Current work definition, specs, design decisions |
| Ephemeral | Hours | Progress logs, intermediate results, checkpoints |

The key refinement: each tier should map to a different **management mechanism**
and **storage location**, not just a different lifespan:

- **Ambient** → CLAUDE.md + hooks + skill metadata (platform-native, auto-loaded)
- **Scoped** → structured files in a work directory (Furrow-managed, loaded at work start)
- **Ephemeral** → conversation context + task system + worktree state (platform-native, session-bound)

Furrow owns the middle tier. The platform owns the other two.

### 5. Generator-Evaluator Separation is the Core Architectural Principle

The seed research is overwhelming: self-review fails, structural separation
works. Agents "confidently praise mediocre work." Tuning a standalone evaluator
to be skeptical is "far more tractable than making a generator critical of its
own work."

Structural separation is the default for all non-trivial work. The evaluation
depth (single-model vs cross-model, deterministic vs LLM-judge) scales with task
complexity, but the separation itself is non-negotiable.

Evaluator calibration is tractable, ongoing work. "Out of the box, Claude is a
poor QA agent." It takes several rounds of reading evaluator logs, finding
judgment divergences, and updating the QA prompt. The tuning process took
"several rounds" — this is investment that pays off.

### 6. Work Decomposition Should Be Outcome-Based, Not Process-Based

The seed research warns against prescribing implementation approach:
"Constrain the agents on the deliverables to be produced and let them figure
out the path." Over-specification hurts. Sprint contracts useful for Opus 4.5
were unnecessary for Opus 4.6.

But *no* structure leads to one-shotting and premature victory. The minimum
viable structure:

1. **Feature enumeration** — explicit list of deliverables (prevents one-shotting)
2. **One-at-a-time discipline** — work on one deliverable before starting the next
3. **Progress tracking** — explicit completion claims, subject to evaluation
4. **Evaluation at boundaries** — each deliverable evaluated before the next begins

This defines *what* and *when*, not *how*. The model chooses its own decomposition
strategy within these guardrails.

### 7. The Harness Should Be Mostly Files

The dual-runtime constraint + thin convention layer + file-based inter-agent
communication pattern all converge: **Furrow is primarily a set of file
conventions**, not a software system.

- Work definitions: files
- Eval specifications: files (runnable — pytest, shell scripts)
- Context: files
- Progress tracking: files (structured — JSON or YAML)
- Quality gate results: files

The code component — eval runners spanning two runtimes, two trace formats,
calibration storage, and unified results — is what it needs to be, measured by
whether it works, not by line count.

### 8. Design for Deletion, Not Extension

Every component encodes an assumption about what the model can't do on its own.
Those assumptions have a half-life. Furrow should be designed so that
removing any component is easy and low-risk:

- Each component has a "this exists because [model limitation]" annotation
- Removal is tested by: delete the component, run evals, see what breaks
- If evals still pass, the component is no longer needed

The space of useful harness components doesn't shrink as models improve — it
*moves*. Design for that movement, not for permanence.

---

## Decision Dependency Map

Decisions are not independent. Some constrain others:

```
┌──────────────────────────────────┐
│  What is Furrow?            │  ← Foundational: defines identity
│  (Platform boundary)             │
└──────────┬───────────────────────┘
           │ constrains
           ▼
┌──────────────────────────────────┐
│  How does work flow through it?  │  ← Structural: defines the core loop
│  (Decomposition + Context)       │
└──────────┬───────────────────────┘
           │ constrains
           ▼
┌──────────────────────────────────┐
│  How do you know it's working?   │  ← Validation: closes the loop
│  (Eval architecture)             │
└──────────┬───────────────────────┘
           │ informs
           ▼
┌──────────────────────────────────┐
│  Derived decisions               │
│  - Quality gate depth            │
│  - Agent coordination patterns   │
│  - Evolution/maintenance model   │
└──────────────────────────────────┘
```

**Sequence**: Resolve the platform boundary first. Then design work/context
flow. Then build the eval architecture. Quality gates, coordination, and
evolution follow naturally.

---

## Key Tensions to Resolve

### Tension 1: Structure vs. Adaptability

More structure prevents failure modes (one-shotting, premature victory, context
anxiety). Less structure lets the model adapt to what it discovers and improves
across model generations. The seed research shows both extremes failing —
v1's 849-line context injection was too much; zero structure leads to
one-shotting.

**Resolution direction**: Minimal structural guardrails (feature list, progress
tracking, evaluation gates) without prescribing implementation approach.
Structure should be *outcome-shaped*, not *process-shaped*.

### Tension 2: Thin vs. Useful

The research identifies real gaps that neither platform fills (eval
infrastructure, work-level context management, generator-evaluator enforcement).
Being too thin means Furrow doesn't actually help. Being too thick means it
reimplements the platform.

**Resolution direction**: Furrow provides conventions + enforcement skeleton
from platform primitives. Platform-native enforcement (hooks, callbacks, schema
validation) IS convention — it's declarative lifecycle binding, not custom code.
Furrow uses platform primitives for enforcement where failure severity is
High or Critical.

### Tension 3: Eval Rigor vs. Bootstrap Cost

Eval-first is a hard constraint, but a comprehensive eval suite for agentic
behavior is expensive to build. You can't have evals before you have something
to evaluate, creating a chicken-and-egg problem.

**Resolution direction**: The eval framework is designed for rapid deployment,
not incremental growth over weeks. The accelerated bootstrap sequence:

- **Phase 0**: Existence checks + trace infrastructure (trace is a fixed cost that blocks behavioral evals — build it first)
- **Phase 1**: Deterministic + behavioral trace evals
- **Phase 2**: LLM-judge gating + cross-model eval
- **Phase 3**: Calibration refinement + self-evolving eval proposals
- **Phase 4**: Deletion testing of harness components against eval suite

### Tension 4: Single-Model Simplicity vs. Cross-Model Robustness

Cross-model review finds 3-5x more bugs. A Claude+Gemini pair captures 91% of
diversity benefit.

**Resolution direction**: Cross-model review is the DEFAULT evaluator
configuration for non-trivial work. Single-model only for trivial work covered
by deterministic tests. Cost is an eval metric (detecting waste, comparing
patterns) — not a decision factor for choosing defaults (flat-rate plan makes
token cost zero). The eval framework measures whether cross-model is paying for
itself — if single-model catches the same issues for a given work type, downgrade
for that type.

### Tension 5: Human-in-Loop vs. Autonomous

Furrow must work interactively (Claude Code, human present) and
autonomously (Agent SDK, human absent). These have different trust models,
different failure modes, and different quality requirements.

**Resolution direction**: Same work definitions, same evals, same enforcement
skeleton. The only variable is a **gate policy**: does this gate pause for human
input, or proceed automatically? Three levels:

- **Supervised**: All gates human-mediated
- **Delegated**: Human approves work definition, execution autonomous
- **Autonomous**: All gates automated, human reviews final artifact

The dual-runtime difference (Claude Code vs Agent SDK) is an implementation
detail of how gates pause (conversation prompt vs queue), not a fundamental
architectural split.

---

## What This Means for Architecture

The research points toward a harness that is:

1. **Declarative**: Mostly files (work definitions, eval specs, context docs)
2. **Convention-enforced**: File conventions + enforcement skeleton from platform primitives (hooks, callbacks, schema validation, subagent boundaries)
3. **Eval-anchored**: Every behavioral expectation has a runnable eval; accelerated bootstrap deploys all eval levels early
4. **Platform-native**: Uses Claude Code skills/hooks and Agent SDK hooks/tools directly — enforcement IS the platform
5. **Multi-agent by default**: Specialist agents + cross-model evaluation for 2+ deliverable work; single-agent for 1-deliverable or tightly-coupled supervised mode
6. **Outcome-shaped**: Defines *what* and *how good*, not *how*
7. **Deletable**: Each component annotated with its rationale and testable for continued necessity

The detailed analysis of each decision area follows in companion documents:

- [Platform Boundary Analysis](findings-platform-boundary.md) — what Furrow is and isn't
- [Work & Context Architecture](findings-work-and-context.md) — decomposition, context flow, coordination
- [Eval Architecture & Quality Gates](findings-eval-and-quality.md) — eval strategy, quality calibration, bootstrapping
