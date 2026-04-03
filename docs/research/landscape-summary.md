# AI Dev Landscape Research — Key Findings

Source: work-harness `docs/feature/ai-dev-landscape.md` and `.furrow/rows/ai-dev-landscape/`

## Headline Findings

- **Scaffold > Model**: Custom scaffolding adds 9.5pp on SWE-bench Pro — larger than most model-generation improvements. Harness engineering is the highest-leverage investment.
- **Architecture convergence**: Every major framework converges on state persistence, domain-expert agents, progressive disclosure, deterministic backbone.
- **MCP right-sized**: MCP costs 7-32x more tokens than CLIs. Use sparingly.
- **Multi-agent**: Centralized coordination contains errors to 4.4x vs 17.2x for independent agents.
- **Optimize for supervision**: 18-23% fresh-issue performance means review is non-negotiable. Make review efficient, not try to eliminate it.

## gstack Patterns (Garry Tan's AI Toolkit)

- **Reasoning framework injection**: Named mental models ("blast radius instinct," "boring by default") injected into agent prompts — a distinct specialization technique beyond role naming.
- **Build-time prompt composition**: CI-validated template resolvers prevent prompt drift at near-zero cost.
- **Prompt testing pyramid**: $0 static / $3.85 E2E / $0.15 LLM-judge. Most teams should stop at Tier 2.
- **Dispersed state**: File-per-concern (not centralized state.json) is viable for simple workflows.
- **Context depth vs capability depth**: Orthogonal problems that need separate solutions.

## Anthropic Repos

- **Feature-dev plugin**: 7-phase workflow with 3 mandatory user gates; dedicated clarification phase.
- **Hookify**: Auto-generates behavioral rules from frustration signals — automated prompt improvement.
- **Agent SDK**: `can_use_tool` rewrites inputs (not just allow/deny); `UserPromptSubmit` invisibly injects context.
- **MCP Go SDK**: Production-ready (v1.4.1).
