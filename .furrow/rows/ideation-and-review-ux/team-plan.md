# Team Plan: ideation-and-review-ux

## Scope Analysis

4 deliverables across 9 files (2 create, 7 modify). All skill/command markdown files.
Single specialist domain: harness-engineer. No code, no tests, no schema changes.

## Team Composition

**Single agent** (harness-engineer) executing sequentially through waves.

Rationale: All deliverables are the same domain (harness skill/command files), the Wave 1
items are small, and Wave 2 items have no file overlap. Parallel agents would add
coordination cost without meaningful time savings for markdown edits.

## Task Assignment

### Wave 1 (parallel-capable but sequential is fine)

| Deliverable | Specialist | Model | Files | Effort |
|------------|-----------|-------|-------|--------|
| decision-format | harness-engineer | sonnet | skills/shared/decision-format.md (new) | Small |
| agent-isolation-audit | harness-engineer | sonnet | skills/shared/gate-evaluator.md (modify) | Small |

### Wave 2 (after Wave 1 complete)

| Deliverable | Specialist | Model | Files | Effort |
|------------|-----------|-------|-------|--------|
| per-step-collaboration | harness-engineer | sonnet | skills/ideate.md, research.md, plan.md, spec.md (modify) | Medium |
| fresh-session-review | harness-engineer | sonnet | commands/review.md, skills/review.md (modify), templates/review-prompt.md (new) | Medium |

## Coordination

- Wave 1 → Wave 2 gate: verify decision-format.md exists and is under 50-line budget
- No intra-wave coordination needed (no file overlap)
- Commit after each deliverable: `feat(ideation-and-review-ux): {deliverable description}`

## Skills

All tasks use: `skills/shared/decision-format.md` (after Wave 1 creates it),
`specialists/harness-engineer.md`, existing step skills as modification targets.
