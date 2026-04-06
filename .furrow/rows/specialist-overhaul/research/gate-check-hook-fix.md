# Research: gate-check-hook-fix

## Problem

`bin/frw.d/hooks/gate-check.sh` has two bugs that interact:

1. **Regex bug**: The sed regex `'s/.*rws +transition +([^ ]*).*/\1/p'`
   captures the first word after `rws transition`, which is `--request` or
   `--confirm` — not the row name. For the correct syntax
   `rws transition --request <name>`, the hook looks for
   `.furrow/rows/--request/state.json`, doesn't find it, and returns 0.
   The hook has **never actually enforced anything** for correctly formatted
   transition commands.

2. **Wrong check**: The hook calls `rws gate-check` (an auto-advance
   heuristic that asks "can this step be skipped?") instead of
   `has_passing_gate()` from `common.sh` (which checks state.json for a
   gate record with outcome pass/conditional). The auto-advance check
   always returns 1 for ideate, implement, and review.

## Why Other Branches Worked

The `ideation-and-review-ux` row on `work/ideation-and-review-ux` successfully
transitioned through all 6 boundaries (including ideate->research and
implement->review) because the correct command syntax
`rws transition --request <name> ...` put `--request` as the first captured
group, bypassing the hook via the regex bug.

## Why This Branch Failed

The agent used the wrong argument order:
`rws transition specialist-overhaul --request ...` (name before --request).
The regex accidentally captured the real row name, found the state file,
ran gate-check, and correctly blocked (ideate always fails gate-check).

## Intended Design

The hook header says "Verify gate record before step advance" and
`common.sh:87` has a `has_passing_gate()` function that does exactly this.
The hook was supposed to use this function but was wired to gate-check instead.

## Fix

1. Fix regex: `'s/.*rws +transition +--(request|confirm) +([^ ]*).*/\2/p'`
2. Replace `rws gate-check` with `has_passing_gate()` from common.sh
3. Only check on --request (--confirm relies on --request having recorded gate)
4. This gives real enforcement: can't transition without a recorded passing gate

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `bin/frw.d/hooks/gate-check.sh` (source code) | Primary | Hook regex and delegation logic |
| `bin/frw.d/lib/common.sh:87` (source code) | Primary | `has_passing_gate()` — the correct check |
| `bin/rws` lines 1363-1367 (source code) | Primary | Transition arg format: --request/--confirm before name |
| `work/ideation-and-review-ux` state.json (git) | Primary | Proof that all 6 transitions succeeded with same hook |
| Shell testing of regex (live) | Primary | Confirmed --request captured instead of row name |
