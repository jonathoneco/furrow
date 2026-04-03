# Spec: rationale-update

## File
`.furrow/almanac/rationale.yaml` — append entries for 25 missing components.

## Entry Format (matching existing)
```yaml
- path: {file-path}
  exists_because: "{what Claude Code gap it fills}"
  delete_when: "{when native feature makes it unnecessary}"
```

## Entries to Add

### Scripts (6)
- `scripts/cross-model-review.sh` — multi-model review invocation; delete when CC supports multi-model evaluation
- `scripts/evaluate-gate.sh` — gate policy enforcement with verdict interpretation; delete when CC provides gate policy evaluation
- `scripts/generate-plan.sh` — wave/dependency planning via topological sort; delete when CC provides native plan generation
- `scripts/migrate-to-furrow.sh` — legacy→furrow state migration; delete when migration is complete (one-time utility)
- `scripts/run-integration-tests.sh` — test orchestration with discovery; delete when CC provides test execution/reporting
- `scripts/select-dimensions.sh` — eval dimension routing by mode+step; delete when CC provides dimension routing

### Hooks (2)
- `hooks/correction-limit.sh` — blocks edits past correction limit per deliverable; delete when CC enforces correction limits natively
- `hooks/verdict-guard.sh` — blocks direct gate verdict writes (evaluator-only); delete when CC provides role-based write protection

### Evals (2)
- `evals/dimensions/seed-consistency.yaml` — seed-sync validation dimension; delete when CC validates seed consistency natively
- `evals/gates/review.yaml` — review step gate rubrics; delete when CC provides review gate evaluation

### CLIs (3)
- `bin/alm` — almanac management (todos, roadmap, learnings, rationale); delete when CC provides knowledge management UI
- `bin/rws` — row lifecycle (state transitions, gate checks, deliverable tracking); delete when CC provides row lifecycle management
- `bin/sds` — seed tracking (JSONL registry, concurrent-safe mutation); delete when CC provides seed registry

### Specialists (12)
All use pattern: "Claude Code does not natively provide domain-specific agent priming for {domain}" / "delete when CC supports built-in specialist roles with domain expertise injection"

cli-designer, complexity-skeptic, document-db-architect, go-specialist, harness-engineer, migration-strategist, python-specialist, relational-db-architect, security-engineer, shell-specialist, systems-architect, typescript-specialist
