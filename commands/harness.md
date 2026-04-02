# /harness <subcommand>

Harness-level management operations: health check, updates, self-modification.

## Subcommands

### doctor

Run health check on harness installation.

1. Check `_rationale.yaml` for missing entries (every harness file must have one).
2. Check for stale `delete_when` conditions that may now be satisfied.
3. Verify skill instruction counts (step skills must be <=50 lines).
4. Verify total injected context (ambient + work + step) <=300 lines.
5. Run `scripts/harness-doctor.sh` for structural validation.
6. Report findings with severity (error, warning, info).

### update

Compare project configuration against installed harness version.

1. Read `.claude/harness.yaml` from the project.
2. Compare against the installed harness version's expected configuration.
3. Report drift: missing fields, deprecated fields, version mismatches.
4. Suggest updates if the project config is behind.

### meta

Enter harness self-modification mode.

1. Load harness component inventory from `_rationale.yaml`.
2. Display harness structure: layers, files, hooks, commands.
3. Present modification guidelines:
   - Sync contract: command table in `workflow.md` must match `commands/`.
   - Context budget: changes must not exceed layer budgets.
   - Rationale: every new file needs a `_rationale.yaml` entry.
4. Agent is ready to accept harness modification instructions.

## Usage

```
/harness doctor    — Check harness health
/harness update    — Check for configuration drift
/harness meta      — Enter self-modification mode
```
