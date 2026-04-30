# CLI-Mediated Harness Interaction

All harness state mutations go through CLI commands, never direct file edits.

| Operation | Command |
|-----------|---------|
| Read task state | `furrow row status [name]` |
| Advance steps | `furrow row transition <name> --step <next-step>` |
| Mark current step complete | `furrow row complete <name>` |
| Update summary sections | Edit `summary.md` deliberately; it is context, not backend-owned truth |
| Complete deliverables | Temporary compatibility holdout: `rws complete-deliverable [name] <deliverable>`; no generic Go deliverable mutation command exists |
| Regenerate summary | Not required for checkpoint or archive; legacy `rws regenerate-summary [name]` remains manual-only |
| Validate summary | Stop/work-check validation is Go-backed through `furrow_guard`; legacy `rws validate-summary [name]` remains manual-only |

## Forbidden

- Direct Edit/Write of `state.json` (enforced by state-guard hook)
- Using `jq`/`sed`/`awk` to mutate state files via Bash

Direct state.json edits are blocked by the state-guard hook (exit 2).
`summary.md` edits are allowed for context notes, but they are not archive or
checkpoint truth. Keep the standard section headings intact so Go validation and
context readers can still parse the file.
Exceeding the correction limit blocks further writes until human escalation.

State mutations must be atomic and schema-validated. Direct edits bypass
validation, risk corruption, and break the harness audit trail.

## Correction Limit

During the implement step, each deliverable has a correction limit (default: 3).
Writes to files owned by a deliverable that reached its limit are blocked by the
`correction-limit` hook. Escalate to human for guidance — no CLI override exists.

## If No CLI Exists

If you need an operation that has no CLI command, flag it as a gap rather
than doing file surgery. Add a TODO or tell the user.
