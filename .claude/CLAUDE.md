## Project

This is work-harness-v2 — a new agentic work harness designed from scratch.

There is NO existing codebase to extend. You are designing and building something new.

## Context

The creator has extensive experience building a v1 harness (in a separate repo). Research findings from that experience are available in `docs/research/` as seed material. These findings inform but do not constrain — every assumption is open to challenge.

## Constraints

- Must work as both Claude Code skills/commands (local interactive) AND Agent SDK programs (autonomous agents)
- Eval infrastructure is a first-class concern, not an afterthought
- Target ~20-30 files — thin convention layer on platform primitives
- No timeline pressure — get it right

## Principles

- Question everything. There is no inherited process or structure that must be preserved.
- Use Claude Code's native primitives (skills, hooks, teams, tasks) rather than reimplementing them.
- Prefer declarative configuration over prose instructions where possible.
- Every behavioral expectation should have an eval, not just documentation.
- Design to shrink over time as platforms absorb capabilities.
