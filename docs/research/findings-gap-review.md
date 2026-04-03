# Gap Review: Stress-Testing the Research Findings

The four findings documents are strong as architectural analysis. They correctly identify the seven platform gaps, articulate the convention-layer identity, and design an eval framework with real depth. But they were derived from principles — what should work in theory. This review stress-tests them against what goes wrong in practice when models are the ones following the conventions.

The central question for each proposal: **what happens when the model doesn't do this?**

---

## Enforcement Gap Summary

| Gap | Convention as Proposed | Failure Mode | Severity | Recommended Enforcement |
|-----|----------------------|--------------|----------|------------------------|
| Workflow entry | Model reads work def at session start | Model skips it, goes straight to coding | **Critical** — harness bypass | **Hard gate**: hook/callback loads work context before first tool call |
| One-at-a-time discipline | Advisory convention in work def | Model parallelizes or one-shots | High — scattered progress, eval meaningless | **Procedural backstop**: progress.json schema enforces single active deliverable; hook validates before tool calls that modify code |
| Completion claims | Model writes "done" to progress.json | Model never writes it, or writes it prematurely | High — eval never triggers or triggers on incomplete work | **Procedural backstop**: hook detects completion claim and triggers eval; eval gate blocks next deliverable until current passes |
| Eval trigger | Model signals completion | Model doesn't signal; keeps working past boundary | High — quality drift, no feedback loop | **Hard gate**: completion claim in progress.json is the trigger; no claim = periodic check hook after N tool calls |
| Work summary update | Model updates at deliverable completion | Session ends without update | Medium — next session starts blind | **Procedural backstop**: hook at session end / compaction auto-generates summary from progress.json + recent file changes |
| Context discipline | Model loads work summary, retrieves on demand | Model reads entire codebase upfront; context fills | Medium — context anxiety, compaction destroys state | **Proactive structural**: hook enforces progressive loading at session start; correction limit prevents spiral accumulation; deliverable sizing keeps scope tractable; no reactive monitoring |
| Self-scoping quality | Model writes appropriately-scoped work def | Model skips def entirely or under-scopes | **Critical** — harness provides zero value without a work def | **Hard gate**: work def must exist and validate against schema before work begins; in supervised mode, human approves scope |
| Progress file integrity | Model maintains honest progress state | Model fabricates progress, marks things done that aren't | High — eval may not catch fabricated claims if eval criteria are weak | **Procedural backstop**: eval runs against actual artifacts, not progress claims; progress.json is a trigger, not evidence |
| Deliverable execution isolation | Single-agent accumulates all context | Context bloat, correction spiral pollution, no fresh-context eval | High — cascading failures across deliverables | **Structural default**: multi-agent team for 2+ deliverable work; specialist per deliverable, parallel by default, coordinator manages lifecycle |
| Cross-model evaluation | Single-model evaluator shares generator's blind spots | Correlated failures pass review | High — false confidence in output quality | **Structural default**: cross-model eval (Claude + Gemini) for 2+ deliverable work; single-model only for trivial work |
| Agent specialization | Generic executor for all deliverables | Domain-specific issues missed; generalist reasoning | Medium — lower quality, more correction cycles | **Convention in work def**: deliverables map to specialist types; coordinator selects appropriate specialist |
| Evaluator calibration bootstrap | Iterative human review of LLM-judge outputs | No outputs exist yet to review; chicken-and-egg | Medium — delays eval maturity | **Bootstrap path**: LLM-judge gates from first use; harness's own development provides calibration corpus; wrong calls fixed by improving judge prompt, not downgrading to advisory |

---

## 1. The Entry Problem

The findings describe what happens _inside_ the workflow but are thin on how the model enters it. This is the most critical gap.

**In Agent SDK mode**, entry is clean — the program loads the work definition, injects it as system context, and controls the agent loop. The model starts inside Furrow because the program put it there.

**In Claude Code mode**, the model has full agency. A skill or hook can inject the work definition, but nothing prevents the model from treating it as reference material it reads once and then ignores. The Anthropic blog documents exactly this: instructions fade over long context horizons.

**Minimum enforcement**: A session-start hook (or skill invocation) that loads the work definition and current progress state into the conversation. This is necessary but not sufficient — the model must also _stay_ in the workflow. The real backstop is the eval gate: even if the model drifts during execution, it cannot claim completion without triggering evaluation. The entry hook gets the model oriented; the eval gate keeps the output honest.

