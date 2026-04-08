# Spec: config-move-and-source-todo

## Interface Contract

**Config location change**: `.claude/furrow.yaml` → `.furrow/furrow.yaml`

**Candidate loop** (shared pattern for all readers):
```sh
furrow_yaml=""
for candidate in .furrow/furrow.yaml .claude/furrow.yaml; do
  if [ -f "$candidate" ]; then
    furrow_yaml="$candidate"
    break
  fi
done
```

**Template source** (in Furrow repo): The template file moves from `.claude/furrow.yaml` to root-level or stays as template at the same location — init/install copy to `.furrow/furrow.yaml` in consumer projects.

**source_todo wiring**: `commands/next.md` reads `state.json` `source_todo` field and includes it in handoff prompts when non-null.

## Acceptance Criteria (Refined)

1. Template file exists at `.furrow/furrow.yaml` (or equivalent location in Furrow source repo)
2. `frw init` creates config at `.furrow/furrow.yaml` in consumer projects (not `.claude/`)
3. `frw install` copies config to `.furrow/furrow.yaml` (not `.claude/`)
4. All runtime readers use candidate loop — `.furrow/furrow.yaml` first, `.claude/furrow.yaml` fallback
5. Affected runtime files updated: correction-limit.sh, run-ci-checks.sh
6. Text references updated: commands/work.md, commands/init.md, commands/update.md
7. `commands/next.md` includes `source_todo` from state.json in handoff prompts when non-null
8. Existing consumer projects with `.claude/furrow.yaml` continue to work (backward compat)

## Test Scenarios

### Scenario: New project gets .furrow/furrow.yaml
- **Verifies**: AC 2
- **WHEN**: `frw init` runs in a directory with no existing furrow.yaml
- **THEN**: `.furrow/furrow.yaml` exists, `.claude/furrow.yaml` does NOT exist
- **Verification**: `test -f .furrow/furrow.yaml && ! test -f .claude/furrow.yaml`

### Scenario: Old project fallback
- **Verifies**: AC 4, 8
- **WHEN**: Consumer project has `.claude/furrow.yaml` but no `.furrow/furrow.yaml`
- **THEN**: Runtime readers find and use `.claude/furrow.yaml`
- **Verification**: `frw doctor` succeeds in a project with only `.claude/furrow.yaml`

### Scenario: source_todo in handoff
- **Verifies**: AC 7
- **WHEN**: Row state.json has `source_todo: "consumer-project-furrow-root"` and `/furrow:next` generates a handoff
- **THEN**: Handoff prompt includes the source_todo reference
- **Verification**: Manual — check generated handoff text includes `source_todo`

## Implementation Notes

### File-by-file changes:

1. **bin/frw.d/init.sh**:
   - Line 53: Change `.claude/furrow.yaml` check to `.furrow/furrow.yaml`
   - Line 57: Copy template to `.furrow/furrow.yaml`
   - Lines 61-106: All `sed -i` targets change to `.furrow/furrow.yaml`
   - Ensure `.furrow/` directory exists before copy (init already creates it)

2. **bin/frw.d/install.sh**:
   - Line 387: Template source stays at `$FURROW_ROOT/.claude/furrow.yaml` (Furrow's own template)
   - Line 388: Target changes to `$TARGET_FURROW/furrow.yaml` where `TARGET_FURROW=.furrow`
   - Line 551: Message updates to reference `.furrow/furrow.yaml`
   - Consider: keep template in Furrow repo at `.claude/furrow.yaml` for now (avoids self-referential move)

3. **bin/frw.d/hooks/correction-limit.sh**:
   - Line 46-47: Replace hardcoded `.claude/furrow.yaml` with candidate loop

4. **bin/frw.d/scripts/run-ci-checks.sh**:
   - Line 30: Replace `${FURROW_ROOT}/.claude/furrow.yaml` with candidate loop using `$PROJECT_ROOT`
   - Note: FURROW_ROOT→PROJECT_ROOT already fixed by wave 1

5. **tests/integration/helpers.sh**:
   - Line 51: Change path from `.claude/furrow.yaml` to `.furrow/furrow.yaml`

6. **commands/work.md, init.md, update.md**: Text reference updates

7. **commands/next.md**: Add instruction to read `state.json` source_todo when generating handoff

### Template location decision:
Keep the template at `.claude/furrow.yaml` in the Furrow source repo for now. Install/init copy it to `.furrow/furrow.yaml` in consumer projects. This avoids a self-referential change where Furrow's own config would need to move.

## Dependencies

- Depends on: project-root-resolution (run-ci-checks.sh uses PROJECT_ROOT)
- Also modifies: `.claude/CLAUDE.md` topic routing table (furrow.yaml path reference)
