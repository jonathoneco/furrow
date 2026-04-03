# frw-cli-dispatcher — Research

## 1. Reference Surface Area

### bin/rws (the biggest consumer)
Only **2 direct script references** — much smaller than expected:
- Line 456: `${FURROW_ROOT}/scripts/validate-definition.sh` (in `validate_step_artifacts()`)
- Line 903: `${FURROW_ROOT}/scripts/measure-context.sh` (in `regenerate_summary()`)

Neither is in a loop or performance-sensitive path. Both capture output/exit codes.

**bin/sds and bin/alm**: Zero references to scripts/ or hooks/. Fully self-contained.

### Commands, Skills, References (~15 references)
- `commands/work.md`: 3 refs to `scripts/run-gate.sh`
- `commands/doctor.md`: 1 ref to `scripts/furrow-doctor.sh`
- `commands/checkpoint.md`: 1 ref to `scripts/run-gate.sh`
- `skills/ideate.md`: 1 ref to `scripts/validate-definition.sh`
- `skills/work-context.md`: 1 ref to `scripts/evaluate-gate.sh`
- `skills/shared/git-conventions.md`: 1 ref to `scripts/merge-to-main.sh`
- `references/gate-protocol.md`: 5 refs to various scripts
- `references/deduplication-strategy.md`: 2 refs to `scripts/measure-context.sh`
- `.claude/CLAUDE.md`: 1 ref to `scripts/measure-context.sh`

### Rationale and TODOs (~50 references)
- `.furrow/almanac/rationale.yaml`: 32 path entries for hooks and scripts
- `.furrow/almanac/todos.yaml`: ~19 references in work items

### Tests
- `tests/integration/test-generate-plan.sh`: symlinks `scripts/generate-plan.sh` and `hooks/lib/validate.sh` into fixtures, invokes directly (5 test cases)

### Agent SDK Adapters (BLOCKER for deletion)
- `adapters/agent-sdk/callbacks/state_mutation.py`: hardcoded `hooks/lib/validate.sh` path
- Several other adapter files reference hook paths via subprocess calls

### install.sh
- ~11 references: symlink loops, check patterns, CLAUDE.md injection

**Total: ~90+ references across the codebase.**

## 2. Open Question Resolutions

### Q1: How should rws call migrated scripts?
**Answer: `frw script <name>` CLI invocation.**

Only 2 non-looped calls, both capture output/exit codes which work fine through exec. Maintains clean interface boundary — rws doesn't need to know frw internals.

```sh
# Before:
"${FURROW_ROOT}/scripts/validate-definition.sh" "$_va_def_file"
# After:
frw script validate-definition "$_va_def_file"
```

### Q2: Should old hooks/ and scripts/ be deleted in same commit?
**Answer: No — separate commit after migration.**

The agent-sdk adapters directly invoke `hooks/lib/validate.sh` via subprocess. Tests expect the directories. Phased approach:
1. Commit: Create frw with all functionality, update settings.json and rws
2. Commit: Update agent-sdk adapters, tests
3. Commit: Delete old hooks/ and scripts/

This means D6 (reference-cleanup) should be split: reference updates first, directory deletion last.

### Q3: How should integration tests work after migration?
**Answer: Use `frw script <name>` interface, not direct path invocation.**

- `test-rws.sh` is already correct (tests rws CLI, not scripts directly)
- `test-generate-plan.sh` needs update: replace symlink+direct invocation with `frw script generate-plan`
- `helpers.sh` already adds `$PROJECT_ROOT/bin` to PATH, so `frw` will be available

## 3. Discoveries

### Agent SDK is a migration dependency
The adapters in `adapters/agent-sdk/` hardcode paths to `hooks/lib/validate.sh`. These must be updated before old directories can be deleted. This wasn't in the original definition — it should be added to D6 or split into its own concern.

### rws is simpler than expected
Only 2 script references. The migration of rws itself is trivial — the real work is in the 50+ documentation/rationale references and the 10 hooks.

### Rationale.yaml is the largest single file to update
32 path entries need updating. Since these are structured YAML with `path:` fields, this is mechanical but needs care to avoid breaking the rationale manifest.
