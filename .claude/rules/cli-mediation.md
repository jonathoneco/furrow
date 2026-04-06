# CLI-Mediated Harness Interaction

All harness state mutations go through CLI commands, never direct file edits.

## Required CLI Usage

| Operation | Command |
|-----------|---------|
| Update summary sections | `rws update-summary [name] <section> [--replace]` (stdin) |
| Read task state | `rws status [name]` |
| Advance steps | `rws transition --request ...` |
| Complete deliverables | `rws complete-deliverable [name] <deliverable>` |
| Regenerate summary | `rws regenerate-summary [name]` |
| Validate summary | `rws validate-summary [name]` |

## Forbidden

- Direct Edit/Write of `state.json` (enforced by state-guard hook)
- Direct Edit/Write of `summary.md` agent sections — use `rws update-summary`
- Using `jq`/`sed`/`awk` to mutate state files via Bash
- Using `echo >>` or `cat >` to append to summary.md

## Consequence

Direct state.json edits are blocked by the state-guard hook (exit 2).
Direct summary.md edits bypass validation and risk section corruption.
Exceeding the correction limit blocks further writes until human escalation.

## Why

State mutations must be atomic and schema-validated. Direct edits bypass
validation, risk corruption, and break the harness audit trail.

## Correction Limit

During the implement step, each deliverable has a correction limit (default: 3).
Writes to files owned by a deliverable that reached its limit are blocked by the
`correction-limit` hook. Escalate to human for guidance — no CLI override exists.

## If No CLI Exists

If you need an operation that has no CLI command, flag it as a gap rather
than doing file surgery. Add a TODO or tell the user.