**What this means for the architecture**: Furrow needs a concept of "active work" — a session is either operating within a work definition or it isn't. The hook at session start establishes this. The progress.json file is the persistent proof. If no work definition is active, Furrow conventions don't apply (the model is just doing ad-hoc work, which is fine).

## 2. The Enforcement Spectrum

The findings position Furrow as "conventions, not engine." This is the right identity, but "convention" spans a wide range. The key insight the findings miss: there are three enforcement levels available, not two.

**Level A — Structural convention** (tools respect it automatically): `.editorconfig`, `tsconfig.json`, progress.json schema validation, subagent context isolation. The model doesn't choose to follow these; the tooling or architecture enforces them. Furrow should use this level wherever possible — schema validation on work definitions and progress files, directory structure conventions that tools expect, and subagent boundaries that enforce context isolation and generator-evaluator separation by construction.

**Level B — Event-driven enforcement** (hooks/callbacks at decision points): This is where Claude Code hooks and Agent SDK callbacks shine. Not front-loaded instructions that fade, but reminders injected at the moment of decision. The Anthropic blog and paradigm-shift doc both validate this: event-triggered system reminders at decision points outperform passive instructions. Furrow should use this for: eval triggering at completion claims, context loading at session start, progress validation before proceeding to next deliverable.

**Level C — Advisory convention** (model chooses to follow): CLAUDE.md instructions, work definition constraints, process guidance. The model may or may not comply. Furrow should use this only for things where non-compliance is tolerable or where the behavior is too contextual to enforce procedurally.

**The findings implicitly treat most conventions as Level C.** The gap review's primary recommendation is to promote critical conventions to Level A or B:

- Work definition existence → Level A (schema validation, hard gate)
- Completion claims → Level A (structured file, not free-form)
- Generator-evaluator separation → Level A (eval runs as cross-model agent, structurally isolated from execution context and model)
- Parallel execution of independent deliverables → Level A (coordinator reads dependency graph, spawns specialists concurrently)
- Context isolation per deliverable → Level A (specialist-per-deliverable, context bounded by agent lifetime)
- Eval at boundaries → Level B (hook triggers on progress.json mutation)
- Work summary at session end → Level B (hook auto-generates)
- Context loading within a subagent → Level C (advisory; specific context pointers encourage targeted reads)
- Implementation approach → Level C (advisory, outcome-based eval catches problems)

## 3. Model Capability Assumptions

The findings state "design for deletion — each component encodes an assumption about model limitations." But several load-bearing assumptions are unstated.

**Assumption: Models will follow multi-step conventions without procedural enforcement.** Current evidence says no. The Anthropic blog documents that even with JSON state tracking (more tamper-resistant than markdown), models still attempt to smooth over failures rather than follow the prescribed recovery process. Convention adherence degrades with context length. This assumption is the one most likely to be wrong for current models and most important to get right.

**Assumption: A work definition file will shape behavior as effectively as v1's active step management.** V1 injected 849 lines of context to keep the model on track — excessive, but it worked directionally. Replacing that with a file the model reads once is a bet on model capability that the seed research doesn't support. The work definition needs to be _re-injected_ at decision points (Level B enforcement), not just available.

**Assumption: Outcome-based guardrails are sufficient without process guardrails.** The findings argue for "constrain deliverables, not process." This is correct as a design principle but insufficient as an enforcement strategy. If the model one-shots all deliverables in a single pass, the outcome eval runs once at the end against an unstructured blob. The eval architecture assumes deliverables are completed and evaluated sequentially. Process guardrails — specifically, the one-at-a-time discipline enforced at Level B — are necessary for the outcome-based eval architecture to function.

**Assumption: The model will self-report progress accurately.** Progress.json is the lynchpin. It triggers evals, tracks state across sessions, enables the work summary. If the model doesn't update it, or updates it dishonestly, Furrow loses its feedback loop. The mitigation: evals verify artifacts, not claims. Progress.json is a trigger mechanism and index, not evidence. The eval itself checks whether the deliverable actually exists and works.

## 4. Implicit Scaling Needs a Procedural Floor

The implicit scaling proposal — same format for everything, deliverable count _is_ the tier — is elegant. But it has an unaddressed failure mode at both ends.

