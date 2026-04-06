## Active Task Detection

This project uses Furrow (V2 adaptive work harness). Task state lives in `.furrow/rows/`.
Check `.furrow/rows/*/state.json` for tasks where `archived_at` is null. If found, recover
context before making changes. See `.claude/rules/` for enforcement details.

## File Conventions

- Rows: `.furrow/rows/{kebab-case-name}/`
- Core files: `definition.yaml`, `state.json`, `summary.md`, `reviews/`
- Identifiers: kebab-case. Schema fields: snake_case. Timestamps: ISO 8601.
- `state.json` is Furrow-exclusive write — never edit directly.
- Step sequence: ideate -> research -> plan -> spec -> decompose -> implement -> review

## Context Budget

Ambient (this file + rules/) <=100 lines. Work <=150. Step <=50. Total <=300.
Run `frw measure-context` to verify.

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
| CLI tools | `bin/frw` (harness), `bin/rws` (rows), `bin/alm` (almanac), `bin/sds` (seeds) |
| Architecture docs | `docs/architecture/` |
| Context loading | `docs/skill-injection-order.md` |
| Research guidance | `references/research-mode.md` |
| Knowledge base | `.furrow/almanac/` (rationale, roadmap, todos) |

<!-- furrow:start -->

## Furrow

Installed from: this repository (self-hosted)

| Command            | Purpose                                          |
| ------------------ | ------------------------------------------------ |
| /furrow:work       | Create or resume a row                           |
| /furrow:status     | Show step, deliverable progress                  |
| /furrow:checkpoint | Save session progress                            |
| /furrow:review     | Run structured review                            |
| /furrow:archive    | Archive completed work                           |
| /furrow:reground   | Recover context after break                      |
| /furrow:redirect   | Record dead end and pivot                        |
| /work-todos        | Extract or create TODOs in todos.yaml            |
| /furrow:triage     | Triage todos.yaml and generate ROADMAP.md        |
| /furrow:next       | Generate handoff prompt(s) for next roadmap work |
| /furrow:init       | Initialize Furrow in a new project               |
| /furrow:doctor     | Check Furrow health                              |
| /furrow:update     | Check configuration drift                        |
| /furrow:meta       | Enter self-modification mode                     |

Run `/furrow:doctor` to check health. Run `install.sh --check` to verify installation.

<!-- furrow:end -->
