# Spec: script-migration

## Interface Contract

Each script becomes a file `bin/frw.d/scripts/<name>.sh` containing a main function (e.g., `frw_update_state()`).

The dispatcher sources the module and calls the function. Scripts that call other scripts should call `frw <subcommand>` (CLI interface) not source sibling modules directly.

### Scripts to Migrate (17 total)

| Script | frw Subcommand | Args | Current LOC | Calls Other Scripts |
|--------|---------------|------|-------------|---------------------|
| update-state.sh | `frw update-state` | `<name> <jq-expr>` | 164 | None |
| update-deliverable.sh | `frw update-deliverable` | `<name> <del> <status> [opts]` | 168 | update-state.sh |
| check-artifacts.sh | `frw check-artifacts` | `<name> <del>` | 234 | validate.sh (lib) |
| run-gate.sh | `frw run-gate` | `<name> <type>` | 183 | check-artifacts.sh, select-gate.sh |
| evaluate-gate.sh | `frw evaluate-gate` | `<name> <boundary> <verdict>` | 71 | None |
| select-gate.sh | `frw select-gate` | `<name>` | 46 | None |
| select-dimensions.sh | `frw select-dimensions` | `<name>` | 61 | None |
| cross-model-review.sh | `frw cross-model-review` | `<name> <del>` | 194 | select-dimensions.sh |
| run-ci-checks.sh | `frw run-ci-checks` | `<name>` | 141 | None |
| generate-plan.sh | `frw generate-plan` | `<name>` | 217 | validate.sh (lib) |
| validate-definition.sh | `frw validate-definition` | `<path>` | 145 | None |
| validate-naming.sh | `frw validate-naming` | `<type> <name>` | 95 | None |
| measure-context.sh | `frw measure-context` | `[root]` | 152 | None |
| furrow-doctor.sh | `frw doctor` | `[--research] [root]` | 406 | measure-context.sh |
| merge-to-main.sh | `frw merge-to-main` | `<name>` | 65 | None |
| migrate-to-furrow.sh | `frw migrate-to-furrow` | `[--dry-run]` | 121 | None |
| run-integration-tests.sh | `frw run-integration-tests` | `[pattern]` | 96 | None |

### Script cross-call migration

| Caller | Currently Calls | Migrated To |
|--------|----------------|-------------|
| update-deliverable | `$FURROW_ROOT/scripts/update-state.sh` | `frw update-state` |
| run-gate | `$FURROW_ROOT/scripts/check-artifacts.sh` | `frw check-artifacts` |
| run-gate | `$FURROW_ROOT/scripts/select-gate.sh` | `frw select-gate` |
| cross-model-review | `$FURROW_ROOT/scripts/select-dimensions.sh` | `frw select-dimensions` |
| doctor | `$FURROW_ROOT/scripts/measure-context.sh` | `frw measure-context` |
| bin/rws (line 456) | `$FURROW_ROOT/scripts/validate-definition.sh` | `frw validate-definition` |
| bin/rws (line 903) | `$FURROW_ROOT/scripts/measure-context.sh` | `frw measure-context` |

## Acceptance Criteria (Refined)

1. Each of the 17 scripts exists as `bin/frw.d/scripts/<name>.sh` with a main function
2. `frw update-state <name> '<jq>'` performs atomic state mutation with schema validation (same as current script)
3. `frw doctor` produces the same health check output as current `scripts/furrow-doctor.sh`
4. `frw validate-definition <path>` returns exit 0 for valid, non-zero for invalid
5. All inter-script calls use `frw <subcommand>` not direct module sourcing
6. `bin/rws` lines 456 and 903 updated to call `frw validate-definition` and `frw measure-context`
7. Scripts that use `$FURROW_ROOT/schemas/` still resolve schema paths correctly
8. Scripts that use python3 (generate-plan, validate-definition) still work (python invocations unchanged)

## Implementation Notes

- Each script has its own FURROW_ROOT resolution preamble — strip it, use the exported `$FURROW_ROOT` from dispatcher
- Scripts that source validate.sh need the dispatcher to source it (or source it themselves from `$FURROW_ROOT/bin/frw.d/lib/validate.sh`)
- `update-state.sh` references `$FURROW_ROOT/schemas/state.schema.json` — this path still works since FURROW_ROOT is the repo root
- `doctor.sh` has 14+ path references to `hooks/` for registration checks — these must update to check `bin/frw.d/hooks/` AND check settings.json for `frw hook <name>` pattern
- `run-integration-tests.sh` uses bash (not sh) — preserve that requirement

## Dependencies

- D1: frw-dispatcher-and-modules (dispatcher + shared libs)
