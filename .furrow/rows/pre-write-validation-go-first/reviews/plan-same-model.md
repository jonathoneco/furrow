# Same-model plan review (sonnet, fresh context subagent)

Verdict: APPROVE-WITH-NOTES

## Findings

1. **Wave numbering mismatch**: definition.yaml constraint stated 2 waves; plan.json had 3 waves. Resolution: split wave 3 into wave 3 + wave 4 (D6 alone) and updated definition.yaml constraint to describe the 4-wave plan.json execution order verbatim.

2. **AD-7 stale framing**: team-plan.md AD-7 said "will update plan.json to add the file" but the file was already added. Resolution: rewrote AD-7 to reflect "decision applied; no follow-up."

3. **D5/D6 parity-verification.md cross-specialist write conflict**: real risk — typescript-specialist (D5) and shell-specialist (D6) cannot serialize via single-agent within the same wave. Resolution: D6 moved to its own wave 4; D5 authors the file in wave 3 (header + Pi rows); D6 appends Claude rows in wave 4 with no concurrent-write window.

4. **Missing: shim continuity test**: D1's existing acceptance covered shim rewrite but not behavioral continuity for existing callers. Resolution: added shim continuity test to D1 AC + new file `tests/integration/test-validate-definition-shim.sh` to D1's file_ownership in both definition.yaml and plan.json.

## Cross-model (codex) findings

`overall: fail` purely due to file_ownership overlap detection within waves. Two of the three flagged overlaps were intentional (AD-5 single-agent serialization for D1+D2 sharing app.go, and D4+D5 sharing furrow.ts). Codex's static analysis can't see specialist assignment so flagged them as failures. The third overlap (parity-verification.md across D5+D6) was the real issue — same as same-model finding 3, resolved via wave split.

## Resolution applied

All 4 findings addressed. Re-validation: definition.yaml passes; plan.json passes (4 waves); team-plan.md updated. No further changes pending.
