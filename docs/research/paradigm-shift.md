# Ecosystem & Paradigm Shift — Key Findings (March 2026)

Source: work-harness `.work/v2-paradigm-harness/research/deliverable.md`

## Platform State of the Art

Claude Code natively provides: skills (SKILL.md format, cross-tool standard), hooks (24 lifecycle events, 4 handler types), agent teams (experimental), tasks (TaskCreate/TaskList with dependencies), subagents, git worktrees, background agents, scheduled tasks (/loop), session management (resume/fork/compact).

Agent SDK provides: programmable agent loop, built-in tools, hooks as callbacks, subagent support, MCP integration, permission modes, session continuity. Does NOT provide: workflow state machine, structured review, triage/assessment, handoff protocol.

## Industry Convergence

All major frameworks (Claude Agent SDK, Codex Agents SDK, LangChain Deep Agents) converged on: agent loop with tool calling, sub-agent spawning, skills/prompts for behavior, filesystem as persistent memory, progressive context loading, hooks for lifecycle management.

Three-layer extension model emerged: Skills (behavioral, zero-cost) → MCP (infrastructure, network cost) → Plugins (bundled, distributable).

## Paradigm Shifts

1. **Agent-as-library**: Agent loop as programmable API call (Python/TypeScript), not markdown prose orchestration.
2. **Layered hybrid wins**: Declarative metadata for routing + constrained prose (<5000 tokens) for behavior + eval suites for validation. Not prose-only, not pure-declarative.
3. **Eval-driven development**: Evals come before prompts. Define success criteria, build eval suite, then write prompts, iterate on eval results. No framework has a complete closed-loop self-improvement pipeline yet.
4. **Self-evolving scaffolds**: Live-SWE-agent (75.4% SWE-bench) starts with bash tools and autonomously creates custom tools via reflection loops. The scaffold itself becomes learnable.
5. **Event-driven steering**: Event-triggered system reminders at decision points outperform front-loaded instructions. Passive initial instructions fade over long horizons.
6. **Bitter Lesson for harnesses**: Must remain lightweight and modular, ready to discard logic when new model releases make current scaffolding unnecessary.

## Eval Landscape

- LangChain: Bespoke test logic per datapoint, single-step + full-turn + multi-turn evals
- Anthropic: Code-based + model-based + human graders combined
- Fireworks: pytest-style assertions for agent behavior (Eval Protocol)
- DSPy: Declarative signatures + metrics → compiled optimal prompts (MIPROv2)
- Red Hat: "the approach only appeared to work because we had overfit the prompt to our limited manual tests"
- evaldriven.org: 10 foundational tenets — evals before prompts

## Spec-Driven Development

GitHub Spec Kit, AWS Kiro (EARS specs), Intent (living-spec sync), BMAD-METHOD. Core idea: specifications, not prompts or code, are the fundamental unit. Maturing fast but still emerging — spec drift and hallucinations persist.

## Key Sources

- Anthropic: Effective Harnesses for Long-Running Agents
- Philipp Schmid: The Importance of Agent Harness in 2026
- LangChain: Deep Agents + Evaluating Deep Agents
- Live-SWE-agent (arXiv 2511.13646)
- OpenDev (arXiv 2603.05344)
- Armin Ronacher: Skills vs Dynamic MCP Loadouts
- evaldriven.org, Fireworks Eval Protocol, Red Hat eval-driven development
