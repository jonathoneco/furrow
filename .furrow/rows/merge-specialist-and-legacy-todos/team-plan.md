# Team Plan: merge-specialist-and-legacy-todos

## Scope Analysis
4 deliverables, all documentation/configuration, single wave, no file ownership overlaps.

## Team Composition
No multi-agent team needed. All deliverables are additive documentation — a single agent can execute them sequentially, or 2 parallel agents can split the work:
- **Agent A**: merge-specialist + harness-engineer-grounding (both specialist files)
- **Agent B**: rationale-update + todos-roadmap-refresh (both almanac files)

## Task Assignment
| Deliverable | Specialist | Files | Agent |
|-------------|-----------|-------|-------|
| merge-specialist | systems-architect | specialists/merge-specialist.md, specialists/_meta.yaml | A |
| harness-engineer-grounding | harness-engineer | specialists/harness-engineer.md | A |
| rationale-update | harness-engineer | .furrow/almanac/rationale.yaml | B |
| todos-roadmap-refresh | harness-engineer | .furrow/almanac/todos.yaml, .furrow/almanac/roadmap-legacy.md | B |

## Coordination
- No inter-deliverable dependencies
- No wave boundary merges needed (single wave)
- Agent B should run `alm validate` after todos update and `alm triage` for roadmap

## Skills
- Spec files in specs/ provide implementation-ready content for each deliverable
- Research findings in research.md provide background context
