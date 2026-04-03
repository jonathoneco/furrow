# Multi-Model Agent Architectures — Research Findings

Source: 70+ sources across academic papers, practitioner blogs, GitHub repos, framework docs, and practitioner experience reports. March 2026.

## Core Finding: Model Diversity Catches What Monocultures Miss

When the same model generates and reviews code, blind spots are correlated. Heterogeneous model ensembles achieve ~9% higher accuracy on reasoning benchmarks. Cross-model review in production finds 3-5x more bugs than single-pass, with low false-positive rates.

Different model families catch different bug classes: Claude excels at integration/architecture, GPT/Codex at API misuse/type errors/logic bugs (lowest false-positive rate), Gemini at whole-repository consistency via 1M+ token context. A Claude + Gemini pair alone reaches 91% of a five-model ceiling, with barely overlapping weaknesses — two carefully chosen models capture most of the diversity benefit. 75%+ of organizations already use multiple models in production (LangChain survey).

## Routing Economics

Hybrid routing delivers 80-90% of frontier quality at 25-30% of frontier-only cost. Multiple approaches validated: RouteLLM (85% savings on MT Bench), CascadeFlow (40-85%), AgentOpt budget combos (21x-118x cheaper at 94-98% quality).

The "cheap draft, expensive verify" pattern is widely validated — verification is inherently easier than generation, so weaker generators + strong verifiers approach the quality of stronger generators alone.

Counterintuitive finding (AgentOpt, Columbia): Ministral 3 8B planner + Opus solver achieved 74.8% vs Opus+Opus at 73% — the smart model "refused to delegate," bypassing solver tools entirely. Cost: 118x savings for only 4.5% accuracy loss. Model combos should be evaluated holistically, not independently optimized.

**Scaffolding matters more than model choice.** The same Opus 4.5 scored 17 problems apart across different agent harnesses (Augment vs Cursor vs Claude Code). Harness quality is the higher-leverage investment over model selection.

## Failure Modes

- **Error cascading**: Unstructured multi-agent networks amplify errors up to 17.2x. Flat topologies (lead + 2-3 specialists) are safe; deep hierarchies are not.
- **Compound reliability**: At 95% per-step reliability, a 10-step chain drops to 59.9%. At 90%, 10 steps = 34.9%.
- **Coordination breakdown**: Study of 1,642 traces across 7 frameworks found 41-86.7% failure rates. Categories: task/role violations, conversation resets, premature termination.
- **Token explosion**: Agents consume 10-50x more tokens via iterative reasoning. Multi-agent systems consume 3-10x more than single-agent.
- **Router collapse**: Routers default to most expensive model when prediction margins are small (94.9% of queries are near-ties).
- **Auto-orchestration collapse**: Practitioner tested full auto-orchestration with watchexec — "all agents stopped doing real work and started generating huge status reports." Unbounded delegation produces coordination overhead, not useful work.
- **Shared instructions don't work**: Each model responds differently to the same prompts. Provider-specific instruction files (CLAUDE.md, CODEX.md) are necessary.
- **Cognitive load**: Developers report "brain fry" managing parallel agents. The human becomes the bottleneck.
- **Model instability**: Week-to-week quality varies unpredictably even in flagship models. Harness should not hardcode model assumptions.
- **Industry failure rate**: 40% of multi-agent pilots fail within six months of production deployment.

## Integration Patterns

Cross-model review implementations exist at three levels of sophistication: one-shot review via skill (simplest), stop-hook spawned review (mid), and full plan-validate-execute-review loops (complex). MCP servers provide the lowest-friction integration path from Claude Code (multi_mcp, PAL MCP, perspectives-mcp).

Skills designed as "job descriptions" (outcomes and quality standards) port across model providers. Skills designed as API wrappers are locked to one provider. Multi-model routing should happen below the skill layer.

File-based coordination dominates in practice. Practitioners use markdown files and handoff logs (CHANGES.log, state.json) for multi-agent coordination — validating Furrow's file-based state approach over framework-mediated communication.

**Practitioner sentiment consensus**: Multi-model task routing is clearly worth it. Multi-agent coordination is fragile and expensive. 2-3 models is the sweet spot. The human is the bottleneck, not the models.

## Open Questions

- Where is the boundary for when cross-model review is worth the cost vs. overkill?
- Quality floor for model downgrading — when does routing to cheaper models introduce more errors than savings?
- Credit assignment — when multi-model fails, which model caused it?
- Local model viability for privacy-sensitive code?
- Convergence criteria when multiple models disagree on a finding?
- Does the Ministral finding (weak planner beats strong planner) generalize to repository-scale coding tasks?
- How stable are model combinations over time given week-to-week quality variation?
- Should agent workflows follow DRY, or is redundancy better for agent-consumed instructions?
- What's the practical ceiling for concurrent agent streams a developer can effectively supervise?
