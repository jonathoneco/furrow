# Team Plan: Isolated Gate Evaluation

## Scope Analysis

8 deliverables across 3 phases (6 waves). All single-specialist (harness-engineer).
Waves 2 and 5 have parallel deliverables. No cross-specialist conflicts.

## Team Composition

Single implementer — all deliverables share the same specialist type and the
dependency chain is strictly sequential between phases. Parallel agents used
within waves 2 and 5 only.

| Wave | Deliverables | Agent Strategy |
|------|-------------|---------------|
| 1 | gate-yaml-schema | Single agent |
| 2 | ideation-gate-migration + evaluator-prompt-template | 2 parallel agents |
| 3 | gate-orchestration-and-gradient | Single agent |
| 4 | script-rewire | Single agent |
| 5 | skill-docs-alignment + protocol-docs-update | 2 parallel agents |
| 6 | consumer-updates | Single agent |

## Task Assignment

### Phase 1: Foundation (Waves 1-2)
- **Wave 1**: Create 7 gate YAML files per `specs/phase1-foundation.md`
- **Wave 2a**: Migrate ideation-gate.md to YAML
- **Wave 2b**: Write evaluator prompt template
- **Commit at phase boundary**: `feat: add gate evaluation YAML schema and evaluator template`

### Phase 2: Integration (Waves 3-4)
- **Wave 3**: Create run-gate.sh, select-gate.sh. Update decided_by vocabulary in
  evaluate-gate.sh, record-gate.sh, update-state.sh, both schema files.
- **Wave 4**: Rename scripts (run-eval.sh → check-artifacts.sh, auto-advance.sh →
  gate-precheck.sh). Delete scripts/auto-advance.sh. Update validate-summary.sh.
  Run grep sweep. Execute smoke tests.
- **Commit at phase boundary**: `feat: rewire gate evaluation to Phase A + isolated subagent Phase B`

### Phase 3: Alignment (Waves 5-6)
- **Wave 5a**: Update 8 step skills with new terminology and subsections
- **Wave 5b**: Rewrite eval-protocol.md and gate-protocol.md
- **Wave 6**: Update all remaining consumers (13 files). Run final grep sweep.
- **Commit at phase boundary**: `docs: align documentation with isolated gate evaluation architecture`

## Coordination

- Phase boundaries are commit points for rollback safety.
- Wave 4 (script-rewire) is the highest-risk wave — run pre/post grep sweeps.
- Wave 6 (consumer-updates) must verify zero references to old names remain.
- Each spec file includes its own verification checklist — agents should follow these.

## Specs

| Deliverable | Spec File |
|-------------|-----------|
| gate-yaml-schema | specs/phase1-foundation.md |
| ideation-gate-migration | specs/phase1-foundation.md |
| evaluator-prompt-template | specs/phase1-foundation.md |
| gate-orchestration-and-gradient | specs/d4-gate-orchestration-and-gradient.md |
| script-rewire | specs/d5-script-rewire.md |
| skill-docs-alignment | specs/d6-skill-docs-alignment.md |
| protocol-docs-update | specs/d7-protocol-docs-update.md |
| consumer-updates | specs/d8-consumer-updates.md |
