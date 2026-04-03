## Furrow

This project uses Furrow (the V2 adaptive work harness). Task state lives in `.furrow/rows/` directories.

## Active Task Detection

Check `.furrow/rows/*/state.json` for tasks where `archived_at` is null. If found, recover
context before making changes. See `.claude/rules/workflow-detect.md` for details.

## File Conventions

- Rows: `.furrow/rows/{kebab-case-name}/`
- Core files: `definition.yaml`, `state.json`, `summary.md`, `reviews/`
- All identifiers (names, deliverables, specialists): kebab-case
- Schema fields (JSON/YAML): snake_case
- Timestamps: ISO 8601 with timezone

## Step Sequence

All rows traverse: ideate -> research -> plan -> spec -> decompose -> implement -> review

## State Ownership

`state.json` is Furrow-exclusive write. Agents read it but never write it directly.

## Context Budget Enforcement

| Layer | Budget | Content |
|-------|--------|---------|
| Ambient | <=100 lines | This file + rules/ (always loaded) |
| Work | <=150 lines | `skills/work-context.md` (during active work) |
| Step | <=50 lines | `skills/{step}.md` (per step, replaced at boundaries) |
| Reference | ~600 lines | `references/` (on demand, NOT injected) |

Total injected (ambient + work + step) must not exceed 300 lines.
Each instruction appears in exactly one layer. Run `frw measure-context` to verify.

## Component Rationale

Component rationale is centralized in `.furrow/almanac/rationale.yaml` (not injected into context).

## Commit Conventions

Conventional commits: feat:, fix:, chore:, docs:, refactor:, test:, infra:

## Rules

See `.claude/rules/` for platform-managed rules that survive compaction.


<!-- furrow:start -->
## Furrow

Installed from: /home/jonco/src/furrow

| Command | Purpose |
|---------|---------|
| /furrow:work | Create or resume a row |
| /furrow:status | Show step, deliverable progress |
| /furrow:checkpoint | Save session progress |
| /furrow:review | Run structured review |
| /furrow:archive | Archive completed work |
| /furrow:reground | Recover context after break |
| /furrow:redirect | Record dead end and pivot |
| /work-todos | Extract or create TODOs in todos.yaml |
| /furrow:triage | Triage todos.yaml and generate ROADMAP.md |
| /furrow:next | Generate handoff prompt(s) for next roadmap work |
| /furrow:init | Initialize Furrow in a new project |
| /furrow:doctor | Check Furrow health |
| /furrow:update | Check configuration drift |
| /furrow:meta | Enter self-modification mode |

Run `/furrow:doctor` to check health. Run `install.sh --check` to verify installation.
<!-- furrow:end -->