**At the simple end**: The model skips the work definition entirely. A one-line bug fix doesn't feel like it needs a definition file, deliverables, and eval criteria. The model will just fix the bug. This is arguably fine — the overhead of creating a work definition for trivial work exceeds the value. **Furrow should explicitly support this**: work below a complexity threshold doesn't need a work definition. The threshold is the model's judgment in supervised mode, and a simple heuristic (e.g., estimated changes touch ≤2 files) in autonomous mode.

**At the complex end**: The model under-scopes. Writing 3 vague deliverables for a 10-deliverable initiative is the default failure mode. In supervised mode, the human catches this. In autonomous mode, nothing does.

**Minimum enforcement**: In autonomous mode (trust levels 2-3), the work definition should pass a structural validation: deliverables have concrete eval criteria, eval files exist or are generated, and a "scope check" eval (LLM-as-judge) reviews whether the decomposition is appropriately granular for the stated objective. This is a Phase 0 eval that runs before work begins.

## 5. Context Management Should Be Proactive, Not Reactive

The findings propose "Furrow makes session boundaries safe" via an always-current work summary. This treats the symptom. The actual problem is uncontrolled context growth. If context is managed well, unplanned boundaries (compaction, crash, user closes terminal) are cheap to recover from because work state lives in files, not conversation history. Furrow should focus on not filling context uncontrollably in the first place.

### Root causes of context bloat

Context doesn't fill itself. Specific behaviors fill it, and each has a structural prevention:

**1. Bulk file reads.** The model reads entire files (or multiple files) when it needs a few functions. This is the single largest context consumer in typical sessions. The findings propose "load exactly the context relevant to this row" but offer no mechanism to encourage it.

_Prevention_: The work definition's context pointers should reference specific symbols or sections, not whole files. Skills and hooks that set up the session should model targeted retrieval — the initial context injection reads the work summary and progress state, demonstrating the pattern of small, specific reads. Advisory guidance in ambient context (CLAUDE.md) reinforces "use targeted tool calls." This is Level C (advisory) but the structural encouragement — context pointers that are specific, not broad — makes the targeted pattern the path of least resistance.

**2. Verbose tool output accumulation.** Tool results (compiler errors, test output, grep results) can be large and accumulate across iterations. Each correction cycle adds another round of full output.

_Prevention_: Tool output is ephemeral by nature — it belongs in the session tier, not the work tier. The key defense is the correction limit (behavior #5 in the catalog): after N failed eval or fix cycles on one deliverable, the model pauses rather than accumulating more verbose output. This is a Level B enforcement (hook-enforced limit). Beyond the correction limit, Furrow can't control tool output size — that's a platform concern. But it can prevent the spiral that generates unbounded amounts of it.

**3. Correction spiral accumulation.** Each failed attempt leaves its reasoning, diffs, error messages, and retry logic in context. After 3-4 cycles, the correction history may dominate the window.

_Prevention_: Same mechanism as above — the correction limit is the structural answer. The limit isn't monitoring context size and reacting; it's preventing the spiral from running long enough to become a context problem. The hook enforces the limit regardless of context state.

**4. Over-eager context loading at session start.** The model loads "everything it might need" rather than what it needs right now.

_Prevention_: The session-start hook loads exactly the work summary (~200-500 tokens) and nothing else. This is a Level B enforcement — the hook controls what's injected, and the model retrieves additional context on demand via tool calls. Progressive loading is the default because the hook makes it the default, not because the model chooses it.

### Deliverable sizing as context-aware scoping

If a deliverable is too large for the context window, no amount of context discipline helps — the model will need to read more code, run more iterations, and accumulate more tool output than the window can hold. This is the missing link that makes implicit scaling context-aware.

The connection: deliverable granularity should be informed by context capacity. A deliverable that requires understanding 20 files, making changes across 10, and running 5 rounds of test-fix iteration will fill a context window regardless of loading discipline. That deliverable needs to be decomposed further.

This doesn't require the model to estimate context budgets explicitly — that's fragile and model-dependent. Instead, it's a scoping heuristic: **a deliverable should be completable in a single focused session.** If the model (or human, in supervised mode) can't envision completing a deliverable without needing to "load a lot of code" or "do many rounds of iteration," it's too large. The scope-check eval (§4) can incorporate this: does each deliverable look completable in one pass, or does it require deep cross-cutting context?

This reframes the context management problem as a scoping problem. Furrow doesn't monitor context and react — it encourages deliverables small enough that context management is tractable, then relies on the correction limit as a backstop if a deliverable turns out to be larger than expected.

The deepest structural answer to context management is the multi-agent team model (§6). When each deliverable executes in its own specialist's context, context bloat becomes a per-specialist problem bounded by agent lifetime — not a cumulative problem across the entire row. Parallel execution of independent deliverables compounds the benefit: three specialists running concurrently each have their own context window. Deliverable sizing still matters (a single deliverable can fill its specialist's context), but the blast radius is contained.

