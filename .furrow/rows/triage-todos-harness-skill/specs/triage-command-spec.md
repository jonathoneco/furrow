# Spec: triage-command-spec

- **Deliverable**: `commands/triage.md`
- **Specialist**: harness-engineer
- **Replaces**: `commands/work-roadmap.md`

## Overview

Adapt the existing `/work-roadmap` command spec into `/harness:triage`. The content is largely the same 10-step pipeline; the changes are the command name, invocation syntax, and minor wording updates.

## File: `commands/triage.md`

### Header

```markdown
# /harness:triage [--full]
```

Replace all internal references from `/work-roadmap` to `/harness:triage`.

### Invocation syntax

```
/harness:triage        → Incremental: preserve completed phases, update remaining
/harness:triage --full → Full regeneration: re-evaluate all phases from scratch
```

### 10-Step Pipeline (preserve from work-roadmap.md)

1. **Validate inputs** — check todos.yaml exists, run `scripts/validate-todos.sh`
2. **Resolve template** — check harness.yaml > `.claude/roadmap.tmpl` > `templates/roadmap.md.tmpl`
3. **Run triage script** — `scripts/triage-todos.sh todos.yaml`, parse JSON output
4. **Preserve completed phases** (incremental only) — read existing ROADMAP.md, keep DONE phases
5. **Triage missing metadata** — AI reasons about urgency/impact/effort/depends_on for TODOs missing fields
6. **Group into phases** — file conflicts, logical coupling, quick wins, critical path
7. **Generate ROADMAP.md** — follow template section order from roadmap-sections.yaml
8. **Present for confirmation** — display proposal, wait for ok/adjust/cancel
9. **Write outputs** — update todos.yaml with triage fields, write ROADMAP.md (atomic)
10. **Commit** — `git add ROADMAP.md todos.yaml && git commit -m "docs: regenerate ROADMAP.md via /harness:triage"`

For `--full` mode, commit message: `"docs: regenerate ROADMAP.md (full) via /harness:triage"`

### Error conditions (preserve from work-roadmap.md)

All error messages should reference `/harness:triage`, not `/work-roadmap`.

## Acceptance Criteria Verification

- [x] `commands/triage.md` defines `/harness:triage` with full 10-step pipeline
- [x] Steps: validate, resolve template, run triage, preserve completed phases, AI assessment, phase grouping, generate ROADMAP.md, confirm, write, auto-commit
- [x] Bare invocation preserves completed phases; `--full` regenerates everything
- [x] AI assessment infers urgency/impact/effort/depends_on from prose
- [x] Phase grouping respects dependency order and file conflict zones
- [x] Worktree commands generated for parallel phases
- [x] Auto-commits both ROADMAP.md and todos.yaml
