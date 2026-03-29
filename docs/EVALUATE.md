# Evaluate & Adopt — Stop Building, Start Using

## Context

I've spent significant time researching, designing, and planning a custom agentic work harness. The research is solid — but I need to be doing my actual work, not building tools. Talented engineers are already building these systems. I want to adopt one.

The research in `docs/research/` gives me a strong evaluation framework. Use it to assess the market and recommend a solution I can adopt now.

## What I Need From a Harness

Based on extensive research and operational experience:

1. **Structured workflow for complex tasks** — Not everything is a one-shot fix. Multi-session initiatives need state, continuity, and quality gates. Some form of depth-based routing (simple tasks get simple treatment, complex tasks get more structure).

2. **Session continuity** — Handoff between sessions so context isn't lost. This was the single most valuable v1 feature.

3. **Quality enforcement** — Review gates, eval-driven validation, or similar. Documentation discipline alone fails (1.43:1 feature-to-fix ratio from v1).

4. **Context management** — Not everything loaded every time. Three observed tiers: project-level (long-lived), work-level (medium), record-level (accumulating). See `docs/research/context-tiers-observation.md`.

5. **Thin layer on platform primitives** — Should leverage Claude Code's native skills, hooks, teams, tasks — not reimplement them. Must be designed to shrink as platforms absorb capabilities.

6. **Eval infrastructure** (nice to have) — Automated behavioral testing, regression detection, or at least a path toward it.

7. **Dual-runtime potential** (nice to have) — Ability to work with Claude Code locally AND potentially Agent SDK for autonomous agents.

## Known Candidates

Evaluate at minimum:
- **Superpowers** (github.com/anotherjesse/superpowers) — Claude Code power-user toolkit
- **GSD** (github.com/gsd-tools/gsd or similar) — "Get Shit Done" workflow framework
- **gstack** (Garry Tan's AI toolkit) — Build-time prompt composition, reasoning frameworks
- **oh-my-claudecode** (github.com search) — Claude Code enhancement framework

Also search for anything else in this space that's gained traction since March 2026. The ecosystem moves fast.

## Evaluation Criteria (from research)

Use findings from `docs/research/` as the evaluation framework:

### From rewrite-assessment.md
- Does it avoid the failure modes we identified? (prose-as-infrastructure, platform reimplementation, implicit contracts, context bloat)
- Does it preserve the concepts we validated? (depth routing, handoffs, review gates, step-aware loading)

### From paradigm-shift.md
- Is it built on the layered hybrid model (declarative + prose + evals)? Or is it v1-era monolithic prose?
- Does it leverage native platform primitives or reimplement them?
- Does it have or support eval infrastructure?

### From anthropic-blog.md
- Does it follow Anthropic's own patterns? (progressive disclosure, hooks for enforcement, file-based state, verification as structural primitive)

### From multi-model-architectures.md
- Does it support or have a path to multi-model review?
- Is the architecture flat (safe) or hierarchical (fragile)?

### From landscape-summary.md
- Does it respect "scaffold > model"? Is the scaffolding quality high?
- Does it follow the convergence patterns (state persistence, domain-expert agents, progressive disclosure)?

### Practical criteria
- **Installation friction**: How fast can I go from zero to productive?
- **Active maintenance**: Is it actively developed? Community size?
- **Customizability**: Can I adapt it to my workflow without forking?
- **Exit cost**: If I outgrow it, how locked in am I?
- **Compatibility**: Works with my setup (Arch Linux, zsh, Claude Code CLI)

## Output Expected

1. **Market scan**: What's out there? Brief assessment of each candidate.
2. **Deep evaluation**: Top 2-3 candidates evaluated against the criteria above.
3. **Recommendation**: One specific recommendation with rationale. Not "it depends" — pick one.
4. **Adoption plan**: What I need to do TODAY to switch. Installation steps, configuration, what to migrate from v1, what to leave behind.

## What NOT to Do

- Don't recommend building a custom harness. That's what I'm moving away from.
- Don't recommend a framework that requires weeks of setup. I need to be productive NOW.
- If nothing meets the bar, say so clearly — but also say what the best available option is and what's missing.