### What survives from the original analysis

- **Work context stays in files, not conversation history.** The work definition, progress state, and eval results are on disk. The model reads them via tools. If context compacts, the files survive. This is the single most important context management principle — it makes unplanned session boundaries recoverable rather than catastrophic.

- **Progressive loading is the default.** At session start: load work summary (~200-500 tokens). Everything else — codebase, full work definition, previous eval results — retrieved on demand via tool calls. The hook at session start enforces this by injecting the summary and nothing else.

- **Work summary auto-generation is a Level B enforcement.** A hook at deliverable completion (or session end, or compaction event if detectable) generates the summary from progress.json and recent file state. The model doesn't need to remember to do this. The model _can_ write a better summary if it chooses, but the auto-generated one is the floor.

### What's removed

The "context at 70% — consider completing current deliverable" warning is removed. It induces the context anxiety behavior documented in the Anthropic blog: the model rushes to close work, writes a superficial completion claim, and either evaluates half-finished work or skips eval entirely. A reactive warning that tells the model "you're running out of room" creates exactly the panic behavior Furrow is designed to prevent. If the proactive mechanisms (targeted loading, correction limits, deliverable sizing) work, the warning is unnecessary. If they don't, the warning makes things worse.

## 6. Multi-Agent Execution as the Default Model

The findings treat multi-agent coordination cautiously — defaulting to single-agent with multi-agent as an opt-in for special cases. This undersells the strongest structural mechanism available. Both runtimes have first-class support for agent teams (Claude Code teams / Agent tool; Agent SDK nested spawning). The seed research is clear on quality grounds: centralized multi-agent achieves **4.4x error containment** vs 17.2x for independent agents, **90.2% improvement** on research tasks, and **90% time reduction** from parallelization. Token cost is not a constraint on flat-rate plans. The decision is made on quality and reliability.

For any work with 2+ deliverables, the default execution model is a **multi-agent team**.

### The four-role architecture

The Anthropic blog validates a planner-generator-evaluator separation. Furrow extends this into four roles:

**Planner.** Reads the objective and produces the work definition: deliverables with eval criteria, dependency graph, specialist assignments, and context pointers. The planner's output is the contract. In supervised mode, the human collaborates on planning. In delegated mode, the planner's output is what the human approves at the handoff moment (§7). In autonomous mode, the planner operates independently — the scope-check eval (§4) validates its output.

**Coordinator (lead).** Manages execution flow: reads the work definition, spawns specialists (in parallel where dependencies allow), tracks progress.json, handles failures, synthesizes results. The coordinator's context stays lean — it holds the work definition, progress state, and specialist result summaries, never the accumulated execution context.

**Specialist executor(s).** Domain-specific agents that implement deliverables. An `auth-specialist` reasons differently about an authentication deliverable than a generic executor. A `database-architect` catches different issues in a schema migration than a generalist would. The work definition maps deliverables to agent specializations — either explicitly (specialist field per deliverable) or by the coordinator choosing specialists based on deliverable content.

**Evaluator.** Fresh-context review of each deliverable against its eval criteria. Receives only the output artifacts and eval spec — structurally isolated from execution reasoning. Cross-model by default for 2+ deliverable work (see below).

The planner and coordinator can be the same agent when appropriate — in supervised mode, the human + agent plan together and the agent coordinates. But they are distinct _roles_ with distinct concerns, and for autonomous work they should be distinct agents to prevent planning bias from influencing coordination decisions.

### Parallel by default, sequential by exception

Independent deliverables execute in **parallel by default**. The work definition annotates dependencies between deliverables; anything without a dependency runs concurrently. The 90% time reduction from the seed research comes from this.

The coordinator's job: read the dependency graph from the work definition, identify the parallelizable frontier, spawn specialists concurrently for independent deliverables, and sequence dependent deliverables. Sequential execution is for deliverables with explicit dependencies, not the default mode.

