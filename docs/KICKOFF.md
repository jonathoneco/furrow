# Work Harness V2 — Kickoff

## What This Is

A new agentic work harness, designed from scratch. Not a refactor, not a migration — a clean-slate design informed by extensive research and operational experience with a v1 system.

## Who It's For

A solo developer who uses Claude Code daily and is building a startup that needs autonomous agents. The harness must work in both contexts:
- **Local interactive**: Claude Code skills/commands for the developer's daily workflow
- **Autonomous**: Agent SDK programs for startup operations

## What We Know

Research findings from the v1 experience are in `docs/research/`. The short version:

**Things that worked** (concepts, not implementations): depth-based task routing, session handoffs, review gates, step-aware context loading, centralized agent coordination.

**Things that failed** (patterns to avoid): prose-as-infrastructure (594-line markdown commands), platform reimplementation (~70% of v1 duplicated native capabilities), documentation discipline as enforcement (implicit contracts break silently), monolithic context injection (849 lines per session), static scaffolds that can't learn.

**Where the ecosystem is**: layered hybrid (declarative + prose + evals), agent-as-library SDKs, eval-driven development, self-evolving scaffolds, platform primitives absorbing infrastructure.

## Constraints

1. **Dual-runtime**: Must feed into Claude Code AND Agent SDK without being locked to either
2. **Eval-first**: Every behavioral expectation has an eval, not just documentation
3. **Thin**: ~20-30 files. Orchestrate platform primitives, don't reimplement them
4. **Shrinkable**: Designed to get smaller as platforms absorb capabilities
5. **Get it right**: No timeline pressure

## What's NOT Decided

Everything. The research findings are seeds, not decisions. Including:
- How many tiers/levels of task complexity (or whether tiers are the right abstraction at all)
- What the workflow steps are (or whether fixed steps are the right model)
- How state is managed (centralized, dispersed, platform-native, or something else)
- What the skill format looks like
- What the eval framework is
- How review/quality gates work
- What the file structure is
- What language the harness is written in

## How to Start

You decide. There's no inherited process. The only given: `docs/research/` has findings you can use as context, and `.claude/CLAUDE.md` has the constraints above.
