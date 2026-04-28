# Codex Two-Session Truth Hardening Plan

Date: 2026-04-28
Mode: out-of-harness Codex work, deliberately not a Furrow row

## Purpose

Use two Codex sessions to correct the process gap that let Phases 1-4 drift from
their spirit-of-the-law claims.

The work is split because the two jobs have different success criteria:

1. Session 1 hardens row functionality so future work cannot archive by
   deferring truth-critical work.
2. Session 2 uses that hardened lens to audit and correct Phases 1-4, then
   hardens the remaining roadmap so future phases converge on the same clean
   end state.

Do not start a Furrow row for either session. Exploration and planning may occur
on `main`; implementation should happen in a git worktree.

## Operating Stance

- Clean end state over transitional compromise.
- A TODO is not neutral. If it is required for the current claim to be true,
  it is remaining work, not a follow-up.
- Pi parity means currently enforced through the actual loaded Pi adapter path.
- Backend owns Furrow business logic and adapter-neutral contracts.
- Adapters own runtime translation, runtime UI, runtime discovery, and runtime
  strengths.
- Testing is a primitive, not an afterthought.
- Reviews must evaluate spirit of the law, not only artifact existence.

## Session Split

### Session 1: Row Truth Gates and Process Hardening

Goal: add row-level primitives that force every row, including ad-hoc work, to
analyze the real ask, define tests up front, classify deferrals, and complete
against the spirit of the law.

Primary handoff:

- `docs/handoffs/codex-session-1-row-truth-gates.md`

### Session 2: Phase 1-4 Retrospective and Correction

Goal: apply the new truth criteria to completed Phases 1-4, fix or downgrade
claims, correct adapter-boundary violations, and repair the roadmap so the
remaining phases cannot preserve dual-source truth, transitional modes, or
compatibility shims without a removal trigger.

Primary handoff:

- `docs/handoffs/codex-session-2-phase-1-4-retrospective.md`
- `docs/handoffs/codex-roadmap-correction-hardening.md`

## Brain-Dump Integration

The notes below should be handled as follows.

### Integrate In Session 1

- TODO capture enables bad deferrals.
- TODO capture needs an "implications / real ask" step.
- Testing as a primitive.
- Spirit-of-the-law completion check.
- Bugs in ceremony and sequencing.
- Archive should include PR prep.
- Any amount of implementation work should happen in a worktree.
- Project vs global learnings reconciliation.
- Modularization / duplicate pass in review.
- Specialists are skills, not registered agents.
- Options should be meaningfully different, not slight variants.
- Scout / dive research pattern.

These are process primitives. If they are postponed, Session 2 will repeat the
same failure mode that caused the drift.

### Integrate In Session 2

- Adapter bleed into backend.
- Pi parity through the loaded adapter path.
- Core-adapter boundary correction.
- Presentation protocol missing file.
- Phase 1-4 truth audit.
- Roadmap claim downgrades or corrections.
- Roadmap hardening for Phases 5-15: every row must have a clean cutover,
  removal trigger, dependency rationale, collision check, and explicit end-state
  contribution.
- Surface spread / optionality pain audit, as applied to shipped schemas and
  row state.

These require using the truth-gate lens against the current codebase.

### Defer To Roadmap After Session 2

- DFD for the harness.
- Gardener metaphor replacing operator/driver/engine terminology.
- Ad-hoc teammate creation as a skill.
- Wide surface / optionality audit across the whole project, beyond issues
  found while correcting Phases 1-4.

These are valuable, but they are not prerequisites to closing the immediate
truth/parity/process gap. If Session 2 discovers one is required for a current
claim to be true, promote it from deferred to in-scope.

## Completion Criteria For The Two Sessions

After both sessions:

- Row archive cannot silently accept truth-critical TODO deferrals.
- Every row has a real-ask / implication artifact or equivalent validation.
- Every row has a test plan before implementation can be considered complete.
- Every row has a spirit-of-law completion check before archive.
- Parity tests cannot pass by skipping claimed behavior.
- Phase 1-4 claims are either true, downgraded, or explicitly marked failed.
- Pi parity claims only remain where the loaded Pi adapter enforces them.
- Backend/adapter boundary violations are either fixed or explicitly listed as
  blockers before roadmap continuation.
- Remaining roadmap rows have explicit cutover/removal semantics where they
  replace existing behavior.
- No planned row introduces a transitional mode, compatibility shim, duplicate
  source of truth, or optional path without a graduation/removal trigger.
- Roadmap dependencies and phase grouping reflect real sequencing and shared
  file collision risk, not only almanac schema validity.