```
Deliverables:  [A] ──→ [C] ──→ [E]
               [B] ──→ [D] ──╱

Execution:     Wave 1: A, B (parallel)
               Wave 2: C, D (parallel, after A, B respectively)
               Wave 3: E (after C, D)
```

Each specialist in a wave runs in its own context with its own deliverable's context pointers. The coordinator spawns the wave, collects results, runs evals, then spawns the next wave.

### Specialist agents, not generic executors

The specialization benefit is not optional overhead — it's a quality mechanism. Agents named and prompted for their domain produce measurably different output:

- A `security-specialist` reviewing an auth flow will probe for token leakage, CSRF, and session fixation. A generic executor implements the feature and moves on.
- A `database-architect` designing a schema migration considers index impact, query plans, and backwards compatibility. A generic executor writes the migration.
- A `frontend-specialist` building a component considers accessibility, responsive behavior, and interaction states. A generic executor renders the markup.

The work definition supports specialist assignment:

```yaml
deliverables:
  - name: "auth-token-rotation"
    specialist: "security-specialist"
    # ...
  - name: "session-schema-migration"
    specialist: "database-architect"
    # ...
```

If no specialist is specified, the coordinator chooses based on deliverable content — or uses a generalist for work that doesn't benefit from specialization.

### Cross-model evaluation as the default

The seed research shows Claude + Gemini captures **91% of a five-model ceiling** with barely overlapping weakness profiles. On flat-rate plans, the cost argument against cross-model review disappears. Single-model evaluation is a known weak point — correlated blind spots mean the evaluator misses what the generator missed.

For 2+ deliverable work, the default evaluator configuration is **cross-model**: the eval subagent uses a different model than the specialist that produced the work. The eval spec in the work definition supports this:

```yaml
evaluation:
  models: ["claude", "gemini"]  # default: cross-model
  # models: ["claude"]          # single-model for trivial work
```

Single-model eval is the lightweight option for 1-deliverable or trivial work where deterministic evals (tests pass, code compiles) carry most of the verification load.

### What multi-agent execution solves structurally

The same structural benefits identified earlier, now amplified by specialization and parallelism:

**Context protection (§5).** Each specialist has its own context window containing only its deliverable's context. The coordinator never accumulates execution context. Context bloat is bounded per-specialist, not cumulative across the row.

**Generator-evaluator separation.** The cross-model eval subagent receives only output artifacts and criteria — structurally isolated from the specialist's reasoning _and_ using a different model with different blind spots. This is the strongest evaluation configuration available.

**Correction spiral containment.** When a specialist spirals, the coordinator kills it. The failed attempts die with the specialist's context. The coordinator spawns a fresh specialist (possibly a different one) with a clean window and a note about what failed.

**Quality through specialization.** Domain-prompted agents catch issues that generalists miss. The `security-specialist` doesn't need to be told to check for CSRF — its domain priming makes it default behavior.

**Speed through parallelism.** Independent deliverables execute concurrently. A 5-deliverable row with 3 independent deliverables completes in 3 waves instead of 5 sequential steps.

### Agent teams as the coordination primitive

Both platforms provide team-level primitives that Furrow should use directly:

- **Claude Code**: The teams feature manages agent composition, communication, and lifecycle. The work definition maps to a team: coordinator + specialists + evaluator.
- **Agent SDK**: Nested agent spawning with programmatic lifecycle control. The coordinator program spawns specialist agents and eval agents.

Furrow's team convention: the work definition specifies (or the coordinator derives) a **team composition** — which specialists are needed, how many can run in parallel, and what eval configuration to use. The coordinator manages the team, not individual spawn/kill cycles.

### Where single-agent remains appropriate

- **1-deliverable work.** No team needed. The model executes directly. Eval still runs as a separate agent (cross-model evaluation is valuable even for single deliverables when the work is non-trivial).
- **Supervised mode with tight human interaction.** When the human is actively pair-programming on each step, team delegation adds latency. The human provides the context protection and quality review directly.

### Interaction with the trust gradient

The team model works identically across trust levels. The coordinator interacts with gate policies:

- **Supervised**: The human collaborates with the planner on the work definition. The coordinator consults the human before spawning each wave. The human sees results as specialists report them.
- **Delegated**: The planner produces the work definition; the human approves it (the handoff moment). The coordinator runs autonomously, spawning specialists and evaluators. The human reviews final artifacts.
- **Autonomous**: The planner and coordinator operate independently. All gates automated. Human reviews final artifact (PR, evidence package).

