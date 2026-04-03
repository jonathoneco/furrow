# Research: merge-specialist-and-legacy-todos

## Deliverable: merge-specialist

### Specialist Template Format
- YAML frontmatter: name, description, type: specialist
- Sections: Domain Expertise, How This Specialist Reasons (5-8 bold bullets), Quality Criteria, Anti-Patterns (table), Context Requirements
- Read on demand as reference layer — not counted against 300-line context budget

### Merge Mechanics (scripts/merge-to-main.sh)
- Pre-merge: row must be archived (state.json.archived_at non-null), branch must exist
- Execution: `git merge --no-ff` — never fast-forward, never squash
- Commit message: `merge: complete {row-name}` with deliverables list + gate evidence
- No auto-push — user decides when to push
- Exit codes: 0=success, 2=state not found, 3=not archived, 4=merge failed

### Wave Merge Dynamics (bin/rws check_wave_conflicts)
- Waves execute sequentially; within a wave, deliverables are concurrent
- File ownership prevents conflicts — no overlapping edits within a wave
- check_wave_conflicts() cross-references changed files against plan.json wave assignments
- Unplanned changes are warnings (non-blocking), audited at implement→review
- Worktrees available but not default; current design: single branch + ownership enforcement

### Git Conventions (docs/git-conventions.md)
- Branch lifecycle: work/{row-name}, created at decompose→implement
- Commit format: {type}({row-name}): {description} with Deliverable/Step metadata
- Periodic rebase onto main during implementation
- Merge policy: always --no-ff, requires archived row

### Reasoning Patterns to Encode
1. Pre-merge readiness checks (archived, branch exists, clean tree)
2. Rebase-before-merge discipline (when, risks, rollback)
3. Conflict detection as ownership audit (file_ownership globs)
4. No-ff merge as traceability (individual commits for bisect/blame)
5. Wave-aware merging (boundary validation, worktree option)
6. Post-merge verification (CI, test suite, working tree state)
7. Escalation paths (lead agent → specialist → user)
8. Bootstrap gap acknowledgment

---

## Deliverable: harness-engineer-grounding

### Current Context Requirements (specialists/harness-engineer.md lines 45-50)
```
- Required: hooks/lib/common.sh, hooks/lib/validate.sh, scripts/update-state.sh patterns
- Required: schemas/ directory for JSON schema patterns
- Helpful: .claude/settings.json for hook registration patterns
- Helpful: _rationale.yaml for understanding component justifications
```

### Pointers to Add (grouped by category)
**Core Architecture**: references/gate-protocol.md, references/row-layout.md, skills/work-context.md
**Evaluation**: skills/shared/gate-evaluator.md, skills/shared/eval-protocol.md, evals/gates/*.yaml, evals/dimensions/*.yaml
**Seeds**: .furrow/seeds/seeds.jsonl, .furrow/seeds/config
**Adapters**: adapters/shared/conventions.md, adapters/claude-code/_meta.yaml, adapters/agent-sdk/_meta.yaml
**Schemas**: schemas/*.schema.json, adapters/shared/schemas/*.schema.json
**CLIs**: bin/rws, bin/sds, bin/alm
**Almanac**: .furrow/almanac/rationale.yaml, .furrow/almanac/todos.yaml

### Approach
Add grouped pointer lines under Context Requirements. Each line: path + one-line role. No prose duplication.

---

## Deliverable: rationale-update

### Missing Components (25 total)

**Scripts (6)**: cross-model-review.sh (multi-model review invocation), evaluate-gate.sh (gate policy enforcement), generate-plan.sh (wave/dependency planning), migrate-to-furrow.sh (legacy→furrow migration), run-integration-tests.sh (test orchestration), select-dimensions.sh (eval dimension routing)

**Hooks (2)**: correction-limit.sh (blocks edits past correction limit), verdict-guard.sh (blocks direct gate verdict writes)

**Evals (2)**: dimensions/seed-consistency.yaml (seed-sync validation), gates/review.yaml (review step rubrics)

**CLIs (3)**: bin/alm (almanac management), bin/rws (row lifecycle), bin/sds (seed tracking)

**Specialists (12)**: cli-designer, complexity-skeptic, document-db-architect, go-specialist, harness-engineer, migration-strategist, python-specialist, relational-db-architect, security-engineer, shell-specialist, systems-architect, typescript-specialist

### Format
Each entry: path, exists_because (what Claude Code gap it fills), delete_when (when native feature arrives).
Specialists share a common pattern: "Claude Code does not natively provide domain-specific agent priming for {domain}".

---

## Deliverable: todos-roadmap-refresh

### TODOs Likely Completed by Archived Rows
- `beans-enforcement-integration` (id at line 509) — beans-enforcement-integration row archived
- `legacy-todos-migration` (id at line 531) — audit complete, nothing to migrate
- `merge-specialist` (id at line 573) — being addressed by this row
- `rename-to-furrow` (id at line 415) — namespace-rename row archived
- `almanac-knowledge-subcommands-learn-rationale-docs` (id at line 821) — cli-enhancements row archived
- `rws-review-archive-flow-and-deliverable-tracking` (id at line 834) — cli-enhancements row archived
- `default-supervised-gating` (id at line 695) — default-supervised-gating row archived

### Roadmap State
- roadmap-legacy.md exists with 8-phase DAG, 4/8 phases complete
- Phase 4 (current): namespace-rename done, supervised-gating done, beans-integration in progress
- Regeneration via `alm triage` to produce updated roadmap

### Approach
1. Mark completed TODOs as status: done with updated_at
2. Add new TODOs for architecture implications discovered during this row
3. Run `alm triage` to regenerate roadmap
4. Run `alm validate` to confirm schema compliance

---

## Legacy TODO Audit (Summary Finding)

**No orphaned TODOs found.** All 26 code-level TODOs are intentional `# TODO: customize` stubs in adapters/agent-sdk/templates/. 30+ items formally tracked in todos.yaml. Nothing to migrate.
