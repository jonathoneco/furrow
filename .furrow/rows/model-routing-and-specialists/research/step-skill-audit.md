# Step Skill Collaboration Audit

## Sources Consulted
- skills/ideate.md (primary) — full read
- skills/research.md (primary) — full read
- skills/plan.md (primary) — full read
- skills/spec.md (primary) — full read
- skills/decompose.md (primary) — full read
- skills/implement.md (primary) — full read
- skills/review.md (primary) — full read

## Orchestrator/Agent Split Per Step

| Step | model_default | Orchestrator Role | Agent Role |
|------|---------------|-------------------|------------|
| ideate | sonnet | All: 6-part ceremony, user decisions, dual-review synthesis | Optional: fresh reviewer subagent, cross-model review |
| research | opus | Source-trust decisions, finding validation, coverage sufficiency | Parallel research agents: investigate topics, cite sources |
| plan | sonnet | Trade-off decisions, risk tolerance, dependency ordering | Artifact writing: plan.json, team-plan.md |
| spec | sonnet | AC precision, edge case scope, testability approach | Parallel spec agents per component |
| decompose | sonnet | Minimal (approval gate only) | Wave mapping, specialist assignment, plan.json |
| implement | sonnet | Wave orchestration, specialist validation, progress inspection | Parallel specialist agents per deliverable per wave |
| review | opus | Phase A checks, dual-reviewer synthesis, consent isolation | Phase B: fresh Claude + cross-model isolated evaluators |

## Key Patterns Found

### Collaboration Protocol (all 7 steps)
Every step has a `## Collaboration Protocol` section with:
- Decision categories specific to the step
- High-value question examples (decisions, not rubber-stamp)
- "Don't assume — ask" discipline

### Supervised Transition Protocol (all 7 steps)
1. Update summary.md (Key Findings, Open Questions, Recommendations)
2. Present work per summary-protocol.md
3. Ask explicitly: "Ready to advance?" (Yes/No)
4. Wait for user response — do NOT proceed without approval
5. On yes: `rws transition` with evidence
6. On no: address feedback, loop back

### Multi-Round Dispatch Patterns
- **Ideate**: 6 ceremony phases, each may need user iteration
- **Research**: Parallel agents per topic, orchestrator collects and presents for validation
- **Spec**: Parallel agents per component, orchestrator validates cross-spec consistency
- **Implement**: Multi-wave dispatch with inspection gates between waves
- **Review**: Two-phase (A: deterministic, B: isolated judgment), then synthesis

### Steps with NO Current Agent Dispatch
- **Ideate**: Pure collaboration (except optional fresh/cross-model review)
- **Plan**: No mandatory dispatch (optional CC plan mode)
- **Decompose**: Writes artifacts directly, no subagent dispatch

### Steps with EXISTING Agent Dispatch
- **Research**: Parallel sub-agents per topic
- **Spec**: Sub-agents per component (multi-deliverable)
- **Implement**: Full specialist dispatch with model routing
- **Review**: Isolated evaluator dispatch (claude -p --bare + cross-model)

## Implications for Orchestrator Skill

1. **Ideate runs fully inline** — it IS the orchestrator's core job (no dispatch)
2. **Research, spec need multi-round dispatch** — dispatch agents, receive, present to user, iterate
3. **Plan, decompose may not need dispatch** — they're already orchestrator-scale work
4. **Implement has the most mature dispatch** — template for generalizing
5. **Review has unique dual-phase** — Phase A inline, Phase B dispatched
6. **Every step needs the collaboration protocol** — this stays with the orchestrator regardless

## What Moves to orchestrator.md
- The dispatch loop pattern (dispatch → receive → present → decide → dispatch)
- Context curation rules (what to pass to agents)
- The "no artifact production" boundary rule
- Multi-round iteration protocol within steps
- How to handle step-specific collaboration decisions
- Summary update protocol before transitions

## What Stays in Step Skills
- Step-specific execution instructions (the "what to do")
- Acceptance criteria for step outputs
- Step-specific rules and constraints
- Mode overlay sections (new, for specialist behavior)
- Agent dispatch metadata (model routing, context requirements)
