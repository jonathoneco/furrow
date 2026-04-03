# Team Plan: Parallel Workflow Support

## Scope Analysis

5 deliverables across 2 waves. Wave 1 is foundation (sequential). Wave 2 has 4
independent deliverables with no file ownership overlap — ideal for parallel agents.

## Team Composition

| Agent | Role | Deliverables | Rationale |
|-------|------|-------------|-----------|
| Coordinator (self) | Wave 1 implementation + orchestration | focus-infrastructure | Foundation must be correct before wave 2 |
| hook-scoping-agent | Shell script refactoring | hook-scoping | Largest deliverable (10 files), needs focused attention |
| command-and-status-agent | Command/skill updates | command-routing, status-command-update | Both are markdown skill files with similar patterns |
| archive-agent | Archive script update | archive-integration | Small, mechanical change — quick turnaround |

3 agents for wave 2 (hook-scoping alone, commands grouped, archive alone).

## Task Assignment

### Wave 1 (Coordinator — sequential)
1. Add `extract_unit_from_path()` to `hooks/lib/common.sh`
2. Add `find_focused_work_unit()` to `hooks/lib/common.sh`
3. Add `set_focus()` and `clear_focus()` to `hooks/lib/common.sh`
4. Verify backward compatibility (single-unit case unchanged)

### Wave 2 (Parallel agents)

**hook-scoping-agent:**
- Refactor 4 path-scoped hooks (timestamp-update, ownership-warn, summary-regen, correction-limit)
- Refactor 1 command-scoped hook (gate-check)
- Refactor 3 focus-scoped hooks (stop-ideation, validate-summary, post-compact)
- Refactor 1 all-units hook (work-check)
- Verify state-guard.sh and validate-definition.sh need no changes

**command-and-status-agent:**
- Update `commands/work.md` routing for --switch, multi-unit creation, implicit focus
- Update `commands/status.md` for --all flag with focused indicator
- No changes to `commands/lib/detect-context.sh` (already multi-unit aware)

**archive-agent:**
- Add .focused cleanup to `scripts/archive-work.sh`
- Source common.sh or inline the check

## Coordination

- Wave 1 completes before wave 2 starts (hard dependency)
- Wave 2 agents have zero file overlap — no coordination needed between them
- Each agent reads its spec from `specs/{deliverable-name}.md`
- Each agent reads `hooks/lib/common.sh` (read-only) for the new helper signatures
- Commit convention: one commit per deliverable, conventional commit format

## Skills

- `specialists/shell-specialist.md` for hook-scoping-agent and archive-agent
- No cli-designer specialist file exists — command-and-status-agent uses general context
