## V2 Work Harness

This project uses the V2 adaptive work harness. Task state lives in `.work/` directories.

## Active Task Detection

Check `.work/*/state.json` for tasks where `archived_at` is null. If found, recover
context before making changes. See `.claude/rules/workflow-detect.md` for details.

## File Conventions

- Work units: `.work/{kebab-case-name}/`
- Core files: `definition.yaml`, `state.json`, `summary.md`, `reviews/`
- All identifiers (names, deliverables, specialists): kebab-case
- Schema fields (JSON/YAML): snake_case
- Timestamps: ISO 8601 with timezone

## Step Sequence

All work units traverse: ideate -> research -> plan -> spec -> decompose -> implement -> review

## State Ownership

`state.json` is harness-exclusive write. Agents read it but never write it directly.

## Context Budget Enforcement

| Layer | Budget | Content |
|-------|--------|---------|
| Ambient | <=100 lines | This file + rules/ (always loaded) |
| Work | <=150 lines | `skills/work-context.md` (during active work) |
| Step | <=50 lines | `skills/{step}.md` (per step, replaced at boundaries) |
| Reference | ~600 lines | `references/` (on demand, NOT injected) |

Total injected (ambient + work + step) must not exceed 300 lines.
Each instruction appears in exactly one layer. Run `scripts/measure-context.sh` to verify.

## Component Rationale

Component rationale is centralized in `_rationale.yaml` (not injected into context).

## Commit Conventions

Conventional commits: feat:, fix:, chore:, docs:, refactor:, test:, infra:

## Rules

See `.claude/rules/` for platform-managed rules that survive compaction.


<!-- harness:start -->
## V2 Work Harness

Installed from: /home/jonco/src/furrow

| Command | Purpose |
|---------|---------|
| /harness:work | Create or resume a work unit |
| /harness:status | Show step, deliverable progress |
| /harness:checkpoint | Save session progress |
| /harness:review | Run structured review |
| /harness:archive | Archive completed work |
| /harness:reground | Recover context after break |
| /harness:redirect | Record dead end and pivot |
| /harness | Harness management (doctor, update, meta) |

Run `/harness:doctor` to check health. Run `install.sh --check` to verify installation.
<!-- harness:end -->
