# Multi-Model Agent Architectures — Research Findings

> **Framing**: This document summarizes community patterns and academic findings
> on combining different AI models in agentic workflows. These are evidence
> to draw on critically, not directives to follow.

## The Cognitive Monoculture Problem

When the same model generates and reviews code, blind spots are correlated.
If it missed a bug during generation, it will likely miss it during review.
Research confirms self-preference bias — models rate their own output higher
than it deserves.

**Evidence:**
- Heterogeneous model ensembles achieve ~9% higher accuracy than
  same-model groups on reasoning benchmarks ([arXiv 2404.13076](https://arxiv.org/abs/2404.13076))
- Independent parallel review outperforms multi-round debate
  ([arXiv 2507.05981](https://arxiv.org/abs/2507.05981))
- Different model families catch different bug classes:
  - **Claude**: Integration issues, architectural concerns, design patterns
  - **GPT/Codex**: API misuse, type errors, logic/race conditions (lowest false-positive rate)
  - **Gemini**: Whole-repository consistency via 1M+ token context, security/scalability
- Production data from cross-model review: 3-5x more bugs detected vs
  single-pass, with only 3 false positives across 24+ rounds
  ([Zylos Research](https://zylos.ai/research/2026-02-17-multi-model-ai-code-review))

This is the core motivation: not that any model is inadequate alone, but
that model diversity catches what monocultures miss.

## Cross-Model Review Patterns (Immediately Actionable)

Three production implementations exist at increasing sophistication:

### Level 1: One-Shot Review (skill-codex)

A SKILL.md invokes `codex exec` headless from within Claude Code for
read-only review. Suppresses stderr to avoid context bloat.

- [skill-codex](https://github.com/skills-directory/skill-codex)
- Simplest integration; works today with a single skill file

### Level 2: Stop-Hook Review (claude-review-loop)

A plugin intercepts Claude's exit via a stop hook and spawns up to 4
parallel Codex reviewers (diff review, holistic review, plus
framework-detected specialists for Next.js and UX). Findings written
to `reviews/review-<id>.md`. State machine prevents infinite loops.

- [claude-review-loop](https://github.com/hamelsmu/claude-review-loop) by Hamel Husain
- Uses hook infrastructure for integration
- State machine pattern: task -> review -> addressing -> done

### Level 3: Full Loop (codex-claude-loop)

Six-phase cycle: Plan (Claude) -> Validate (Codex, read-only) -> Feedback
-> Execute (Claude) -> Cross-review (Codex) -> Iterate. Uses
`codex exec resume --last` for session continuity.

- [codex-claude-loop](https://fastmcp.me/skills/details/181/codex-claude-loop)
- Most sophisticated but highest integration complexity

### Production Orchestration (agent-mux)

[agent-mux](https://github.com/buildoak/agent-mux) dispatches across
engines via standardized JSON contracts. Real workflow: Opus plans ->
Codex (3-4 workers) executes -> Codex xhigh audits -> fixes route back
-> Opus synthesizes. Runs 30-60 minutes autonomously.

### Key Data Points

- Cost: $1-5 per 2000-line PR
- Rounds 2-4 catch fix-induced regressions invisible to single-pass review
- 60-70% of bugs found in first half of iterations
- Generator-verifier asymmetry: verification is inherently easier than
  generation, so weaker generators + strong verifiers approach the quality
  of stronger generators alone ([arXiv 2509.17995](https://arxiv.org/abs/2509.17995))

### Noise Filtering

The [claude-code-skills](https://github.com/levnikolaevich/claude-code-skills)
project implements an AGREE/DISAGREE/UNCERTAIN framework with up to 2
debate rounds. Only high-confidence (>=90%) and high-impact (>2%)
suggestions surface to users. This pattern is worth adopting to prevent
review noise from overwhelming developers.

## Routing Economics

### Savings Are Real

| Approach | Savings | Quality | Source |
|---|---|---|---|
| RouteLLM (LMSYS) | 85% on MT Bench | 95% of GPT-4 | ICLR 2025 |
| CascadeFlow | 40-85% | Maintained | Lemony |
| Frontier + cheap workers | 40-60% | No loss | MindStudio |
| AgentOpt budget combos | 21x-118x cheaper | 94-98% | Columbia |
| Production (100K/day) | $4,500 -> $1,500/mo | Maintained | FutureAGI |

Aggregate: hybrid routing delivers 80-90% of frontier quality at
25-30% of frontier-only cost.

### Per-Task-Phase Routing

Different phases of work have different model requirements:

- **Research/exploration**: Haiku — fast, read-only, volume-tolerant
- **Planning/synthesis**: Opus — highest reasoning, low token volume
- **Implementation**: Sonnet — balanced, majority of tokens spent here
- **Review**: Cross-model or Sonnet + specialized review agents

Model capabilities shift quarterly.

### The "Cheap Draft, Expensive Verify" Pattern

Widely validated. OpenAI's verification research: "falsifying a proposed
change usually needs only targeted hypothesis generation and checks."
Their deployed reviewer processes 100K+ external PRs daily. Verification
is cheaper per-token than generation.

### Model Combos as Atomic Units

AgentOpt (Columbia, March 2026) found counterintuitive results when
searching planner-solver pairs:

- Weakest planner + strongest solver outperformed strong+strong on
  HotpotQA (weak planner correctly delegated to tools)
- Budget combo achieved 94% accuracy at 118x less cost than frontier+frontier

**Implication**: optimizing each layer independently is suboptimal.
Model combos should be evaluated holistically.

## Failure Modes (Do Not Ignore)

### Error Cascading (17.2x Amplification)

Unstructured multi-agent networks amplify errors up to 17.2x vs
single-agent baselines. Errors cascade hidden behind syntactically
correct language.

### Compound Reliability

| Per-Step Reliability | 5 Steps | 10 Steps | 20 Steps |
|---|---|---|---|
| 99% | 95.1% | 90.4% | 81.8% |
| 95% | 77.4% | 59.9% | 35.8% |
| 90% | 59.0% | 34.9% | 12.2% |

Flat topologies (lead + 2-3 specialists) are safe.
Deep agent hierarchies are not.

### Coordination Breakdown (36.9% of Failures)

Study of 1,642 traces across 7 frameworks: failure rates 41-86.7%.
Categories include task/role violations, conversation resets, task
derailment, premature termination. Even with interventions, gains
were insufficient for production deployment.

### Router Collapse

Routers default to the most expensive model when prediction margins
are small (94.9% of queries on RouterBench are near-ties). Fix:
ranking-based objectives instead of scalar prediction.

### Token Explosion

Agents consume 10-50x more tokens via iterative reasoning. One
company went from $5K/month to $50K/month between prototype and
staging. Gartner predicts 40%+ of agentic AI projects will be
canceled due to hidden costs.

## Integration Infrastructure

### MCP Servers (Recommended Path)

MCP servers are the lowest-friction integration from Claude Code:

| Server | Purpose |
|---|---|
| [multi_mcp](https://github.com/religa/multi_mcp) | Parallel execution, debate mode, OWASP code review |
| [PAL MCP](https://github.com/BeehiveInnovations/pal-mcp-server) | Cross-model conversation continuity |
| [perspectives-mcp](https://github.com/polydev-ai/perspectives-mcp) | One call, four model opinions |

Pattern: Skills instruct Claude -> Claude calls MCP tools ->
MCP tools call other models -> results return to Claude. Claude
never loses control.

### AI Gateways (If Scale Demands It)

- **LiteLLM**: Self-hosted, 100+ providers, 7 routing strategies.
  Best for flexibility. Free.
- **OpenRouter**: Hosted, 300+ models, zero infrastructure. Best
  for simplicity. 5% markup.
- **Bifrost**: Go, 11us overhead at 5K RPS. Best for performance. Free.

For individual developers, MCP servers suffice. Gateways become
relevant at team scale.

### Portable Skills

The SKILL.md format works across Claude Code, Codex CLI, Gemini CLI,
Cursor, and Antigravity IDE. 1,234+ skills exist in the
[Awesome Agent Skills](https://github.com/VoltAgent/awesome-agent-skills)
library.

Design skills as **job descriptions**, not API wrappers. A skill
that says "review for OWASP Top 10" ports everywhere. A skill that
says "call the OpenAI API" is locked to one provider. Multi-model
routing happens below the skill layer.


## Open Questions

- **Where is the T1/T2 boundary for cross-model review?** For T1
  fixes, cross-model is overkill. For T3, probably essential. The
  T2 boundary is unclear.

- **Skill vs hook for review enforcement?** Explicit invocation
  (`/work-review`) vs automatic enforcement (stop-hook on every
  task)? Likely tier-dependent.

- **Quality floor for downgrading?** No published thresholds for
  when routing to Haiku introduces more errors than savings.

- **Credit assignment?** When multi-model fails, which model caused
  it? Model combos must be evaluated holistically.

- **Local model viability?** Can Ollama models provide meaningful
  review quality for privacy-sensitive code?

- **Convergence criteria?** When 3 models disagree on a review
  finding, what confidence thresholds and iteration limits work?

---

*Research conducted March 2026. 70+ sources across academic papers,
practitioner blogs, GitHub repositories, and framework documentation.
Full deliverable with complete source list at
`.work/multi-model-architectures/research/deliverable.md`.*
