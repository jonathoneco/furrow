# Downstream Effects Analysis

## Sources Consulted
- .furrow/almanac/roadmap.yaml (primary) — Phase 2 dependencies
- .furrow/almanac/todos.yaml (primary) — Phase 2 TODO entries
- bin/frw.d/scripts/launch-phase.sh (primary) — full read
- evals/gates/*.yaml (primary) — gate evaluation structure
- bin/frw.d/hooks/ (primary) — all hook files
- bin/rws (primary) — relevant subcommands
- skills/work-context.md (primary) — work layer context

## Phase 2 Dependents

### parallel-agent-orchestration-adoption
**Expects from our work:**
- Model routing that works (agents dispatched at correct model)
- Specialist templates that are valid and loadable
- Clear orchestration instructions in implement.md

**Key problem it solves:** Despite full infrastructure (wave planning, specialist templates, context isolation, file ownership), implementation falls back to solo execution. Agents don't follow through on multi-agent dispatch.

**Our work enables this by:**
- Making the orchestrator skill explicit (not embedded in step skills)
- Clarifying the dispatch protocol (what to dispatch, how, with what model)
- Ensuring specialist templates are audit-verified and consistent

### dual-review-and-specialist-delegation
**Expects from our work:**
- Specialist templates with correct model_hint values
- Mode overlay convention documented in specialist-template.md
- Intent-based specialist matching patterns

**Key problem it solves:** Dual-reviewer protocol only exists in review/ideate. Specialists are assigned in decompose but not enforced during implementation.

**Our work enables this by:**
- Establishing mode overlays that show how specialists adapt per step
- Documenting the specialist-step interaction pattern
- Providing the routing architecture for specialist evaluators

## Infrastructure Components — No Changes Needed

### launch-phase.sh
- Creates worktrees, tmux sessions, launches Claude CLI
- No model selection handling — defers to skills at runtime
- No changes needed for model routing

### Gate Evaluation System
- Phase A (deterministic): runs inline as shell checks — no model routing needed
- Phase B (judgment): already dispatched as isolated subagent via `claude -p --bare`
- Current pattern is correct for orchestrator architecture
- Gate evaluator subagent spawning already respects Agent tool model parameter

### Hooks
- state-guard.sh, verdict-guard.sh: critical safety boundaries, no changes needed
- gate-check.sh: already simplified (validation moved into rws_transition)
- correction-limit.sh: prevents spiral, model-routing-agnostic
- No new hooks required for model routing

### rws CLI
- rws_load_step: may benefit from model metadata output (inform orchestrator which model to use)
- rws_transition: no changes (validation already in function)
- rws_gate_check: deterministic, no model routing
- Model routing decisions happen in skills, not CLI

## Conflict Zones

From roadmap.yaml:
```
Phase 1, file_pattern: "specialists/, skills/implement.md"
work_units: [model-routing-and-specialists, infra-fixes]
severity: low
mitigation: "model-routing merges first"
```

Our work touches specialists/ and skills/ — infra-fixes also touches skills/implement.md. Low severity because model-routing merges first.

## Open Questions Addressed

### Q: How much context beyond summary.md + step skill should orchestrator pass?
**Answer:** Per context-isolation.md and implement.md pattern:
- Specialist template content (full text)
- Curated context per specialist's Context Requirements (Required/Helpful/Exclude)
- Definition.yaml acceptance criteria
- File ownership globs
- NOT: full session history, raw research, other agents' WIP, state.json

### Q: Should gate evaluators run as orchestrator-inline or dispatched?
**Answer:** Both, matching current pattern:
- Phase A (artifact checks): inline shell (no model needed)
- Phase B (quality judgment): dispatched isolated subagent
- Failures route back via review results, not orchestrator session

### Q: Fallback when dispatched agent produces insufficient output?
**Answer:** No automatic re-dispatch. Current pattern:
- Review Phase A/B catches failures
- Returns to implement with specific feedback
- In-session corrections (same agent continues)
- Correction counter tracks attempts
- Correction limit (hook-enforced) pauses for human input after N failures

### Q: Cross-model review tooling gap at ideation?
**Answer:** Confirmed. `frw cross-model-review` requires `<name> <deliverable>`. No ideation-stage equivalent exists. Workaround: skip cross-model during ideation (only fresh-context review). Future fix: add `frw cross-model-review --stage ideation` or similar.
