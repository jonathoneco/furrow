# Spec: transition-simplification

## Interface Contract

File: `bin/rws` — `rws_transition()` function (lines 1361-1560)
New usage: `rws transition <name> <outcome> <decided_by> <evidence> [conditions_json]`
Old usage (removed): `rws transition --request/--confirm <name> ...`

Exit codes: same as current (EXIT_SUCCESS, EXIT_USAGE, EXIT_VALIDATION,
EXIT_POLICY, EXIT_SUB_FAILED, EXIT_WRONG_STATUS)

Behavior (single atomic command):
1. Record gate in state.json.gates[]
2. Validate step artifacts (on pass/conditional)
3. Validate decided_by against gate_policy
4. Validate verdict nonce (if decided_by=evaluated)
5. Handle fail outcome (no advance, increment corrections)
6. Wave conflict check at implement->review
7. Regenerate summary
8. Advance step
9. Sync seed status

Files also changed: all 7 step skills (transition protocol sections)

## Acceptance Criteria (Refined)

1. `rws transition <name> <outcome> <decided_by> <evidence>` performs all
   validation and advancement atomically — no intermediate `pending_approval` state
2. `--request` and `--confirm` flags are removed from argument parsing
3. `pending_approval` is no longer a valid `step_status` value — remove all
   references from rws
4. Gate policy enforcement preserved: supervised requires decided_by=manual,
   delegated requires manual or evaluated
5. Verdict nonce validation preserved for decided_by=evaluated transitions
6. Artifact validation preserved for pass/conditional outcomes
7. All 7 step skills (`skills/ideate.md`, `skills/research.md`, `skills/plan.md`,
   `skills/spec.md`, `skills/decompose.md`, `skills/implement.md`, `skills/review.md`)
   updated: "Supervised Transition Protocol" sections use new single-command syntax
8. Gate-check hook (`bin/frw.d/hooks/gate-check.sh`) updated to match new
   command format — no `--request`/`--confirm` branching needed

## Implementation Notes

- Merge --request logic (record gate, validate artifacts, set step_status)
  and --confirm logic (validate policy, validate nonce, advance, sync seed)
  into a single sequential flow
- Remove the `pending_approval` -> `completed` step_status transition;
  go directly from `in_progress` to `completed` on success
- The `case "${1:-}" in --request|--confirm)` dispatch becomes simple
  positional arg parsing: `$1=name, $2=outcome, $3=decided_by, $4=evidence`
- Step skill updates are mechanical: replace the 2-line transition protocol
  with a single `rws transition` call
- Gate-check hook simplification: no need to distinguish --request/--confirm;
  check `has_passing_gate()` before any `rws transition` command
- Copy changes to installed Furrow at `/home/jonco/src/furrow/`

## Dependencies

- gate-check-hook-fix (wave 1) — hook must be working correctly first
- enforcement-wiring (wave 3) — step skill modifiers must be in place;
  transition-simplification edits the same files but different sections
