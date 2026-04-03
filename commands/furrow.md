# /furrow <subcommand>

Harness-level management operations: health check, updates, self-modification.

## Subcommands

### doctor

Run health check on Furrow installation.

1. Check `.furrow/almanac/rationale.yaml` for missing entries (every Furrow file must have one).
2. Check for stale `delete_when` conditions that may now be satisfied.
3. Verify skill instruction counts (step skills must be <=50 lines).
4. Verify total injected context (ambient + work + step) <=300 lines.
5. Run `scripts/furrow-doctor.sh` for structural validation.
6. Report findings with severity (error, warning, info).

### update

Compare project configuration against installed Furrow version.

1. Read `.claude/furrow.yaml` from the project.
2. Compare against the installed Furrow version's expected configuration.
3. Report drift: missing fields, deprecated fields, version mismatches.
4. Suggest updates if the project config is behind.

### meta

Enter Furrow self-modification mode.

1. Load Furrow component inventory from `.furrow/almanac/rationale.yaml`.
2. Display Furrow structure: layers, files, hooks, commands.
3. Present modification guidelines:
   - Sync contract: command table in `workflow.md` must match `commands/`.
   - Context budget: changes must not exceed layer budgets.
   - Rationale: every new file needs a `.furrow/almanac/rationale.yaml` entry.
4. Agent is ready to accept Furrow modification instructions.

## Usage

```
/furrow doctor    — Check Furrow health
/furrow update    — Check for configuration drift
/furrow meta      — Enter self-modification mode
```
