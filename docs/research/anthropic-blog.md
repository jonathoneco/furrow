# Anthropic Blog Research — Seed Document for v2 Harness Design

> **Framing**: This document summarizes patterns from 56 Anthropic blog posts
> (anthropic.com/engineering + claude.com/blog). Three posts are especially
> central: *Effective Harnesses for Long-Running Agents* (Agent SDK
> architecture), *Harness Design for Long-Running Application Development*
> (iterative harness simplification across model generations), and *Writing
> Effective Tools for Agents — with Agents* (tool design methodology).
> These are first-party findings from Anthropic engineers. They are evidence
> to draw on critically, not directives to follow.

---

## Critical Tension: Phase-Based vs. Context-Centric Decomposition

Anthropic explicitly warns against splitting by workflow phase across agents:

> "Work should only be split when context can be truly isolated."
> — _When to use multi-agent systems_

Problematic decomposition boundaries (per Anthropic):

- Sequential phases of the same work (planning -> implementation -> testing)
- Tightly coupled components requiring constant synchronization
- Work requiring shared state management

Effective decomposition boundaries:

- Independent research paths (different domains, no shared context)
- Separate components with clean interfaces
- Blackbox verification tasks

**The nuance**: Steps within a single agent session are fine — sequential phases
are natural when one agent maintains context. The anti-pattern is spawning
separate agents for "planning" vs "implementation" of the same feature, forcing
context reconstruction. The verification subagent (blackbox testing after
completion) is the one phase-based split that Anthropic validates, because
fresh evaluator context is a feature, not a bug.

---

## Theme 1: Context as the Fundamental Constraint

Every design decision flows from finite context windows. This was the most
consistent signal across all 56 posts analyzed.

Key findings:

- Performance degrades as context fills. Models exhibit "context anxiety" —
  rushing to close work near perceived limits. (_Harness Design_)
- Context resets (fresh agent + structured artifacts) outperform compaction
  for models experiencing context anxiety — but this is model-dependent.
  Claude Sonnet 4.5 exhibited context anxiety strongly enough that compaction
  alone was insufficient. However, Opus 4.5 "largely removed that behavior
  on its own," allowing context resets to be dropped entirely. The technique
  is model-capability-dependent, not universally superior. (_Harness Design_)
- Compaction doesn't always pass perfectly clear instructions to the next
  agent — particularly when features are half-implemented. (_Effective Harnesses_)
- The guiding principle: find the smallest set of high-signal tokens that
  maximize the desired outcome. (_Context Engineering_)

Quantitative evidence:

- Tool Search: **85% context reduction** by deferring tool definitions
- Sub-agent returns: target **1-2K tokens** (vs full context dumps)
- Context editing + memory tool: **39% improvement** on agentic tasks
- Prompt caching: **90% cost reduction**, **79% latency reduction** (100K cached)
- Token-efficient tool use: up to **70% output savings**
- Long-context retrieval: 27% -> **98% accuracy** with one prompt directive

**Progressive disclosure** is the primary mitigation:

- Skills use three-tier loading: metadata (~50-100 tokens) -> full docs
  (~500-5K tokens) -> reference files (2K+ tokens)
- Tool Search marks tools `defer_loading: true`, loads 3-5 on demand
- CLAUDE.md loads up front; everything else via just-in-time retrieval


---

## Theme 2: Environmental Scaffolding Over Prompt Engineering

Structured artifacts guide behavior more reliably than natural language.

Key findings:

- "Agents need environmental scaffolding more than prompting tweaks — READMEs,
  progress files, and clean test output matter more than instruction quality."
  (_Building a C Compiler_)
- JSON resists model tampering better than Markdown for state. (_Effective Harnesses_)
- Hooks enforce rules procedurally where CLAUDE.md is advisory.
  8 hook events cover the full lifecycle. (_Hooks blog_)
- Testing is "the single highest-leverage thing you can do." (_Best Practices_)

**Note on Effective Harnesses post:** This post describes work with the Claude
Agent SDK, not Claude Code. The initializer/worker "agents" are the same agent
with different initial user prompts — not architecturally distinct agents. Per
the post's footnote: "We refer to these as separate agents in this context only
because they have different initial user prompts." The split is achievable with
prompt switching, not agent spawning.

**File-based inter-agent communication:** In the Harness Design post's
three-agent architecture, agents communicate through the filesystem: "one agent
would write a file, another agent would read it and respond either within that
file or with a new file." Agents do not share context — they share files. This
suggests file-based state as a natural inter-agent communication pattern.

The four-layer customization stack (Claude Code):

1. CLAUDE.md — declarative context (keep under 200 lines)
2. Hooks — procedural automation (8 lifecycle events)
3. Plugins — distributable bundles
4. Permissions/Sandboxing — OS-level isolation


---

## Theme 3: Scaffolding Depth Should Match Task Complexity and Model Capability

The relationship between scaffolding and quality is task-dependent and
model-dependent, not monotonic. The Harness Design post provides the most
detailed treatment: it documents the iterative process of building, testing,
and simplifying a harness across two model generations.