The trust gradient's gate policy attaches to the coordinator, not to specialists or evaluators. The team's internal operation is an implementation detail.

## 7. The Trust Gradient

The findings frame the dual-runtime constraint as "Claude Code vs Agent SDK" with parallel adapters. This misses the actual operational model: a trust gradient where the human progressively withdraws.

| Level | Preparation | Execution | Review | Gate policy |
|-------|------------|-----------|--------|-------------|
| **Supervised** | Human + agent | Human + agent | Inline | All gates human-mediated |
| **Delegated** | Human + agent | Autonomous | Artifact review | Prep gate human, execution gates automated |
| **Autonomous** | Agent or trigger | Autonomous | PR review | All gates automated, human reviews final artifact |

**Key implications for the furrow:**

The agent behaves identically at every level. Same work definitions, same eval gates, same progress tracking. The only variable is a **gate policy**: does this gate pause for human input, or proceed automatically? This is a configuration parameter on the work definition, not an architectural split.

The "handoff moment" in delegated mode is architecturally significant. The human approves the work definition and eval criteria as a contract, then autonomous execution begins. This approval gate needs first-class representation — it's the point where the human certifies that the scope and success criteria are correct, which is the prerequisite for trusting autonomous execution.

The artifact contract intensifies at higher trust levels. At supervised, the human sees everything. At autonomous, the human reviews artifacts — the work summary, eval results, code diff, and any flagged issues. The minimum evidence package that enables meaningful review without re-executing the work is: final progress.json, all eval results, the generated work summary, and the git diff.

**Revision to Tension 5**: "Human-in-Loop vs Autonomous" should be reframed as "Trust Level Configuration." The dual-runtime adapters are thinner than proposed — same adapter, different gate policies. The runtime difference (Claude Code vs Agent SDK) is an implementation detail of how gates pause (conversation prompt vs queue), not a fundamental split.

## 8. The Calibration Bootstrap

The eval architecture proposes iterative calibration of LLM-as-judge evaluators, but faces a circular dependency: calibration needs human-reviewed outputs, which need Furrow producing work, which may need calibrated evaluators.

The resolution: LLM-judge gates from first use. Calibration is ongoing improvement, not a prerequisite for gating. The bootstrap corpus comes from Furrow's own development.

**Phase 0: Foundation (day 1)**

- Existence checks (work def has criteria, eval files exist, eval files executable).
- Trace infrastructure — normalized event format across both runtimes.
- Schema validation for work definitions and progress files.
- Zero calibration needed. This is day-1 infrastructure.

**Phase 1: Deterministic + behavioral evals (week 1)**

- Run pytest/shell evals at deliverable boundaries — gating.
- Run behavioral trace evals (one-at-a-time discipline, eval-at-boundaries, completion claims) — gating.
- Both eval types gate: work doesn't proceed until they pass.
- Use Furrow to build itself. Human-reviewed artifacts become the initial calibration corpus.

**Phase 2: LLM-judge gating + cross-model eval (week 1-2)**

- Deploy LLM-judge as **gating** (not shadow, not advisory) from first use.
- Cross-model eval (Claude + Gemini) as default for 2+ deliverable work.
- Calibration tracking from day 1: store all judge outputs with inputs and grades.
- If the judge makes a wrong call, fix the judge prompt — don't downgrade to advisory.
- Compare cross-model vs single-model catch rates per work type.

**Phase 3: Calibration refinement**

- Systematic comparison of LLM-judge output to human judgment.
- Update judge prompts to close gaps.
- System proposes new evals based on observed failure patterns (human-in-loop approval).
- Track calibration metrics over time.
- Remove process evals that models now handle natively.

**Phase 4: Deletion testing**

- Periodically remove harness components and run full eval suite.
- If evals still pass — component is no longer needed, delete permanently.
- Test whether cross-model adds value over single-model for each work type.
- Test whether specialist agents add value over generalists for each work type.

The key difference from a gradual ramp-up: deterministic and behavioral evals gate from day one, and the LLM-judge gates from its first deployment in Phase 2 — never in shadow or advisory mode. Wrong calls are fixed by improving the judge prompt, not by retreating to a weaker enforcement level. Calibration is continuous improvement of a gating system, not a prerequisite for turning gating on.

## 9. The Missing Behavior Catalog

