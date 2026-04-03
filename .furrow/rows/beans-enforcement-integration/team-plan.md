# Team Plan: Seeds Integration

## Principle

CLIs are the abstraction layer. The harness interacts with row lifecycle, seed tracking, and almanac functionality exclusively through `rws`, `sds`, and `alm`. No direct script calls, no inline enforcement logic in hooks.

Domain hooks (enforcement that IS lifecycle management) fold into CLIs.
Policy hooks (prescriptive rules ON TOP of lifecycle) stay separate but call CLIs.

## Wave 1 — Foundation (parallel)

### furrow-restructure (shell-specialist)
**Scope**: Directory migration + 127+ file reference updates + state.json field renames.
**Sequence**:
1. Write `scripts/migrate-to-furrow.sh` (idempotent)
2. Run migration: .work/ → .furrow/rows/, .beans/ → .furrow/seeds/, todos.yaml/ROADMAP.md/_rationale.yaml → .furrow/almanac/
3. Rename state.json fields (issue_id → seed_id, epic_id → epic_seed_id) in all existing rows
4. Update all 127+ file references (.work/ → .furrow/rows/, work unit → row)
5. Update .claude/CLAUDE.md, .claude/furrow.yaml (seeds.prefix), install.sh
6. Rename references/work-unit-layout.md → references/row-layout.md
7. **Checkpoint**: grep -r '\.work/' returns zero hits in source

### sds-cli (cli-designer)
**Scope**: Fork bn → sds with extended statuses, .furrow/seeds/ paths.
**Sequence**:
1. Copy /home/jonco/src/work-harness/bin/bn → bin/sds
2. Rename variables: BEANS_DIR → SDS_DIR, BEANS_ISSUES → SDS_ISSUES
3. Update all user-facing strings (bn → sds, beans → seeds)
4. Extend status enum: open, claimed, ideating, researching, planning, speccing, decomposing, implementing, reviewing, closed
5. Remove migrate-from-beads, add migrate-from-beans
6. Update install.sh symlink table
7. **Checkpoint**: all sds operations work, extended statuses accepted

## Wave 2 — CLIs (parallel, after wave 1)

### rws-cli (cli-designer)
**Scope**: Unify row lifecycle into monolithic CLI. Absorb domain hooks. Delete absorbed scripts.
**Sequence**:
1. Create bin/rws with subcommand dispatch (~1200 lines)
2. Implement subcommands: init, transition (two-phase), status, list, archive, gate-check, load-step, rewind, diff, focus, regenerate-summary, validate-summary
3. Fold domain hooks into rws: gate-check, summary-regen, timestamp-update
4. Remove transition-guard.sh (guarded scripts no longer exist)
5. Update all Claude Code commands to call rws subcommands
6. Update policy hooks to call rws where needed
7. Delete absorbed scripts (13 files: commands/lib/ and scripts/)
8. Update install.sh symlink table
9. **Checkpoint**: all transitions work via rws, no calls to deleted scripts

### alm-cli (cli-designer)
**Scope**: Unify TODO/roadmap into monolithic CLI.
**Sequence**:
1. Create bin/alm with subcommand dispatch (~800 lines)
2. Implement subcommands: add, extract, list, show, triage, next, validate, render
3. Update Claude Code commands (/work-todos, /furrow:triage, /furrow:next) as thin wrappers
4. Delete absorbed scripts (3 files)
5. Update install.sh symlink table
6. **Checkpoint**: alm triage generates roadmap.yaml, alm validate passes

## Wave 3 — Integration (after waves 1+2)

### seeds-row-integration (harness-engineer)
**Scope**: Wire sds into rws lifecycle, add gate dimension.
**Sequence**:
1. rws init: call sds create, store seed_id in state.json
2. rws init --seed-id: validate and link existing seed
3. rws init --source-todo: lookup/create seed, backfill todos.yaml
4. rws transition: push sds update --status <step> on each advance
5. Add Phase A.6 seed check to check-artifacts.sh
6. Create evals/dimensions/seed-consistency.yaml
7. Add seed-sync dimension to all 7 gate YAML files
8. Update gate-evaluator.md with step→status mapping
9. rws archive: call sds close
10. Update schemas: state.schema.json (seed_id), todos.schema.yaml (seed_id, legacy)
11. Update furrow.yaml: seeds.prefix (mandatory, no opt-in)
12. **Checkpoint**: full lifecycle with seed sync at every boundary

## Wave 4 — Verification + Documentation (parallel, after wave 3)

### cli-test-suite (test-engineer)
**Scope**: Delete old tests, write new CLI-framed suite.
**Sequence**:
1. Delete old integration tests (4 files)
2. Write test-sds.sh: init, create, update (all statuses), list, show, close, ready, dep, search
3. Write test-rws.sh: init, transition (two-phase supervised), status, list, archive, rewind, diff, focus
4. Write test-alm.sh: add, extract, validate, triage (roadmap.yaml), next
5. Write integration test: full lifecycle (init → transitions → archive) with seed sync verification
6. Update helpers.sh for .furrow/ paths
7. **Checkpoint**: all tests pass

### architecture-docs (harness-engineer)
**Scope**: Document the three-CLI architecture and migration path.
**Sequence**:
1. Write docs/architecture/cli-architecture.md: directory structure, CLI model, data flows, abstraction principle
2. Document hook disposition: domain vs. policy, what folded where
3. Update references/row-layout.md for .furrow/ structure
4. Update references/gate-protocol.md with seed-consistency
5. Include migration guide for existing projects
6. **Checkpoint**: docs complete and accurate
