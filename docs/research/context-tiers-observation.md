# Context Management Tiers — Observation from V1 Experience

Source: Operator experience across multiple projects and agent workflows.

## Observation

Three distinct lifespans of useful context have emerged in practice:

### 1. Project-level (long-lived)

Infrastructure, tooling, product non-negotiables, long-running priorities, architectural decisions. Managed throughout a project's lifetime. Changes slowly. Relevant to every session.

### 2. Work-level (medium-lived)

Review docs, specs, feature/initiative scope, design decisions, research findings. Managed throughout a piece of work. Relevant to sessions working on that specific initiative.

### 3. Record-level (short-lived, accumulating)

Checkpoint gates, atomized work logs, dependency tracking, detail organization. Created during execution. Serves as a log of record. Relevant for continuity between sessions and for audit.

## Why This Matters

Each tier has different:

- **Lifespan**: months vs. weeks vs. hours
- **Audience**: all sessions vs. task-specific sessions vs. the next session
- **Update frequency**: rarely vs. at milestones vs. continuously
- **Retrieval pattern**: always loaded vs. loaded on demand vs. queried when needed

A harness that treats all context the same (loading everything every time) creates bloat. One that separates tiers can load only what's relevant to the current scope.

## Open Questions (Not Prescriptions)

- Is three the right number of tiers, or does it collapse/expand?
- What's the right storage and retrieval mechanism for each tier?
- How does context flow between tiers? (e.g., a record-level finding that becomes a project-level decision)
- How does this interact with context window budgets?
- Should tiers map to different tools/formats, or is there a unified model?