Insight #3 claims "evals define behavior" but the findings never enumerate the behaviors. Without a behavior list, you can't build evals, and you can't assess which behaviors need procedural enforcement. Here is a representative catalog — proof of the gap and a template for the full list.

| # | Behavior | Failure if Missing | Eval Method | Enforcement |
|---|----------|--------------------|-------------|-------------|
| 1 | Load work definition at session start | Harness bypass — model works without context | Trace: first N tool calls include work def read | **Hard gate** (hook) |
| 2 | Execute deliverables respecting dependency order | Independent work blocked behind dependencies; or dependent work starts before prerequisites complete | Trace: parallel waves match dependency graph; no dependent deliverable starts before prerequisite completes | **Structural** (coordinator reads dependency graph, spawns parallel waves) |
| 3 | Write completion claim before starting next deliverable | Eval never triggers; quality drift | Trace: completion claim precedes next deliverable start | **Procedural backstop** (hook on progress.json) |
| 4 | Run/trigger eval at completion boundary | Unevaluated work accumulates | Trace: eval execution follows each completion claim | **Hard gate** (hook auto-triggers eval) |
| 5 | Stop after N eval failures on same deliverable | Correction spiral; context pollution | Trace: count eval failures per deliverable | **Structural + procedural** (coordinator tracks failure count; kills specialist on limit; spirals contained in specialist context) |
| 6 | Update progress.json accurately | Downstream consumers (eval trigger, work summary, next session) get wrong state | Deterministic: progress.json matches actual file artifacts | **Procedural backstop** (validation hook) |
| 7 | Produce work summary at deliverable completion | Next session starts blind after boundary | Deterministic: summary file exists and is recent | **Procedural backstop** (hook auto-generates) |
| 8 | Stay within work definition scope | Scope creep; delivers unrequested features | LLM-judge: diff analysis against work def deliverables | Advisory (eval catches post-hoc) |
| 9 | Use targeted tool calls, not bulk reads | Context fills with irrelevant code; compaction destroys work state | Trace: ratio of targeted vs bulk file reads | Advisory (specific context pointers in work def encourage targeted reads) |
| 10 | Produce eval-specified artifacts for each deliverable | Eval can't run; completion claim is empty | Deterministic: eval files execute successfully against work output | **Hard gate** (eval must pass) |
| 11 | Cross-model evaluation (evaluator uses different model and fresh context) | Correlated blind spots; false passes | Trace: evaluator agent uses different model than specialist; receives only output + criteria | **Structural** (cross-model eval agent; structurally isolated from execution context and model) |
| 12 | Write work definition with testable eval criteria (autonomous mode) | Eval is meaningless; can't verify completion | LLM-judge: scope check eval reviews work def quality | **Procedural backstop** (Phase 0 eval) |
| 13 | Respect correction limit before requesting help | Infinite fix loops; wasted tokens and time | Trace: count consecutive failures before escalation | **Procedural backstop** (hook enforces) |
| 14 | Specialists: domain-appropriate agent for each deliverable | Domain-specific issues missed; generic reasoning | Trace: specialist type matches deliverable domain | **Convention** (work def maps deliverables to specialists; coordinator selects based on content) |
| 15 | Preserve work def constraints during execution | Violates tech choices, standards, or scope limits | LLM-judge: constraint compliance check | Advisory (eval catches post-hoc) |

This catalog reveals the enforcement skeleton: behaviors 1, 4, 10 need hard gates (hooks). Behaviors 2, 5, 11 are structurally enforced by the multi-agent team model — dependency-driven parallelism, specialist context isolation, and cross-model evaluation by construction. Behaviors 3, 6, 7, 12, 13 need procedural backstops (hooks that validate or auto-generate). Behaviors 8, 9, 14, 15 can survive as advisory or convention-based, with eval-based detection.

## 10. Revisions to Key Insights

**Insight #1 (Convention Layer, Not Engine)** — Upheld, but needs qualification. A convention layer without an enforcement skeleton is a README. Furrow is conventions + the minimum hooks/gates that make those conventions trustworthy. The enforcement skeleton is part of the convention layer, not a departure from it.

**Insight #3 (Eval-First Means Evals Define Behavior)** — Upheld in principle, but the behavior list the evals would test is missing. This insight is incomplete until the behavior catalog exists. The catalog is the bridge between the eval architecture and the enforcement spectrum.

