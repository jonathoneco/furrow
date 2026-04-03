# Spec: frw-dispatcher-and-modules

## Interface Contract

### `bin/frw`

```
frw <command> [args...]
```

**Path resolution** (first 5 lines of executable logic):
```sh
SCRIPT_PATH="$(readlink -f "$0")"
FURROW_ROOT="$(cd "$(dirname "$SCRIPT_PATH")" && cd .. && pwd)"
export FURROW_ROOT
```

**Dispatch table** (case statement):

| Command | Sources | Calls |
|---------|---------|-------|
| `hook <name> [args]` | `frw.d/lib/common.sh` + `frw.d/hooks/<name>.sh` | `hook_<name> "$@"` |
| `init [args]` | `frw.d/init.sh` | `frw_init "$@"` |
| `install [args]` | `frw.d/install.sh` | `frw_install "$@"` |
| `doctor [args]` | `frw.d/scripts/doctor.sh` | `frw_doctor "$@"` |
| `update-state <name> <jq>` | `frw.d/scripts/update-state.sh` | `frw_update_state "$@"` |
| `update-deliverable <name> <del> [opts]` | `frw.d/scripts/update-deliverable.sh` | `frw_update_deliverable "$@"` |
| `check-artifacts <name> <del>` | `frw.d/scripts/check-artifacts.sh` | `frw_check_artifacts "$@"` |
| `run-gate <name> <type>` | `frw.d/scripts/run-gate.sh` | `frw_run_gate "$@"` |
| `evaluate-gate <name> <boundary> <verdict>` | `frw.d/scripts/evaluate-gate.sh` | `frw_evaluate_gate "$@"` |
| `select-gate <name>` | `frw.d/scripts/select-gate.sh` | `frw_select_gate "$@"` |
| `select-dimensions <name>` | `frw.d/scripts/select-dimensions.sh` | `frw_select_dimensions "$@"` |
| `generate-plan <name>` | `frw.d/scripts/generate-plan.sh` | `frw_generate_plan "$@"` |
| `validate-definition <path>` | `frw.d/scripts/validate-definition.sh` | `frw_validate_definition "$@"` |
| `validate-naming <type> <name>` | `frw.d/scripts/validate-naming.sh` | `frw_validate_naming "$@"` |
| `measure-context [root]` | `frw.d/scripts/measure-context.sh` | `frw_measure_context "$@"` |
| `run-ci-checks <name>` | `frw.d/scripts/run-ci-checks.sh` | `frw_run_ci_checks "$@"` |
| `cross-model-review <name> <del>` | `frw.d/scripts/cross-model-review.sh` | `frw_cross_model_review "$@"` |
| `merge-to-main <name>` | `frw.d/scripts/merge-to-main.sh` | `frw_merge_to_main "$@"` |
| `migrate-to-furrow [opts]` | `frw.d/scripts/migrate-to-furrow.sh` | `frw_migrate_to_furrow "$@"` |
| `run-integration-tests [pat]` | `frw.d/scripts/run-integration-tests.sh` | `frw_run_integration_tests "$@"` |
| `root` | nothing | `printf '%s\n' "$FURROW_ROOT"` |
| `help` | nothing | print usage |

**Exit codes**: pass through from sourced module.
**Stdin**: pass through (not consumed by dispatcher).

### `bin/frw.d/lib/common.sh`

Migrated verbatim from `hooks/lib/common.sh`. Exports: `find_active_row()`, `find_focused_row()`, `read_state_field()`, `read_definition_field()`, `current_step()`, `step_status()`, `has_passing_gate()`, `row_name()`, `is_row_file()`, `extract_row_from_path()`, `set_focus()`, `clear_focus()`, `log_warning()`, `log_error()`.

### `bin/frw.d/lib/validate.sh`

Migrated verbatim from `hooks/lib/validate.sh`. Exports: `validate_definition_yaml()`, `validate_state_json()`, `validate_plan_json()`, `validate_step_boundary()`.

## Acceptance Criteria (Refined)

1. `bin/frw` exists, is executable (`chmod +x`), starts with `#!/bin/sh`
2. `frw root` prints the absolute path to the furrow repo (resolved through symlinks)
3. `frw help` prints usage listing all subcommands, exits 0
4. `frw hook state-guard` with stdin JSON correctly sources common.sh + hook module (verified by exit code)
5. `frw unknown-cmd` prints error and exits 1
6. `bin/frw.d/lib/common.sh` exists and contains all functions from `hooks/lib/common.sh`
7. `bin/frw.d/lib/validate.sh` exists and contains all functions from `hooks/lib/validate.sh`
8. `FURROW_ROOT` is exported so sourced modules can use it without re-resolving

## Implementation Notes

- Follow `readlink -f` pattern from `bin/rws` line 9
- `die()` helper for error messages (same pattern as sds/rws/alm)
- Source modules with `. "$FURROW_ROOT/bin/frw.d/..."` — never exec
- The `hook` subcommand must NOT consume stdin before sourcing the hook module

## Dependencies

- None (this is the foundation deliverable)
