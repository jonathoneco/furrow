# Spec: harness-registration

- **Deliverable**: Symlink + reference repairs
- **Specialist**: harness-engineer
- **Depends on**: triage-command-spec

## Symlink Changes

### Create
```
.claude/commands/harness:triage.md → ../../commands/triage.md
```

### Remove
```
.claude/commands/work-roadmap.md (if exists — currently doesn't have one)
commands/work-roadmap.md (delete the file)
```

## Reference Repairs

### Active files to update (replace `/work-roadmap` with `/harness:triage`):

1. **`.claude/CLAUDE.md:66`** — command table
   - Old: `| /work-roadmap | Generate ROADMAP.md from todos.yaml |`
   - New: `| /harness:triage | Triage todos.yaml and generate ROADMAP.md |`

2. **`templates/roadmap-sections.yaml:2`** — comment
   - Old: `# Defines section order, requirements, and rendering hints for /work-roadmap`
   - New: `# Defines section order, requirements, and rendering hints for /harness:triage`

3. **`adapters/shared/schemas/todos.schema.yaml`** — 5 field descriptions
   - Replace all `(populated by /work-roadmap triage)` with `(populated by /harness:triage)`

4. **`ROADMAP.md:47`** — T7 description
   - Replace `/work-roadmap` with `/harness:triage` in the T7 summary

### Files NOT to repair (historical/archived):
- `.work/roadmap-process/` — T7's archived work unit. Leave unchanged.

## Acceptance Criteria Verification

- [x] Symlink `.claude/commands/harness:triage.md` points to `../../commands/triage.md`
- [x] Old symlink `.claude/commands/work-roadmap.md` removed (n/a — doesn't exist)
- [x] `commands/work-roadmap.md` deleted
- [x] CLAUDE.md command table updated
- [x] All active references to `/work-roadmap` repaired
