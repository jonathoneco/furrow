# Spec: reference-cleanup

## Interface Contract

No new interfaces. This deliverable updates all references across the codebase and deletes old files.

## Reference Map (from research)

### Phase 1: Update references (same commit as D2-D5)

**Commands (~6 refs)**:
- `commands/work.md`: 3× `scripts/run-gate.sh` → `frw run-gate`
- `commands/doctor.md`: 1× `scripts/furrow-doctor.sh` → `frw doctor`
- `commands/checkpoint.md`: 1× `scripts/run-gate.sh` → `frw run-gate`
- `commands/init.md`: update to reference `frw init` as implementation

**Skills (~3 refs)**:
- `skills/ideate.md`: 1× `scripts/validate-definition.sh` → `frw validate-definition`
- `skills/work-context.md`: 1× `scripts/evaluate-gate.sh` → `frw evaluate-gate`
- `skills/shared/git-conventions.md`: 1× `scripts/merge-to-main.sh` → `frw merge-to-main`

**References (~7 refs)**:
- `references/gate-protocol.md`: 5× various script paths → `frw <subcommand>`
- `references/deduplication-strategy.md`: 2× `scripts/measure-context.sh` → `frw measure-context`

**CLAUDE.md (~1 ref)**:
- `.claude/CLAUDE.md`: 1× `scripts/measure-context.sh` → `frw measure-context`

**Rationale (~32 path entries)**:
- `.furrow/almanac/rationale.yaml`: All `hooks/<name>.sh` → `bin/frw.d/hooks/<name>.sh`
- `.furrow/almanac/rationale.yaml`: All `scripts/<name>.sh` → `bin/frw.d/scripts/<name>.sh`
- `.furrow/almanac/rationale.yaml`: `hooks/lib/common.sh` → `bin/frw.d/lib/common.sh`
- `.furrow/almanac/rationale.yaml`: `hooks/lib/validate.sh` → `bin/frw.d/lib/validate.sh`

**TODOs (~19 refs)**:
- `.furrow/almanac/todos.yaml`: Update paths in work items referencing hooks/ and scripts/

**Tests (~6 refs)**:
- `tests/integration/test-generate-plan.sh`: Replace script symlinks with `frw` invocations

**Agent SDK adapters (~4 refs)**:
- `adapters/agent-sdk/callbacks/state_mutation.py`: `hooks/lib/validate.sh` → `frw validate-state` or updated path
- Other adapter files with hardcoded hook paths

### Phase 2: Delete old directories (separate commit, after Phase 1 verified)

Delete:
- `hooks/state-guard.sh` through `hooks/post-compact.sh` (10 files)
- `hooks/lib/common.sh`, `hooks/lib/validate.sh`
- `scripts/update-state.sh` through `scripts/run-integration-tests.sh` (17 files)

Keep:
- `hooks/` and `scripts/` directories can be removed entirely (empty after deletion)
- OR keep as empty dirs with `.gitkeep` if any tooling expects them

### Phase 3: Verify

- Run `frw doctor` — must pass with new paths
- Run `frw install --check` — must pass
- Run integration tests — must pass

## Acceptance Criteria (Refined)

1. Zero references to `hooks/<name>.sh` or `scripts/<name>.sh` remain in commands/, skills/, references/, .claude/
2. rationale.yaml has all 32 path entries updated to `bin/frw.d/` paths
3. todos.yaml path references updated
4. Agent SDK adapter files updated to use `frw` or new paths
5. Integration tests pass using `frw` interface
6. `frw doctor` passes after all updates
7. Old `hooks/*.sh` and `scripts/*.sh` files deleted
8. `hooks/lib/` directory deleted

## Implementation Notes

- Use grep/ripgrep to verify no remaining references before committing deletion
- rationale.yaml updates are mechanical: `s|hooks/|bin/frw.d/hooks/|g` and `s|scripts/|bin/frw.d/scripts/|g` with path field targeting
- Agent SDK adapter changes may need Python-side testing
- Integration test changes: remove symlink setup, use `frw` CLI calls

## Dependencies

- D2: hook-migration
- D3: script-migration
- D5: frw-install
