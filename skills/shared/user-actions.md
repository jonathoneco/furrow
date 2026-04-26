---
layer: shared
---
# User Actions

When a workflow step requires the user to act outside Claude Code (interactive
logins, PR reviews, deploy approvals, manual verifications), declare the action:

1. `rws add-user-action <name> <id> <instructions>` — declares what the user must do
2. Tell the user what action is needed and why
3. `rws list-user-actions <name>` — check action status
4. User runs `rws complete-user-action <name> <id>` when done
5. Step transitions are blocked until all pending actions are completed

The agent does NOT complete actions — only the user does.
