# Model Routing Reference

## Resolution Order

When dispatching a sub-agent, resolve the model in this order:

1. **Specialist `model_hint`** — from the specialist template's YAML frontmatter
2. **Step `model_default`** — declared in the current step skill
3. **Project default** — `sonnet`

First non-empty value wins. Pass as the Agent tool's `model` parameter.

## Per-Step Rationale

| Step | Default | Rationale |
|------|---------|-----------|
| ideate | sonnet | Structured ceremony; reviewer is evaluation, not novel reasoning |
| research | opus | Multi-source investigation requires deep reasoning and synthesis |
| plan | sonnet | Codebase exploration is structured reading, not architectural reasoning |
| spec | sonnet | Spec writing follows plan decisions; structured, not exploratory |
| decompose | — | No dispatch — orchestrator writes plan.json directly |
| implement | per hint | Specialist model_hint drives; varies by domain complexity |
| review | opus | Quality judgment and evaluation require deep reasoning |

## Specialist Model Hints

| Hint | When Used | Current Specialists |
|------|-----------|-------------------|
| opus | Deep reasoning, evaluation, security analysis, architectural judgment | accessibility-auditor, complexity-skeptic, prompt-engineer, security-engineer, systems-architect (5) |
| sonnet | Structured implementation, pattern application, domain-specific coding | api-designer, cli-designer, css-specialist, document-db-architect, frontend-designer, go-specialist, harness-engineer, merge-specialist, migration-strategist, python-specialist, relational-db-architect, shell-specialist, technical-writer, test-engineer, typescript-specialist (15) |
| haiku | Fast structured tasks (not currently assigned) | None (0) |

## Override Rules

The orchestrator may override a specialist's model_hint when:

1. **Task complexity exceeds hint** — a sonnet-hinted specialist faces unusually complex reasoning (e.g., intricate concurrency design in go-specialist)
2. **Aligned reasoning depth** — multiple deliverables in a wave need consistent reasoning depth
3. **Atypical work** — the specialist is being used outside its typical domain (e.g., security-engineer doing routine config review)

Overrides must be documented in the dispatch decision (e.g., in team-plan.md or summary.md), not silent. The default is to trust the hint.