**Insight #6 (Outcome-Based, Not Process-Based)** — Needs revision. Outcome-based decomposition is correct. But the eval architecture depends on sequential deliverable completion — which is a process constraint. Furrow needs minimal process guardrails (one-at-a-time, eval-at-boundaries) to make the outcome-based eval architecture function. "Outcome-based with structural process guardrails" is the accurate framing.

**Insight #7 (The Harness Should Be Mostly Files)** — Upheld and reinforced. The multi-agent team model depends on file-based communication. Specialists receive context via files, return results via files. The coordinator reads file-based progress and results. Furrow's file-centric identity enables the team architecture.

**Insight #8 (Design for Deletion)** — Upheld. The enforcement skeleton itself should be designed for deletion. Each hook encodes an assumption about model behavior that should be re-tested as models improve. Specialist agents are a deletion candidate: if future models don't benefit from domain priming, generalist execution suffices. Cross-model evaluation is a deletion candidate: if single-model self-evaluation becomes reliable, the second model adds no value. Parallelism is not a deletion candidate — it's a permanent speed advantage.

**Tension #5 (Human-in-Loop vs Autonomous)** — Reframed as trust gradient. Not two parallel modes but a single progression with configurable gate policies. The adapters are thinner than proposed.

## 11. Sharpened Open Questions

### Resolved

**Q1 (minimum hook set):** The behavior catalog (§9) identifies the hooks needed. The minimum hook set is 4-5 hooks covering: (1) session-start: load work context + validate work def schema, (2) completion-claim: validate progress.json + trigger eval, (3) eval-gate: block next deliverable until eval passes, (4) session-end: auto-generate work summary, (5) correction-limit: pause after N eval failures on same deliverable. These map to Claude Code hooks and Agent SDK callbacks.

**Q4 (work definition schema):** YAML with required fields: objective, deliverables (each with name, eval_criteria, specialist type), context_pointers, constraints, evaluation config (gate types, model config, cross-model default). Plus optional: dependency graph between deliverables, gate_policy (supervised/delegated/autonomous).

**Q5 (evidence package):** progress.json + all eval results + work summary + git diff. This is sufficient. The eval results provide the quality signal. The diff provides the change. The summary provides the narrative. The progress file provides the structured state.

**Q7 (complexity threshold for work definition):** In supervised mode, the human decides. In autonomous mode: if estimated changes touch ≤2 files AND no evaluation criteria beyond "tests pass," skip the work definition. Everything else gets a work definition. The threshold is deliberately low — the work definition overhead is small, and the cost of skipping it for non-trivial work is high.

### Genuinely Open

1. **What triggers the periodic eval check?** If the model doesn't signal completion, a fallback is needed. Is it tool-call count? Elapsed time? File-change volume? What heuristic avoids both false triggers and missed boundaries?

2. **How does the scope-check eval work in practice?** For autonomous mode, an LLM-judge reviews whether the work definition is appropriately scoped. What criteria does it use? How does it distinguish "lean but correct" from "under-scoped"?

3. **How does the auto-generated work summary compare to model-written summaries?** If the hook generates summaries mechanically from progress.json, are they sufficient for next-session orientation? Or does the model need to write richer summaries? This is testable.

4. **What are the quality metrics for multi-agent vs single-agent execution?** Error containment, eval pass rate, correction spiral frequency, deliverable-over-deliverable quality consistency, and specialist-vs-generalist defect rates should be measured early. Token usage is an eval metric for detecting waste patterns.

5. **What context does the coordinator need to carry?** The coordinator holds the work definition, progress.json, dependency graph, and specialist result summaries. How large does this get for complex work (10+ deliverables with parallel waves)? If the coordinator's own context fills, what's the recovery path?

6. **How does the work definition schema support team composition?** The schema needs: dependency annotations between deliverables, specialist type mappings, eval model configuration (default cross-model). How much is explicit in the work definition vs derived by the coordinator?

7. **What is the specialist agent definition format?** Domain specialists need system prompts that prime their reasoning. Where do these live — in Furrow as reusable agent definitions, or inline in the work definition? How many specialist types does Furrow ship with vs how many are defined per-project?

8. **How does cross-model evaluation work in practice with Agent SDK?** Claude Code can spawn agents with different models via the Agent tool. The Agent SDK's model selection is programmatic. What's the concrete mechanism for the evaluator using a different model than the specialist? Is this a harness convention or does it require platform support?
