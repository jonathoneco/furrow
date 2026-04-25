# Cross-adapter parity verification — pre-write-validation-go-first

This document records paired Pi-side and Claude-side observations for the same Go-validator outputs. It proves the cross-adapter parity invariant from `definition.yaml` constraints holds: identical step-agnostic non-blocking awareness on both runtimes, with intrinsic UX divergence (Pi: interactive `ctx.ui.confirm`; Claude: shell `log_warning` because Claude hooks are non-interactive at write time).

## Paired scenarios

| # | Scenario | Input path | Input row | D2 verdict | Pi handler outcome (D5) | Claude hook outcome (D6) | Parity OK? | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | in_scope match | `internal/cli/validate_ownership.go` | `pre-write-validation-go-first` | `in_scope`, matched_deliverable=`validate-ownership-go`, matched_glob=`internal/cli/validate_ownership.go` | silent allow (no notify, no confirm) | (filled by D6) | (filled by D6) |  |
| 2 | out_of_scope | `tests/adversarial/outside.go` | `pre-write-validation-go-first` | `out_of_scope`, envelope.code=`ownership_outside_scope`, severity=`warn`, confirmation_path=`warn-with-confirm` | `ctx.ui.confirm("Furrow ownership check", "...outside file_ownership... Proceed anyway?")` fires | (filled by D6) | (filled by D6) | Pi UX is interactive; Claude is non-interactive. Both fire on the same trigger. |
| 3 | not_applicable (no row) | `random/path.txt` | (none — no `--row`, no focused row) | `not_applicable`, reason=`no_active_row` | silent allow | (filled by D6) | (filled by D6) | Hook resolves as no-op when no row context exists |

## Methodology

### Pi-side (D5) — bun test, contract assertions

The Pi handler reads `runFurrowJson<ValidateOwnershipData>` envelope output. The contract tests at `adapters/pi/furrow.test.ts` exercise:

- `bun test furrow.test.ts -t "in_scope"` → asserts `verdict === "in_scope"` + `matched_deliverable` + `matched_glob`
- `bun test furrow.test.ts -t "out_of_scope"` → asserts `verdict === "out_of_scope"` + `envelope.code === "ownership_outside_scope"` + `confirmation_path === "warn-with-confirm"`
- `bun test furrow.test.ts -t "not_applicable"` → asserts `verdict === "not_applicable"` + `reason` non-empty
- `bun test furrow.test.ts -t "step-agnostic"` → asserts verdict identical across `state.step ∈ {ideate, plan, implement}` for the same path/row

All four pass with the D2 Go validator (`furrow validate ownership`) as the upstream source of truth.

The handler at `adapters/pi/furrow.ts` (D5 block) reads `data.verdict` from the envelope and:
- `in_scope` / `not_applicable` → return undefined (silent allow)
- `out_of_scope` with UI → `ctx.ui.confirm` prompt; user "yes" → undefined; user "no" → `{block: true, reason}`
- `out_of_scope` without UI → return undefined (degraded silent allow; the Claude shell hook is the non-interactive equivalent)

### Claude-side (D6) — manual verification

(Filled by D6 when wave 6 implements the shell hook update.)

## Shared invariants

Both runtimes:
- Fire on the same Go validator verdict (`out_of_scope`).
- Are step-agnostic — never read `state.json.step`.
- Are non-blocking by default (Pi: user can confirm to proceed; Claude: warn-only via log_warning).
- Surface the same envelope message (Pi: in confirm prompt; Claude: in log_warning text).

## UX divergence (intrinsic, accepted)

- **Pi**: interactive `ctx.ui.confirm` with proceed/cancel.
- **Claude**: non-interactive log_warning (Claude shell hooks have no interactive primitive at write time).

This divergence is host-capability-driven. The cross-adapter parity invariant in `definition.yaml` constraints names this explicitly: "step-agnostic non-blocking awareness with identical Go-validator-driven trigger conditions; the divergence is purely host-capability UX."
