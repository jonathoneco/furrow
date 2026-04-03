# Research: Replace /work-roadmap with /harness:triage

## Deliverable: triage-command-spec

The existing `commands/work-roadmap.md` is a complete 10-step pipeline spec (219 lines). It will be adapted into `commands/triage.md` with these changes:
- Renamed invocation: `/harness:triage [--full]`
- All 10 steps preserved (validate, resolve template, run triage, preserve completed phases, AI assessment, group phases, generate ROADMAP.md, confirm, write, auto-commit)
- No structural changes to the pipeline logic

The existing spec's step 5 (AI assessment) describes the exact behavior needed — infer urgency/impact/effort/depends_on from prose. No new design required.

## Deliverable: harness-registration

### Reference scan — files that mention `/work-roadmap`:

**Active files to repair (8):**
1. `.claude/CLAUDE.md:66` — command table entry
2. `templates/roadmap-sections.yaml:2` — comment referencing the command
3. `adapters/shared/schemas/todos.schema.yaml` — 5 description fields say "populated by /work-roadmap triage"
4. `ROADMAP.md:47` — T7 description references `/work-roadmap` command
5. `commands/work-roadmap.md` — the file itself (delete)

**Archived/work-unit files (not repaired — historical):**
- `.work/roadmap-process/` — T7's work unit (archived). ~20 references. Leave as-is; it's historical.
- `.work/triage-todos-harness-skill/` — our own definition. Will naturally reference the new name.

### Symlink mechanism

Current `.claude/commands/` has symlinks to `/home/jonco/src/work-harness-v2/commands/`. Project-local commands (`work-roadmap.md`, `work-todos.md`) live in `commands/` without `.claude/commands/` symlinks — they're discovered via a different path.

For `/harness:triage` with the `harness:` prefix, create a symlink:
```
.claude/commands/harness:triage.md → ../../commands/triage.md
```

## Deliverable: work-todos-auto-commit

`commands/work-todos.md` currently has no commit step. After step 8 (validate), add:

```
### 9. Commit
git add todos.yaml
git commit -m "chore: update todos.yaml via /work-todos"
```

For extract mode, the commit message should reference the source work unit:
```
chore: extract TODOs from {name} into todos.yaml
```

For new mode:
```
chore: add TODO {id} to todos.yaml
```

## Deliverable: glob-regex-bugfix

**The bug:** In `triage-todos.sh` lines 202-203, the glob-to-regex conversion does:
```jq
gsub("\\*\\*"; ".*") | gsub("\\*"; "[^/]*")
```

This fails on bare directory paths like `skills/shared/` — the path has no glob characters, so `test()` treats it as a literal regex match. A file like `skills/shared/red-flags.md` won't match the regex `skills/shared/` because the slash at the end requires exactly that termination.

**The fix:** Before applying glob conversion, detect trailing `/` and append `**` to make it `skills/shared/**`, which then converts to `skills/shared/.*`. This matches all files under that directory.

The conversion should be:
```jq
gsub("/$"; "/**") | gsub("\\*\\*"; ".*") | gsub("\\*"; "[^/]*")
```

## Cross-cutting finding: validate-step-artifacts.sh

During ideation, discovered that `scripts/validate-step-artifacts.sh` was missing the `ideate->research` boundary case. Already fixed — added validation that `definition.yaml` exists, is non-empty, and passes schema validation. This fix should be committed alongside the main deliverables.