**The harness iteration story** (central narrative of the _Harness Design_ post):

A solo run (~$9/20min) and a V1 harness run (~$200/6hr, Opus 4.5) both built a
game level editor from the same one-sentence prompt. The solo run produced a
broken app. The harness run — planner expanding the prompt into a 16-feature
spec, generator and evaluator negotiating testable sprint contracts — produced
qualitatively superior output. "The difference in output quality was immediately
apparent."

But the blog's main contribution is what happened next:

1. **Radical simplification failed**: "I cut the harness back radically and tried
   a few creative new ideas, but I wasn't able to replicate the performance."
2. **Methodical simplification succeeded**: "removing one component at a time and
   reviewing what impact it had." Sprint constructs removed — Opus 4.6 no longer
   needed that decomposition. Evaluator moved from per-sprint to single pass.
3. **V2 harness** (Opus 4.6): ~$124/4hr for a DAW. Cost breakdown: planner
   $0.46, builds $71 + $37 + $6, QA $3-5 per round. QA is cheap relative to
   building.

"When a new model lands, it is generally good practice to re-examine a harness,
stripping away pieces that are no longer load-bearing." (_Harness Design_)

Key findings — minimal tooling wins on narrow tasks:

- SWE-bench SOTA used only: a prompt, Bash, and Edit. (_SWE-bench Sonnet_)
- Frameworks "create extra layers of abstraction that obscure the underlying
  prompts and responses." (_Building Effective Agents_)

Shared principles:

- "Every component in a harness encodes an assumption about what the model
  can't do on its own, and those assumptions are worth stress testing."
  (_Harness Design_)
- "The space of interesting harness combinations doesn't shrink as models
  improve. Instead, it moves." (_Harness Design_)
- Fewer purposeful tools beat many wrappers. (_Context Engineering_)
- Multi-agent systems consume **3-10x more tokens** than single-agent.
  (_Multi-agent Systems_)

The reconciliation: SWE-bench tests narrow, well-defined tasks (bug fixes) where
minimal tooling suffices. Complex, open-ended work (building applications) benefits
dramatically from scaffolding. "Simplicity" applies to tooling design (fewer
purposeful tools), not scaffolding removal. But scaffolding should also be matched
to model capability — what Opus 4.5 needed (sprint constructs, per-sprint
evaluation), Opus 4.6 did not.


---

## Theme 4: Generator-Evaluator Separation

Self-evaluation is unreliable. Generation and verification must be structurally
separated — but the depth of separation should match task difficulty relative to
the model's native capability.

Key findings:

- Agents "confidently praise mediocre work." (_Harness Design_)
- Tuning a standalone evaluator to be skeptical is "far more tractable than
  making a generator critical of its own work." (_Harness Design_)
- Grade outcomes, not paths. Checking step sequences is "too rigid." (_Evals_)
- "Early victory problem": verifiers declare success after minimal testing.
  Requires concrete criteria and explicit comprehensive-validation demands.
  (_Multi-agent Systems_)

**Evaluator calibration requires real effort:** "Out of the box, Claude is a
poor QA agent." The tuning process: read the evaluator's logs, find examples
where its judgment diverged from the author's, update the QA prompt. "It took
several rounds of this development loop." Implementing an evaluator is not
"spawn a fresh agent and tell it to review" — it requires iterative prompt
calibration. (_Harness Design_)

Patterns:

- Three-agent architecture: planner (high-level) -> generator -> evaluator
- Sprint contracts: testable success criteria negotiated before implementation.
  In the Harness Design post, these were useful with Opus 4.5 but were removed
  for Opus 4.6 as the model could handle coherent work without that
  decomposition level.
- Planner positive framing: "constrain the agents on the deliverables to be
  produced and let them figure out the path as they worked." (_Harness Design_)
- Verification strategies: rules-based, visual, LLM-as-judge
- "The evaluator is not a fixed yes-or-no decision. It is worth the cost when
  the task sits beyond what the current model does reliably solo."
  (_Harness Design_)

**Criteria-driven evaluation for subjective quality:** The Harness Design post
describes a frontend design experiment using four criteria: design quality,
originality, craft, and functionality. Criteria wording directly shapes output
character — phrases like "museum quality" pushed designs toward visual
convergence. This is relevant to writing review prompts: the specific words
in evaluation criteria shape the output, not just whether evaluation happens.
(_Harness Design_)


---

## Theme 5: Skills as the Specialization Primitive

Anthropic's Skills system provides the formal model for packaging procedural
knowledge.

Architecture:

- Folder-based packages with SKILL.md (YAML frontmatter + markdown)
- Semantic triggering by description quality (no keyword matching)
- Three-tier progressive loading prevents context bloat
- Composition with MCP: skills provide procedural knowledge, MCP provides
  connectivity to external systems

Key distinction: "Projects say 'here's what you need to know.' Skills say
'here's how to do things.'"

Two categories for lifecycle management:

