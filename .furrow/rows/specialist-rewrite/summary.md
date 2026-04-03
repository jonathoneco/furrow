# specialist-rewrite — Summary

## Task
Rewrite 4 existing + create 9 new specialist templates in the reasoning-focused format of harness-engineer.md. 13 specialists total across 6 deliverables.

## Current State
Archived. All 6 deliverables complete. Review passed (Phase A + Phase B) for all deliverables.

## Artifact Paths
- `specialists/api-designer.md` — rewritten (6 patterns)
- `specialists/test-engineer.md` — rewritten (7 patterns)
- `specialists/relational-db-architect.md` — new, replaces database-architect.md (7 patterns)
- `specialists/document-db-architect.md` — new, replaces database-architect.md (7 patterns)
- `specialists/go-specialist.md` — new (7 patterns)
- `specialists/shell-specialist.md` — new (7 patterns)
- `specialists/typescript-specialist.md` — new (7 patterns)
- `specialists/python-specialist.md` — new (7 patterns)
- `specialists/systems-architect.md` — new (8 patterns)
- `specialists/security-engineer.md` — new (6 patterns)
- `specialists/migration-strategist.md` — new (7 patterns)
- `specialists/complexity-skeptic.md` — new (6 patterns)
- `specialists/cli-designer.md` — new (7 patterns)
- `references/specialist-template.md` — updated to new format
- `specialists/database-architect.md` — deleted (replaced by relational + document variants)

## Settled Decisions
- Pattern count: variable 5-8 per specialist, quality over forced quantity
- Content reuse: light editing of existing QC/Anti-Patterns, not full rewrites
- Drop "Exclude" from Context Requirements to match exemplar
- DB split: database-architect.md → relational-db-architect.md + document-db-architect.md
- Technology-agnostic patterns; language-specific idioms in language specialists only
- Harness-themed patterns optional — only where they naturally change reasoning
- Merged dependency-skeptic + redesign-advocate → complexity-skeptic
- Priority order: existing-rewrites → language → architecture → process

## Key Findings
- 95 reasoning patterns across 14 specialist files, all structurally conformant
- Cross-model review identified key issues early: scope concern (mitigated by parallel agents), overlap risks (resolved by merging complexity-skeptic), forced harness patterns (made optional)
- Catalog validation found 2 issues post-implementation: duplicate pattern name ("Schema as reviewable artifact" renamed in document-db) and anti-pattern overlap (complexity-skeptic reframed)

## Open Questions
- Should the catalog include frontend/UI, observability, or data pipeline specialists? (Deferred — add when needed)
- How to validate that reasoning patterns actually change agent behavior? (Smoke testing proposed but not implemented)

## Recommendations
- Run E2E test (T2) with one of the new specialists assigned to a deliverable to validate the two-path consumption model
- Add a structural conformance linting script that can be run across all specialists when the format evolves
- Consider adding TODOS item 10 (validate-definition.sh slug support) to next work unit
