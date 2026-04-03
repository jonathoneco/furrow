# Research: rws CLI Architecture (D3)

## Call Graph

```
step-transition.sh (orchestrator)
├── record-gate.sh
├── validate-step-artifacts.sh
├── validate-summary.sh (hook)
├── regenerate-summary.sh
└── advance-step.sh
    └── create-work-branch.sh (at decompose→implement)

init-work-unit.sh (standalone)
detect-context.sh (standalone scanner)
load-step.sh (standalone reader)
gate-precheck.sh (standalone validator)
rewind.sh → record-gate.sh
archive-work.sh → update-state.sh, regenerate-summary.sh
work-unit-diff.sh (standalone, git-based)
```

All state mutations go through `update-state.sh` (atomic jq + temp file + mv).

## Subcommand Mapping

| Subcommand | Absorbs | Args |
|---|---|---|
| `rws init <name>` | init-work-unit.sh (both copies) | `--title, --mode, --gate-policy, --source-todo, --seed-id` |
| `rws transition --request` | step-transition.sh request phase | `<name> <outcome> <decided_by> <evidence> [conditions]` |
| `rws transition --confirm` | step-transition.sh confirm phase | `<name>` |
| `rws status [name]` | detect-context.sh (single row) | optional name |
| `rws list [--active\|--archived]` | detect-context.sh (all rows) | filter flags |
| `rws archive <name>` | archive-work.sh | name required |
| `rws gate-check` | gate-precheck.sh | `<step> <def_path> <state_path>` |
| `rws load-step [name]` | load-step.sh | optional name |
| `rws rewind <name> <step>` | rewind.sh | both required |
| `rws diff [name]` | work-unit-diff.sh | optional name |
| `rws focus [name\|--clear]` | from common.sh | manage .focused |

## Architecture Decision: Monolithic vs. Dispatch

**Decision: Single `bin/rws` script with embedded subcommands.**

Rationale: `bn` is ~450 lines as a monolithic script and works well. The absorbed scripts total ~800 lines of logic. A single `rws` at ~1000-1200 lines is manageable for POSIX shell. Avoids the complexity of a lib/ directory with sourced files.

Internal helpers (record-gate, advance-step, validate-step-artifacts, regenerate-summary) become shell functions within `rws`, not exposed subcommands. They're implementation details of `rws transition`.

## Shared Code

- `update-state.sh` remains separate (called by `rws` internally) — it's the mutation hub
- `hooks/lib/common.sh` functions (find_focused_work_unit, etc.) get duplicated into `rws` as internal functions
- `hooks/lib/validate.sh` functions called by validate-step-artifacts stay in hooks/ (rws sources them)

## Exit Codes (preserved)

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Usage/argument error |
| 2 | state.json not found |
| 3 | Validation/precondition failed |
| 4 | Sub-operation failed |
| 5 | Wrong state (e.g., pending_approval mismatch) |
| 6 | Policy violation |
| 7 | Seed mismatch (NEW — hard block) |

## Path Updates

Every `.work/` reference becomes `.furrow/rows/`. The `.focused` file moves from `.work/.focused` to `.furrow/.focused`.
