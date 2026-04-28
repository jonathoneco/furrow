## Active Task Detection

This project uses Furrow (V2 adaptive work harness). Task state lives in `.furrow/rows/`.
Check `.furrow/rows/*/state.json` for tasks where `archived_at` is null. If found, recover
context before making changes. See `.claude/rules/` for enforcement details.

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

Total injected (ambient + work + step) must not exceed 350 lines.
Each instruction appears in exactly one layer. Run `frw measure-context` to verify.

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
| CLI tools | `furrow` / `frw`; legacy `bin/rws`, `bin/alm`, and `bin/sds` are compatibility wrappers only |
| Architecture docs | `docs/architecture/` |
| Context loading | `docs/skill-injection-order.md` |
| Research guidance | `references/research-mode.md` |
| Knowledge base | `.furrow/almanac/` (rationale, roadmap, todos) |

<!-- furrow:start -->

## Furrow

Installed from: this repository (self-hosted)

Commands: see `references/furrow-commands.md`

Run `/furrow:doctor` to check health. Run `install.sh --check` to verify installation.

<!-- furrow:end -->
