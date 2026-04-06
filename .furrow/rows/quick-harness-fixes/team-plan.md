# Team Plan: quick-harness-fixes

## Scope Analysis

3 deliverables across 2 waves. Wave 1 has 2 independent deliverables that can run
in parallel. Wave 2 has 1 deliverable that depends on wave 1's CLI surface.

## Team Composition

| Agent | Specialist | Deliverables | Wave |
|-------|-----------|--------------|------|
| shell-specialist | `specialists/shell-specialist.md` | cli-mediated-interaction | 1 |
| harness-engineer | `specialists/harness-engineer.md` | claude-md-docs-routing, proactive-summary-maintenance | 1, 2 |

2 agents. shell-specialist handles the rws command implementation. harness-engineer
handles CLAUDE.md routing (wave 1) then summary-protocol reconciliation (wave 2).

## Task Assignment

### Wave 1 (parallel)

**shell-specialist: cli-mediated-interaction**
- Add `rws update-summary` command to `bin/rws`
- Add `update-summary` to help text and dispatch case
- Create `.claude/rules/cli-mediation.md`
- Fix broken `.claude/rules/workflow-detect.md` symlink
- File ownership: `bin/rws`, `.claude/rules/cli-mediation.md`
- Spec: `specs/cli-mediated-interaction.md`

**harness-engineer: claude-md-docs-routing**
- Add topic routing section to `.claude/CLAUDE.md`
- Consolidate/remove duplicate furrow command block if needed
- Stay within 100-line budget
- File ownership: `.claude/CLAUDE.md`
- Spec: `specs/claude-md-docs-routing.md`

### Wave 2 (sequential, after wave 1)

**harness-engineer: proactive-summary-maintenance**
- Update `skills/shared/summary-protocol.md`: reconcile ≥1 line, add timing guidance
- Reference `rws update-summary` command from wave 1
- File ownership: `skills/shared/summary-protocol.md`
- Spec: `specs/proactive-summary-maintenance.md`

## Coordination

- Wave 1 agents have no file ownership overlap — fully parallel.
- Wave 2 starts after wave 1 shell-specialist completes (D2 depends on D1's CLI).
- harness-engineer can start wave 2 immediately after its own wave 1 work finishes,
  as long as shell-specialist has merged the rws update-summary command.

## Skills

- shell-specialist: `specialists/shell-specialist.md`
- harness-engineer: `specialists/harness-engineer.md`
