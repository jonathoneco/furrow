# Spec: rules-strategy-doc

## Interface Contract

**`references/rules-strategy.md`** (new)
- Reference document (on-demand, not auto-injected)
- Covers the enforcement taxonomy and extraction criteria

## Acceptance Criteria (Refined)

1. `references/rules-strategy.md` exists and documents the enforcement taxonomy
2. Document covers all 4 enforcement layers: rules, hooks, skills, CLAUDE.md
3. Each layer has: purpose, persistence characteristics, propagation scope (main session, subagents, worktrees, post-compaction)
4. Document includes extraction criteria: "would violating this break the harness workflow?"
5. Document includes the CLAUDE.md vs rules persistence research findings (equivalent persistence, hooks are only universal enforcement)
6. Document includes examples of what belongs in each layer
7. Document references install.sh management of rules (symlink approach)

## Test Scenarios

### Scenario: taxonomy covers all layers
- **Verifies**: AC 2
- **WHEN**: Reading references/rules-strategy.md
- **THEN**: All 4 layers are documented with distinct sections
- **Verification**: `grep -c "^## " references/rules-strategy.md` >= 4 (one per layer + overview)

### Scenario: extraction criteria are actionable
- **Verifies**: AC 4
- **WHEN**: Developer wants to decide where to put a new invariant
- **THEN**: Document provides a decision tree or criteria list that produces a clear answer
- **Verification**: Document contains "when to use" or "criteria" section with binary decision points

## Implementation Notes

- Structure: Overview → Layer taxonomy table → Per-layer details → Extraction criteria → Examples → install.sh management
- Keep under 100 lines — this is a reference, not a tutorial
- Persistence research summary: rules and CLAUDE.md both re-read from disk after compaction, both load in worktrees, neither reliably loads in subagents. Hooks (settings.json) are universal.
- Link to cli-mediation.md and step-sequence.md as concrete examples

## Dependencies

- harness-rules deliverable should be complete first (provides concrete examples to reference)
