# Team Plan: frw-cli-dispatcher

## Scope Analysis

6 deliverables across 4 waves. All shell-specialist domain. Waves 1, 3, 4 are sequential (single deliverable each). Wave 2 has 3 parallel deliverables with non-overlapping file_ownership.

Total estimated LOC: ~3600 migrated + ~200 new (dispatcher, init). This is a large mechanical migration with a few novel components (dispatcher, init, install slim-down).

## Team Composition

**Lead: shell-specialist** (main agent)
- Owns waves 1, 3, 4 (sequential deliverables)
- Coordinates wave 2 parallel agents
- Runs final verification

**Wave 2 parallel agents** (3 subagents, one per deliverable):
- **hook-migrator**: Migrates 10 hooks to `bin/frw.d/hooks/`, updates settings.json
- **script-migrator**: Migrates 17 scripts to `bin/frw.d/scripts/`, updates rws refs
- **init-builder**: Implements `frw init` in `bin/frw.d/init.sh`, updates commands/init.md

## Task Assignment

### Wave 1: Foundation (lead agent)
- [ ] Create `bin/frw` dispatcher (~80 lines)
- [ ] Create `bin/frw.d/lib/common.sh` (migrate from `hooks/lib/common.sh`)
- [ ] Create `bin/frw.d/lib/validate.sh` (migrate from `hooks/lib/validate.sh`)
- [ ] Verify: `frw root`, `frw help`, `frw hook` sourcing works

### Wave 2: Migration (3 parallel agents)

**hook-migrator**:
- [ ] Create 10 files in `bin/frw.d/hooks/` with `hook_<name>()` functions
- [ ] Update `.claude/settings.json` to `frw hook <name>`
- [ ] Test: state-guard block/allow, gate-check block/allow

**script-migrator**:
- [ ] Create 17 files in `bin/frw.d/scripts/` with `frw_<name>()` functions
- [ ] Update inter-script calls to `frw <subcommand>`
- [ ] Update `bin/rws` lines 456, 903
- [ ] Test: `frw update-state`, `frw doctor`, `frw validate-definition`

**init-builder**:
- [ ] Implement `frw_init()` in `bin/frw.d/init.sh`
- [ ] Update `commands/init.md` to reference `frw init`
- [ ] Update `commands/work.md` pre-flight to call `frw init`
- [ ] Test: `frw init` in temp dir creates expected structure

### Wave 3: Install (lead agent)
- [ ] Implement `frw_install()` in `bin/frw.d/install.sh`
- [ ] Slim `install.sh` to bootstrap (~30 lines)
- [ ] Remove `hooks/`, `scripts/` from symlink list
- [ ] Test: `frw install --check`, `install.sh --global`

### Wave 4: Cleanup (lead agent)
- [ ] Update all commands/*.md references
- [ ] Update all skills/*.md and skills/shared/*.md references
- [ ] Update references/*.md
- [ ] Update .claude/CLAUDE.md
- [ ] Update .furrow/almanac/rationale.yaml (32 entries)
- [ ] Update .furrow/almanac/todos.yaml (~19 refs)
- [ ] Update adapters/agent-sdk/ files
- [ ] Update tests/integration/test-generate-plan.sh
- [ ] Delete old hooks/*.sh, scripts/*.sh, hooks/lib/
- [ ] Verify: `frw doctor` passes, zero remaining old path references

## Coordination

- Wave 2 agents work in parallel — no file_ownership overlap
- Lead agent verifies wave 2 output before starting wave 3
- Wave 4 cleanup is a sweep — run ripgrep for any remaining `hooks/` or `scripts/` references before committing deletion
- Git: one branch (`work/frw-cli-dispatcher`), commits per wave

## Skills

All agents use `specialist:shell-specialist` template. No additional skill loading required.