- **Capability uplift**: teaches techniques (may become unnecessary as models improve)
- **Encoded preference**: documents workflows (remains valuable regardless)

Testing framework:

- Three-scenario matrix: normal, edge case, out-of-scope
- Benchmark mode: pass rates, time, tokens across iterations
- Multi-agent blind A/B testing


---

## Theme 6: Trust and Autonomy Tiers

A graduated permission model reduces friction while maintaining safety.

Four tiers: Default (manual) -> Auto mode (classifier) -> Sandbox (OS-level) ->
Skip (dangerous).

Auto mode specifics:

- Two-stage classifier: fast yes/no filter -> chain-of-thought only on flagged items
- Classifier sees only user messages and tool commands (assistant text stripped
  to prevent persuasive rationalization)
- **84% permission prompt reduction** from sandboxing
- 93% of manual prompts accepted anyway (approval fatigue)

Deny-and-continue pattern: block dangerous action, return guidance to find a
safer path. 3 consecutive or 20 total denials escalate to human.

Four threat categories: overeager (most common), honest mistakes,
prompt injection, misalignment (not yet observed).


---

## Theme 7: Incremental Progress and Anti-Patterns

Long-running work requires enforced incrementalism.

Key patterns:

- One feature at a time — "the next iteration of the coding agent was then asked
  to work on only one feature at a time." A session can address multiple features
  sequentially; the constraint is working on one at a time, not one per session.
  (_Effective Harnesses_)
- Initializer/worker split (note: same agent with different user prompts, per the
  Effective Harnesses footnote): first session writes requirements + progress file;
  subsequent sessions read state and work incrementally
- JSON state tracking resists model tampering
- Startup protocol: read state -> sanity test -> begin work

Primary failure modes and mitigations:

| Mode                                            | Mitigation                             |
| ----------------------------------------------- | -------------------------------------- |
| One-shotting (build everything at once)         | Feature list + one-at-a-time discipline |
| Premature victory (declare done early)          | JSON task list with pass/fail tracking |
| Context anxiety (rush near limits)              | Context resets over compaction (model-dependent) |
| Correction spiral (fixes pollute context)       | After 2 failures, clear and restart    |
| Over-specification (planner prescribes details) | Keep planning high-level               |
| Time blindness (hours on tests)                 | Capped runs, random sampling           |


---

## Theme 8: Multi-Agent Coordination Patterns

Token usage explains **80%** of multi-agent performance variance. Delegation
quality is the key bottleneck.

When multi-agent wins:

1. Context protection (irrelevant subtask context would pollute)
2. Parallelization (independent investigations) — **90% time reduction**
3. Specialization (20+ tools spanning unrelated domains)

When single-agent wins: shared context needed, many inter-agent dependencies,
simple or low-value tasks.

Production pattern (Anthropic's Research feature): Opus orchestrator + Sonnet
workers. Lead decomposes, spawns 3-5 subagents in parallel, each returns
compressed summaries. Subagent-to-filesystem output minimizes "game of telephone."

File-based inter-agent communication is the standard pattern: agents write to
files, other agents read those files. They do not share context windows.
(_Harness Design_)

Effort scaling: simple fact-finding (1 agent, 3-10 calls) -> comparisons
(2-4 subagents, 10-15 calls each) -> complex research (10+ subagents).


---

## Quantitative Summary

| Metric                               | Value                             | Source                 |
| ------------------------------------ | --------------------------------- | ---------------------- |
| Tool Search context reduction        | 85%                               | Advanced Tool Use      |
| Prompt caching cost reduction        | 90%                               | Prompt Caching         |
| Prompt caching latency reduction     | 79%                               | Prompt Caching         |
| Token-efficient tool use savings     | Up to 70%                         | Token-Saving Updates   |
| Context editing + memory improvement | 39%                               | Context Management API |
| Parallel execution time reduction    | 90%                               | Multi-Agent Research   |
| Auto mode permission reduction       | 84%                               | Sandboxing             |
| Token usage as perf predictor        | 80% of variance                   | Multi-Agent Research   |
| Multi-agent token overhead           | 3-10x vs single                   | Multi-agent Systems    |
| Multi-agent vs single on research    | 90.2% improvement                 | Multi-Agent Research   |
| Infrastructure benchmark noise       | 6pp (exceeds leaderboard margins) | Infrastructure Noise   |
| Think tool improvement (airline)     | 54% relative                      | Think Tool             |
| Tool use examples accuracy gain      | 72% -> 90%                        | Advanced Tool Use      |
| Long-context retrieval gain          | 27% -> 98%                        | Claude 2.1 Prompting   |
| Anthropic internal PRs/eng/day       | 67% increase                      | Contribution Metrics   |
| V1 harness cost (game editor)        | ~$200/6hr                         | Harness Design         |
| V2 harness cost (DAW)               | ~$124/4hr                         | Harness Design         |
| V2 planner cost                      | $0.46/5min                        | Harness Design         |
| V2 QA cost per round                 | $3-5/7-10min                      | Harness Design         |

---

