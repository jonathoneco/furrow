# Spec: existing-rewrites

## Structural Requirements (all 4 files)

Match `specialists/harness-engineer.md` exactly:

```
---
name: {kebab-case}
description: {one-line}
type: specialist
---

# {Name} Specialist

## Domain Expertise
{1-2 paragraph prose. Rewrite existing paragraph for voice alignment with harness-engineer.md — emphasis on HOW this specialist thinks, not WHAT it does.}

## How This Specialist Reasons
{5-8 bullet points. Each: **Bold pattern name**: Expanded reasoning (2-4 sentences). Patterns must be actionable mental models, not reworded responsibilities.}

## Quality Criteria
{Prose paragraph. Light edit of existing for voice alignment.}

## Anti-Patterns
{Table: Pattern | Why It's Wrong | Do This Instead. Light edit of existing.}

## Context Requirements
{Bullet lists: Required + Helpful only. Drop Exclude.}
```

## api-designer.md

**Reasoning patterns** (6):
1. **Consumer-first design** — Start from the caller's experience. How many calls does it take? What does the error tell the caller? Design inward from the consumer, not outward from the implementation.
2. **Backward compatibility calculus** — Classify every change as additive, breaking, or ambiguous before making it. Additive changes (new fields, new endpoints) are safe. Removals and renames are breaking. When in doubt, it's breaking.
3. **Resource boundary reasoning** — Where to draw lines between resources. Nest when the child has no independent identity. Flatten when the child is referenced from multiple parents. When a sub-resource starts getting its own query parameters, it deserves promotion.
4. **Error contract rigor** — Errors are API surface, not afterthought. Machine-readable codes, human-readable messages, consistent envelope. A caller should never need to parse an error string to decide what to do.
5. **Idempotency awareness** — Every endpoint needs a retry story. PUT and DELETE are naturally idempotent. POST needs explicit handling — idempotency keys, upsert semantics, or documented non-idempotent behavior.
6. **Pagination as default** — Unbounded collections are latent production incidents. Every list endpoint gets a default limit, cursor-based pagination, and a total count or has-more indicator.

**Quality Criteria**: Light edit existing — keep consistent naming, error responses, idempotency, pagination requirements.

**Anti-Patterns**: Light edit existing 4 rows — keep internal IDs, 200-with-error, unbounded lists, mixed naming.

**Context Requirements**: Drop Exclude line. Keep Required (route files, handlers, error types) and Helpful (OpenAPI specs, integration tests).

## test-engineer.md

**Reasoning patterns** (7):
1. **Failure-first design** — Every test exists to catch a specific class of regression. Start with "what could break?" then write the test that would detect it. A test without a failure scenario in mind is a test that passes by accident.
2. **Determinism obsession** — Non-deterministic tests are worse than no tests — they train developers to ignore failures. Eliminate time-dependence, ordering-dependence, and external-service dependence. If a test fails intermittently, the test is the bug.
3. **Test boundary reasoning** — Unit, integration, and E2E tests catch different classes of bugs. Choose the cheapest test level that catches the bug you're worried about. Don't write an E2E test for what a unit test covers.
4. **Fixture minimalism** — Test setup contains exactly what the test needs, nothing more. Shared fixtures that grow to cover "all cases" become incomprehensible. When a fixture change breaks 40 tests, the fixture is the problem.
5. **Name as documentation** — A test name communicates what broke when it fails. If you need to read the test body to understand the failure, the name is wrong. Format: `Test{Thing}_{Condition}_{ExpectedResult}`.
6. **Coverage strategy over coverage percentage** — 80% coverage with good boundary testing beats 95% that only tests happy paths. Measure what classes of bugs you catch, not line counts.
7. **Gate-aligned test design** — Design test suites so gate reviewers can trace each acceptance criterion to a passing test. Group tests by criterion, not by implementation file.

**Quality Criteria**: Light edit existing.

**Anti-Patterns**: Light edit existing 4 rows.

**Context Requirements**: Drop Exclude. Keep Required + Helpful.

