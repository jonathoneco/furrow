## Active Task Detection

Furrow task state lives in `.furrow/rows/`. Check for rows where
`archived_at` is null; recover context before changing files.

## File Conventions

- Rows: `.furrow/rows/{kebab-case-name}/`
- Core files: `definition.yaml`, `state.json`, `summary.md`, `reviews/`
- Identifiers: kebab-case. Schema fields: snake_case. Timestamps: ISO 8601.
- `state.json` is Furrow-exclusive write — never edit directly.
- Step sequence: see `.claude/rules/step-sequence.md`

## Context Budget

| Layer | Budget | Content |
|-------|--------|---------|
| Ambient | <=150 lines | This file + rules/ (always loaded) |
| Work | <=150 lines | `skills/work-context.md` (during active work) |
| Step | <=50 lines | `skills/{step}.md` (per step, replaced at boundaries) |
| Reference | ~600 lines | `references/` (on demand, NOT injected) |

Total injected context must stay small. Verify with the temporary compatibility
holdout `frw measure-context`; enforcement is not Go-backed yet.

## Component Rationale

Component rationale is centralized in `.furrow/almanac/rationale.yaml` (not injected into context).

## Commit Conventions

Conventional commits: feat:, fix:, chore:, docs:, refactor:, test:, infra:

## Topic Routing

| Topic | Reference |
|-------|-----------|
| Row structure & files | `references/row-layout.md` |
| Definition schema | `references/definition-shape.md` |
| Gate protocol | `references/gate-protocol.md` |
| Eval dimensions | `references/eval-dimensions.md`, `evals/` |
| Review process | `references/review-methodology.md` |
| Specialist templates | `references/specialist-template.md`, `specialists/` |
| CLI tools | `furrow` is canonical; `frw`, `rws`, `alm`, `sds` are compatibility-only unless named as temporary holdouts. |
| Architecture docs | `docs/architecture/` |
| Context loading | `docs/skill-injection-order.md` |
| Research guidance | `references/research-mode.md` |
| Knowledge base | `.furrow/almanac/` (rationale, roadmap, todos) |

<!-- furrow:start -->

## Furrow

Installed from: this repository (self-hosted)

Commands: see `references/furrow-commands.md`

Run `/furrow:doctor` for health; `install.sh --check` verifies installation.

<!-- furrow:end -->
