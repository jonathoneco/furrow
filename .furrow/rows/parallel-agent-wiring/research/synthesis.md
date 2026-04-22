# Research Synthesis

## Cross-Deliverable Findings

All three deliverables share a common implementation surface: **bin/rws** is the CLI entry
point for all state mutations, and all follow the same pattern (jq mutation, atomic write,
schema validation, timestamp update).

### orchestration-instructions
The infrastructure is complete — waves, specialists, context isolation, validation. The gap
is entirely in the implement.md skill text: no decision tree, no concrete example, no
wave inspection protocol. This is a **documentation/instruction** problem, not a code problem.
Implementation touches skills/ files only, no CLI changes needed.

### worktree-summary
Clean replication of update-summary pattern. The awk section-replacement is well-understood
(~30 lines). New command in bin/rws, new file in row directory. Modest scope.

### user-action-lifecycle
Extends state.json schema (new array field), adds 2-3 CLI commands to bin/rws, adds
notify-send call, and extends transition logic to check for pending actions. Gate
enforcement fits inside rws_transition() rather than the gate-check hook (keeps the
atomic operation pattern). Schema change requires updating schemas/state.schema.json.

## Ordering Confirmation

Research confirms the reviewer's sequential ordering recommendation:
1. **orchestration-instructions first** — pure skill text, no CLI changes, unblocks dispatch
2. **worktree-summary second** — only useful when dispatch is happening
3. **user-action-lifecycle third** — independent but logically last (adds state complexity)

## Open Questions Resolved

| Question | Resolution |
|----------|-----------|
| Where does gate enforcement for user actions go? | Inside rws_transition(), not gate-check hook |
| Does the awk pattern need extraction to common.sh? | Worth checking if update-summary and update-worktree-summary can share it |
| What sections does worktree-summary need? | files-changed, decisions, open-items, test-results |

## Risks

1. **Context budget for implement.md** — the rewrite must fit within 50 lines injected.
   Current orchestration section is dense; the decision tree + example may exceed budget.
   Mitigation: move the example to a reference file, keep implement.md to the decision tree only.
2. **notify-send availability** — assumes swaync is running. Should gracefully degrade
   (check command exists before calling).