## relational-db-architect.md (NEW — draws from database-architect.md)

**Reasoning patterns** (7):
1. **Constraint-first modeling** — Express business rules as CHECK, FK, UNIQUE constraints, not application code. If the database can enforce it, it should. Application-level validation is a convenience; database constraints are the guarantee.
2. **Migration safety calculus** — Every schema change gets asked: "What happens if the deploy fails halfway? Can we roll back?" Two-phase migrations for anything destructive. Never drop and add in the same migration.
3. **Normalization-then-justify** — Start normalized (3NF minimum). Denormalize only with a documented justification, a sync mechanism, and a staleness budget. Undocumented denormalization is a time bomb.
4. **Transaction boundary reasoning** — Where does a transaction begin and end? What's the blast radius of a failed write? Choose isolation levels deliberately — serializable is not always the answer, and read-committed is not always enough.
5. **Join-path planning** — Design schemas with query join paths in mind. If the most common query requires 4 joins, the schema serves the ER diagram, not the application. Optimize for actual access patterns.
6. **Index cost awareness** — Every index speeds reads but slows writes. Know the write amplification. Only index what queries actually need. Composite indexes serve the leftmost prefix — order columns by selectivity.
7. **Schema as reviewable artifact** — Migrations and schema changes are deliverables with rollback plans and performance impact assessments. A schema change without a tested rollback is not ready to ship.

**Domain Expertise**: New paragraph — relational data modeling, normalization, constraint design, migration safety, query optimization. Thinks from the consistency and durability perspective.

**Quality Criteria**: Adapted from database-architect.md — reversible migrations, FK constraints, index coverage, two-phase migration pattern.

**Anti-Patterns**: Adapted from database-architect.md — columns without defaults on large tables, N+1 patterns, unsynced denormalization, same-migration drop+add.

**Context Requirements**: Required: schema files, migration history, repository interfaces. Helpful: query baselines, DB config, ORM models.

## document-db-architect.md (NEW)

**Reasoning patterns** (7):
1. **Access-pattern-first modeling** — Design documents around how they'll be read, not how entities relate. The shape of the document is the shape of the query. If a read requires assembling data from 3 collections, the model is wrong.
2. **Embedding vs. referencing** — Nest subdocuments when the child is always read with the parent and rarely updated independently. Reference when the child has independent lifecycle, is shared across parents, or grows unboundedly. Size and update frequency are the deciding factors.
3. **Schema evolution strategy** — Documents evolve. Plan for old and new shapes coexisting in production. Every field addition needs a default for existing documents. Renames require dual-read periods. Removals require confirming no reader depends on the field.
4. **Consistency tradeoff mapping** — Know where you need strong consistency and where eventual is acceptable. Map each operation to its consistency requirement explicitly. "Eventually consistent" is not an excuse for undefined behavior — specify the staleness budget.
5. **Aggregation avoidance** — Design documents to serve reads directly, not through complex aggregation pipelines. If a dashboard requires a 7-stage aggregation, the data model is fighting the access pattern. Pre-compute or reshape.
6. **Data lifecycle thinking** — TTL indexes for ephemeral data, archival strategies for cold data, sharding key selection from day one. A collection that grows forever is a collection that eventually falls over.
7. **Schema as reviewable artifact** — Collection design docs and migration plans are deliverables. A schema change in a schemaless database needs more documentation than a relational migration, not less, because the database won't enforce it.

**Domain Expertise**: New paragraph — document data modeling, denormalization-by-design, schema evolution, consistency tradeoffs. Thinks from the access-pattern perspective.

**Quality Criteria**: New — documents shaped for primary access pattern, embedding decisions documented with rationale, TTL/archival configured for ephemeral collections, migrations include dual-read compatibility.

**Anti-Patterns**: New table — unbounded arrays in documents, cross-collection joins as default pattern, schemaless-means-no-schema thinking, ignoring document size limits.

**Context Requirements**: Required: collection schemas/samples, primary access patterns, consistency requirements. Helpful: query profiles, index usage stats, driver/ODM configuration.
