# Shared Conventions Reference

Quick-reference for adapter developers. See spec 00 for full details.

## File Path Conventions (spec 00 §2)

| Path | Purpose |
|------|---------|
| `.work/{name}/` | Work unit directory (kebab-case name) |
| `.work/{name}/definition.yaml` | Work contract |
| `.work/{name}/state.json` | Lifecycle and progress |
| `.work/{name}/summary.md` | Context recovery document |
| `.work/{name}/plan.json` | Execution plan with waves |
| `.work/{name}/team-plan.md` | Team coordination audit |
| `.work/{name}/reviews/{deliverable}.json` | Per-deliverable review results |
| `.work/{name}/gates/{from}-to-{to}.json` | Extended gate evidence |
| `.work/{name}/research.md` or `research/` | Research findings |
| `.work/{name}/spec.md` or `specs/` | Component specifications |

## Naming Conventions (spec 00 §7)

| Element | Convention | Example |
|---------|-----------|---------|
| Work unit directory | kebab-case | `.work/add-rate-limiting/` |
| Deliverable names | kebab-case | `rate-limiter-middleware` |
| Specialist types | kebab-case | `api-designer` |
| JSON schema fields | snake_case | `step_status`, `created_at` |
| YAML schema fields | snake_case | `gate_policy`, `depends_on` |
| Enum values | lowercase | `in_progress`, `not_started` |
| Timestamps | ISO 8601 with timezone | `2026-04-01T10:00:00Z` |
| Identifiers | kebab-case | `rate-limiter-middleware` |

## Step Sequence (spec 00 §3)

```
ideate -> research -> plan -> spec -> decompose -> implement -> review
```

All 7 steps are traversed. No steps are skipped.

## Write Ownership (spec 00 §2.3)

| File | Writer | Readers |
|------|--------|---------|
| `definition.yaml` | Human or ideation agent | All |
| `state.json` | Harness only | All (read-only) |
| `plan.json` | Coordinator (write-once) | All |
| `summary.md` | Harness + step agent | Next-step agent |
| `team-plan.md` | Lead agent | Specialists, reviewers |
| `reviews/*.json` | Review agent | Harness, human |

## Canonical Terms (spec 00 §7.1)

| Concept | Term | Never Use |
|---------|------|-----------|
| Parallel work units | Deliverables | streams, tasks, work items |
| Domain agents | Specialists | agents, workers |
| Step transition check | Gate | checkpoint, approval |
| Context recovery doc | Summary | handoff prompt |
| Concurrency groups | Waves | phases |
| Structured evaluation | Dimension rubric | checklist, scorecard |
