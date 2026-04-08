# Spec: agent-isolation-audit

## Interface Contract

**Output file**: `.furrow/rows/ideation-and-review-ux/research/agent-isolation-findings.md` (already created)
**Modified file**: `skills/shared/gate-evaluator.md`
**Type**: Research artifact + documentation update

## Acceptance Criteria (Refined)

1. **Empirical test performed**
   - Test already completed during research step (spawned subagent, verified context access)
   - Findings documented in `research/agent-isolation-findings.md` with test methodology

2. **Findings document what context is/isn't shared**
   - Table showing: mechanism × (conversation, system context, file access)
   - Covers: Agent tool subagent, `claude -p`, `claude -p --bare`
   - Already present in research/agent-isolation-findings.md

3. **gate-evaluator.md updated to reflect verified isolation level**
   - Add a "Context Isolation Verification" section or update existing "Prohibited Context" section
   - Clarify: "Agent tool subagents do not receive conversation history or prior tool results"
   - Clarify: "System context (CLAUDE.md, memory, MCP) IS inherited — acceptable for gate evaluation"
   - Add note: "For maximum isolation (e.g., final review), use `claude -p --bare`"

4. **Recommendation documented**
   - Gate evaluations: Agent tool subagents (sufficient isolation)
   - Final review Phase B: `claude -p --bare` (maximum isolation)
   - Include in both research/agent-isolation-findings.md and gate-evaluator.md

## Implementation Notes

- Research artifact is already complete — this deliverable is primarily the gate-evaluator.md update
- Keep gate-evaluator.md changes minimal: clarify existing claims, don't restructure
- The "Prohibited Context" section already exists — augment it with verified claims

## Dependencies

- None (Wave 1, independent)
