# Spec: furrow-restructure

## Overview

Move all harness state under `.furrow/`, rename "work unit" to "row", update 127+ file references, and rename state.json fields in existing row data.

## Migration Script: scripts/migrate-to-furrow.sh

### Interface
```
migrate-to-furrow.sh [--dry-run]
```
- `--dry-run`: print actions without executing
- Exit 0 on success, 1 on error
- Idempotent: safe to run multiple times

### Operations (in order)

1. **Create .furrow/ structure**
   ```
   mkdir -p .furrow/rows .furrow/seeds .furrow/almanac
   ```

2. **Move row directories**
   ```
   for dir in .work/*/; do
     name=$(basename "$dir")
     [ "$name" = "_meta.yaml" ] && continue
     mv "$dir" ".furrow/rows/$name/"
   done
   ```

3. **Move metadata files**
   ```
   [ -f .work/.focused ] && mv .work/.focused .furrow/.focused
   [ -f .work/_meta.yaml ] && mv .work/_meta.yaml .furrow/_meta.yaml
   ```

4. **Move seeds data** (if .beans/ exists)
   ```
   if [ -d .beans ]; then
     mv .beans/issues.jsonl .furrow/seeds/seeds.jsonl
     mv .beans/config .furrow/seeds/config
     [ -f .beans/.lock ] && mv .beans/.lock .furrow/seeds/.lock
     rmdir .beans 2>/dev/null || true
   fi
   ```

5. **Move almanac data**
   ```
   [ -f todos.yaml ] && mv todos.yaml .furrow/almanac/todos.yaml
   [ -f ROADMAP.md ] && mv ROADMAP.md .furrow/almanac/roadmap.md
   [ -f _rationale.yaml ] && mv _rationale.yaml .furrow/almanac/rationale.yaml
   ```

6. **Rename state.json fields** in all existing rows
   ```
   for state in .furrow/rows/*/state.json; do
     jq '.seed_id = .issue_id | .epic_seed_id = .epic_id | del(.issue_id, .epic_id)' \
       "$state" > "$state.tmp" && mv "$state.tmp" "$state"
   done
   ```

7. **Update .gitattributes** if it references `.beans/issues.jsonl`
   ```
   sed -i 's|\.beans/issues\.jsonl|.furrow/seeds/seeds.jsonl|g' .gitattributes
   ```

8. **Clean up** empty `.work/` directory
   ```
   rmdir .work 2>/dev/null || true
   ```

### Edge cases
- `.work/` doesn't exist → skip row migration
- `.beans/` doesn't exist → skip seeds migration
- `todos.yaml` doesn't exist → skip almanac migration
- Row in mid-transition (step_status=pending_approval) → move as-is, no special handling
- Symlinks in `.work/` → preserve (mv handles this)
- Script already ran → idempotent (checks if target exists before moving)

## Source Code Reference Updates

### Pattern: `.work/` → `.furrow/rows/`
Apply to all .sh, .md, .yaml, .json, .py files (excluding .furrow/rows/ data).

### Pattern: `work.unit` → `row` (case-insensitive)
- `work-unit` → `row` in kebab-case contexts
- `work_unit` → `row` in snake_case contexts
- `Work Unit` → `Row` in title case
- `work unit` → `row` in prose

### Pattern: `init-work-unit` → `rws init` (in command references)

### Files to rename
- `references/work-unit-layout.md` → `references/row-layout.md`
- `references/work-unit-meta.yaml` → `references/row-meta.yaml`
- `hooks/work-check.sh` → `hooks/row-check.sh`

### Config updates

**.claude/furrow.yaml:**
```yaml
# Replace beans section:
seeds:
  prefix: ""    # Set during sds init
```

**.claude/CLAUDE.md:**
- Update all `.work/` references to `.furrow/rows/`
- Update "work unit" to "row"
- Update command table if it references old scripts

**install.sh:**
- Add sds, rws, alm to symlink table

### Verification

After all updates, run:
```sh
grep -rn '\.work/' --include='*.sh' --include='*.yaml' --include='*.json' --include='*.md' \
  --exclude-dir=.furrow --exclude-dir=.git
```
Must return zero results.

```sh
grep -rni 'work.unit' --include='*.sh' --include='*.md' \
  --exclude-dir=.furrow --exclude-dir=.git
```
Must return zero results (excluding changelog/history references).

## Acceptance Criteria Tests

| AC | Test |
|---|---|
| No .work/ references | grep verification returns 0 results |
| No "work unit" references | grep verification returns 0 results |
| Migration script moves all data | Run on test .work/ dir, verify .furrow/ structure |
| Migration is idempotent | Run twice, second run is a no-op |
| Edge cases handled | Test with missing .beans/, missing todos.yaml, mid-transition row |
| state.json fields renamed | jq '.seed_id' on migrated state.json returns value (even if null) |
| references/ files renamed | ls references/row-layout.md succeeds |
| Config updated | grep 'seeds:' .claude/furrow.yaml succeeds |
