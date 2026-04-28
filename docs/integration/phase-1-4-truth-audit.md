# Phase 1-4 Truth Audit

Date: 2026-04-28

This audit applies the Session 1 truth-gate rubric to completed Phases 1-4.
Verdicts distinguish mechanically landed work from claims that are true through
the runtime paths they advertise.

## Summary Verdict

Phases 1-4 are kept as completed historical work, but two claims were corrected:

- Phase 3 no longer claims full Pi enforcement parity. It claims loaded-path
  main-thread Pi layer enforcement only.
- Phase 4 blocker parity no longer counts absent Pi handlers as parity passes.
  Absent handlers are fixture inventory until a live adapter handler exists.

## Phase 1: Post-install Hygiene

Verdict: true for the completed claim surface.

Evidence:

- Install, upgrade, XDG, review scoping, and reintegration checks are covered by
  existing integration tests.
- Session 1 added completion-evidence gates so future rows cannot archive with
  required-for-truth follow-ups hidden as ordinary TODOs.

Residual risk:

- Historical rows remain grandfathered unless they opt into truth gates.

## Phase 2: Backend Contract Foundations

Verdict: corrected.

Problem found:

- Backend hook inputs included Claude-shaped payload parsing in semantic paths.

Correction:

- Added normalized `layer.ToolEvent`.
- Added `furrow layer decide` as the adapter-neutral decision path.
- Kept `furrow hook layer-guard` as the Claude PreToolUse compatibility shim.

Residual risk:

- Additional hooks outside layer/presentation may still need normalized event
  equivalents before future parity rows can make broad backend-neutral claims.

## Phase 3: Pi Enforcement Parity

Verdict: downgraded and partially fixed.

Problem found:

- `.pi/extensions/furrow.ts` loaded `adapters/pi/furrow.ts`, while stronger
  layer-guard code lived in `adapters/pi/extension/index.ts`.
- The old parity test invoked the same Go hook twice instead of exercising the
  loaded Pi adapter path.

Correction:

- The loaded Pi adapter now normalizes Pi `tool_call` events into `ToolEvent`
  and calls `furrow layer decide`.
- Added a loaded-entrypoint test through `.pi/extensions/furrow.ts`.
- `tests/integration/test-layer-policy-parity.sh` now checks Claude hook
  behavior and the loaded Pi entrypoint path.

Downgrade:

- Pi enforcement parity is limited to tool calls visible to the loaded Pi
  extension. The known subprocess subagent hook-bus blind spot remains outside
  the completed claim.

## Phase 4: Blocker Taxonomy + Delegation Contract

Verdict: corrected with explicit limitations.

Problems found:

- Blocker parity tests passed by skipping Pi handlers that did not exist.
- Presentation protocol references pointed to a missing file.
- Backend presentation scanning parsed Claude transcript paths directly.

Correction:

- `tests/integration/test-blocker-parity.sh` now treats absent Pi handlers as
  inventory-only, not parity passes.
- Added `skills/shared/presentation-protocol.md`.
- Added normalized `PresentationEvent` and `furrow presentation scan`.
- Kept `furrow hook presentation-check` as the Claude Stop-hook transcript
  extraction shim.

Downgrade:

- Pi presentation scanning is not claimed until the Pi adapter has a comparable
  lifecycle event wired to `furrow presentation scan`.

## Boundary Findings

- Backend now owns normalized decisions: `ToolEvent` and `PresentationEvent`.
- Claude owns PreToolUse and Stop transcript extraction.
- Pi owns `tool_call` translation and UI/runtime behavior.
- Future rows must not put `.claude`, `.pi`, Claude transcript paths, or Pi
  runtime event names in backend-owned schemas except as adapter fixtures.

## Verification Targets

Required before closing this correction row:

- `go test ./...`
- `bun test` in `adapters/pi`
- `bun run typecheck` in `adapters/pi`
- `tests/integration/test-layer-policy-parity.sh`
- `tests/integration/test-presentation-protocol.sh`
- `furrow almanac validate`
