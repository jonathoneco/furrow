# Research Synthesis — model-routing-and-specialists

## Deliverable: orchestrator-architecture

### Finding 1: The Collaborate/Execute Split is Step-Dependent
Not every step needs the same dispatch pattern:
- **Ideate**: Pure collaboration, no dispatch (orchestrator IS the step)
- **Research, Spec**: Multi-round dispatch — agents investigate, orchestrator presents to user, iterates, agents refine
- **Plan, Decompose**: Primarily orchestrator work — synthesis and artifact writing that's small enough to stay inline. Plan may dispatch for codebase exploration; decompose writes plan.json directly
- **Implement**: Full specialist dispatch with wave orchestration (the mature pattern)
- **Review**: Dual-phase — Phase A inline (deterministic), Phase B dispatched (isolated evaluation)

**Implication**: The orchestrator skill needs a per-step dispatch table, not one universal loop.

### Finding 2: Implement.md Is the Generalizable Template
The implement.md dispatch protocol is the most mature and well-documented:
- plan.json-driven, schema-validated handoff from decompose
- Specialist template loading is mandatory and blocking
- Context curation follows specialist's Context Requirements (Required/Helpful/Exclude)
- 3-tier model resolution with explicit Agent tool `model` parameter
- Wave execution with inspection gates between waves
- Correction limits prevent spiral

**Implication**: The orchestrator skill should encode this as the default dispatch pattern, with per-step adaptations documented in each step skill.

### Finding 3: Context Curation Is the Critical Boundary
From context-isolation.md and implement.md, what crosses the dispatch boundary:
- **Included**: Full task text, specialist template, curated context per specialist's Requirements, definition.yaml ACs, file ownership globs
- **Excluded**: Session history, other agents' WIP, raw research, state.json
- **Anti-pattern**: "Never pass the lead agent's full conversation to a sub-agent. Curate, do not copy."

**Implication**: The orchestrator skill must explicitly list what context flows to agents for each step type.

### Finding 4: All Open Questions Answered
1. **Context to agents**: Specialist template + curated context per Requirements + ACs + file ownership + summary.md (not raw research or session history)
2. **Gate evaluators**: Phase A inline (shell), Phase B dispatched (isolated subagent). No change needed.
3. **Fallback on insufficient output**: No re-dispatch. Review catches failures → correction cycle → correction limit prevents spiral.
4. **Cross-model gap**: Confirmed. frw cross-model-review needs deliverable arg. Skip at ideation, use fresh-context only.

## Deliverable: specialist-step-modes

### Finding 5: Model Routing Is Already Consistent
20 specialists audited: 5 opus (25%), 15 sonnet (75%). All assignments match template guidance. No model_hint changes needed.

### Finding 6: Step Mode Overlays Map to 5 Steps
Not all 7 steps dispatch specialists. Mode overlays needed for:
1. **Plan**: Emphasize architectural framing, trade-off analysis
2. **Spec**: Emphasize contract completeness, boundary definition, constraint enumeration
3. **Decompose**: Emphasize wave strategy, dependency ordering, file ownership scoping
4. **Implement**: Emphasize incremental correctness, testability, spec adherence (already exists in implement.md)
5. **Review**: Emphasize AC verification, anti-pattern detection, quality dimension coverage (already exists in review.md)

Ideate and research don't dispatch specialists (ideate is pure collaboration; research dispatches generic research agents, not specialists).

**Implication**: ~3 new mode overlays needed (plan, spec, decompose). Implement and review already have step-level specialist modifiers.

### Finding 7: Harness-Engineer Grounding Is Partially Done
- Context Requirements already list rationale.yaml as Required
- What's missing: explicit reasoning patterns that USE rationale.yaml (check exists_because, verify delete_when, justify decisions from rationale entries)
- Rationale.yaml covers 100+ components with exists_because/delete_when structure

### Finding 8: Phase 2 Dependents Are Well-Aligned
- **parallel-agent-orchestration-adoption**: Needs working model routing + clear orchestration instructions. Our orchestrator skill directly enables this.
- **dual-review-and-specialist-delegation**: Needs mode overlay convention + specialist-step interaction patterns. Our specialist-step-modes deliverable directly enables this.
- No infrastructure components (launch-phase.sh, hooks, rws CLI) need changes for model routing.

## Architecture Decision Record

### AD-1: Per-Step Dispatch Table
The orchestrator skill will include a dispatch table mapping each step to its dispatch pattern:
- Which steps dispatch agents vs run inline
- What dispatch model each step uses (single-round, multi-round, wave-based)
- What model the dispatched agents run at

### AD-2: Orchestrator Boundary = No Artifact Production
The enforceable boundary is "no file writes" — the orchestrator presents, decides, iterates, dispatches, but never produces deliverable artifacts directly. This is cleaner than "no step work" because the orchestrator DOES reason about step content (e.g., understanding review findings to dispatch fixes).

### AD-3: Static Model Routing
Model routing uses the existing 3-tier resolution (specialist hint → step default → project default). No dynamic complexity analysis. The lead agent may override hints if task complexity warrants, but this is judgment-based, not algorithmic.

### AD-4: Mode Overlays Are Step-Scoped Generics
~5 mode overlays total, one per dispatching step. Each overlay is 10-15 lines describing how specialists should adapt their reasoning emphasis for that step. Not per-specialist-per-step.

## Risk Assessment

### Low Risk
- Model routing audit shows no inconsistencies — this is refinement, not redesign
- Gate evaluation system needs no changes
- Launch-phase.sh needs no changes
- Hooks need no changes

### Medium Risk
- Splitting collaboration out of step skills requires careful auditing to ensure nothing is lost
- Mode overlays need to be concrete enough to change agent behavior without being so specific they conflict with specialist reasoning

### Mitigated
- Orchestrator bloat: sessions are per-step (existing design), so orchestrator context doesn't accumulate across all 7 steps
- Context loss: summary.md + specialist Context Requirements + ACs provide sufficient handoff (validated by implement.md's success pattern)
