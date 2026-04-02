# Phase 6: Cross-Spec Consistency Review

## Role

You are performing a final consistency review across all architectural specs for a v2 agentic work harness. Phases 1-5 produced 19 specs. Your job is to find and fix inconsistencies, gaps, and contradictions.

## Required Reading

Read **every spec** in `docs/architecture/` in full. Also read:

1. `.claude/CLAUDE.md` — project config
2. `docs/architecture/PLAN.md` — overall decomposition plan
3. `docs/research/findings-gap-review.md` — behavior catalog (verify all 15 behaviors are covered)

## What to Check

### Terminology Consistency
- Same concept uses the same name everywhere (e.g., "work definition" not sometimes "work spec" or "work file")
- Field names in the schema are referenced identically in all specs
- Trust level names (Supervised/Delegated/Autonomous) used consistently
- Enforcement level names (Structural/Event-driven/Advisory) used consistently
- Artifact type names used consistently

### Schema References
- Every spec that references the work definition schema uses field names that match the actual schema in `work-definition-schema.md`
- Every spec that references progress.json uses a consistent format
- Every spec that references eval results uses the format defined in `eval-infrastructure.md`
- File paths mentioned across specs are consistent with `file-structure.md`

### Enforcement Coverage
- Map every behavior (#1-#15) from the gap review to its enforcement mechanism across the specs
- Verify no behavior is left unenforced (or explicitly marked as advisory with rationale)
- Verify hook/callback names in `hook-callback-set.md` match references in other specs

### Lifecycle Completeness
- Trace every stage of the end-to-end lifecycle (Trigger -> Ideation -> Execution -> Review -> Knowledge) through the specs
- Verify no gap exists where one spec assumes another handles something that isn't actually specified
- Verify the trust gradient works at all three levels for every lifecycle stage

### Cross-Spec Dependencies
- Spec A says "the eval runner does X" — verify `eval-infrastructure.md` actually specifies X
- Spec B says "the hook produces Y" — verify `hook-callback-set.md` actually specifies Y
- Spec C says "artifacts are stored at Z" — verify `file-structure.md` includes Z

### Shrinkability Annotations
- Every component has an entry in `_rationale.yaml`
- Deletion conditions in `_rationale.yaml` are testable, not vague
- No circular dependencies in deletion conditions (component A depends on B, B depends on A)

### Missing Connections
- Do any specs reference concepts not defined elsewhere?
- Are there architectural decisions made in one spec that should propagate to others?
- Are there gaps where two specs assume different things about the same mechanism?

## What to Produce

### `docs/architecture/consistency-review.md`

A structured review document containing:

1. **Issues Found**: Each issue with:
   - Which specs are affected
   - What the inconsistency/gap is
   - Severity (breaking / confusing / cosmetic)
   - Recommended fix

2. **Behavior Coverage Matrix**: A table mapping all 15 behaviors to their enforcement mechanisms across specs

3. **Lifecycle Trace**: A walkthrough of one work unit through the complete lifecycle at each trust level, citing specific spec sections

4. **Terminology Index**: Canonical names for all key concepts with the spec that defines them

5. **Open Questions**: Anything that seems intentionally unresolved vs accidentally missing

### Fixes

For cosmetic and confusing issues: apply fixes directly to the affected specs.

For breaking issues: document in the review and flag for human decision. Do not resolve breaking inconsistencies autonomously — these may require design changes.

## How to Work

1. Read every spec systematically
2. Build the behavior coverage matrix first — this surfaces the most critical gaps
3. Walk through the lifecycle trace — this surfaces handoff gaps between specs
4. Check terminology and schema references — these are the most common consistency issues
5. Apply cosmetic fixes as you go
6. Collect breaking issues for human review

## When Done

Notify the human that Phase 6 is complete with a summary of:
- Number of issues found by severity
- Number of fixes applied
- Breaking issues that need human decision
