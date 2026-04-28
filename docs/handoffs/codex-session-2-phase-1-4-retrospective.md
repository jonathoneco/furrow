# Codex Session 2 Handoff: Phase 1-4 Retrospective And Correction

Mode: out-of-harness Codex session
Recommended branch/worktree: `work/phase-1-4-truth-correction`
Prerequisite: Session 1 row truth gates completed or at least available as a
manual rubric.

## Mission

Audit completed Phases 1-4 against the spirit of the law, then fix or downgrade
claims. Do not accept "works enough to dogfood." A completed phase must be true
through the actual runtime paths it claims to support.

After that, harden the remaining roadmap using
`docs/handoffs/codex-roadmap-correction-hardening.md` before original Phase 5+
work resumes.

## Current Known Verdict

Phases 1-4 are mechanically loadable and substantially landed, but not sound.

Known issues:

- Pi parity is overstated.
- Pi layer-guard enforcement is not wired through the auto-discovered Pi adapter
  path.
- Backend hook inputs are Claude-shaped.
- Presentation protocol references point to a missing file.
- Blocker parity tests pass with Pi skips.
- Backend/adapter boundary is blurry.
- Follow-up TODOs were accepted for work required to make phase claims true.

## Scope

Use the Session 1 truth-gate rubric to audit and correct:

1. Phase 1: Post-install hygiene.
2. Phase 2: Backend contract foundations.
3. Phase 3: Pi enforcement parity.
4. Phase 4: Blocker taxonomy + delegation contract.

This session may change code, docs, schemas, tests, and roadmap wording. It may
also reshape planned phases when the current roadmap encodes future drift.

## Non-Goals

- Do not proceed with the original roadmap until this audit is resolved.
- Do not implement the gardener metaphor unless required for correctness.
- Do not do a full DFD unless needed to settle backend/adapter boundaries.
- Do not broaden into all future roadmap phases except to correct claims that
  rely on Phases 1-4.

## Workstreams

### W1: Actual Pi Parity

Problem:

`.pi/extensions/furrow.ts` loads `adapters/pi/furrow.ts`, but layer-guard
enforcement lives in `adapters/pi/extension/index.ts`.

Required outcome:

- The auto-discovered Pi adapter enforces every currently claimed Pi guard.
- Pi parity tests exercise the loaded adapter path, not only helper modules.
- No test named parity passes by skipping claimed behavior.

Likely tasks:

- Merge or compose `adapters/pi/extension/index.ts` into the canonical Pi
  adapter entrypoint.
- Update `.pi/extensions/furrow.ts` if needed.
- Add a loaded-entrypoint test.
- Remove or fail the blanket Pi skip rule for currently claimed behavior.

### W2: Adapter-Neutral Backend Contract

Problem:

Backend layer guard consumes Claude `PreToolUse` shape and treats Pi as a
translator into Claude-shaped JSON.

Required outcome:

- Backend accepts a Furrow-native normalized tool event.
- Claude adapter maps `PreToolUse` into the normalized event.
- Pi adapter maps `tool_call` into the normalized event.
- Core layer decision logic is runtime-agnostic.

Likely tasks:

- Add normalized `ToolEvent` schema and Go struct.
- Add `furrow layer decide` or equivalent.
- Keep `furrow hook layer-guard` as a Claude compatibility adapter.
- Point Pi at the normalized command.

### W3: Stop/Presentation Boundary

Problem:

`internal/cli/hook/presentation_check.go` parses Claude Stop-hook transcript
payloads in backend code, and skills reference missing
`skills/shared/presentation-protocol.md`.

Required outcome:

- `skills/shared/presentation-protocol.md` exists and is loaded by context.
- Backend presentation scanner receives normalized text/event data, not Claude
  transcript paths.
- Claude and Pi adapters own their runtime-specific transcript/message
  extraction.

Likely tasks:

- Add the missing presentation protocol.
- Add normalized presentation event shape.
- Keep Claude Stop hook as adapter shim.
- Add Pi-equivalent presentation event where feasible, or downgrade claim.

### W4: Adapter Boundary Cleanup

Problem:

Core/backend code renders `.claude/agents` and shared skills include runtime API
syntax.

Required outcome:

- Backend exposes driver definitions and adapter-neutral render data.
- Adapter-specific renderers own `.claude` and `.pi` artifacts.
- Shared skills describe abstract Furrow primitives.
- Runtime-specific mappings live in adapter templates or adapter docs.

Likely tasks:

- Move or clearly classify `.claude/agents` rendering as adapter tooling.
- Introduce templates for runtime-specific operator/driver instructions.
- Replace shared skill inline "Claude: Agent / Pi: pi-subagents" with abstract
  primitives and template-rendered mappings.

### W5: Phase Claim Reconciliation

Problem:

Roadmap titles/statuses imply completed truth where gaps remain.

Required outcome:

- Each Phase 1-4 claim is marked true, downgraded, or failed.
- Follow-ups required for truth are pulled into the correction scope.
- Roadmap wording no longer says parity where parity is not enforced.

Likely tasks:

- Create `docs/integration/phase-1-4-truth-audit.md`.
- Update roadmap phase titles/rationales/status if claims are downgraded.
- Add completion-check style verdicts for each phase.

### W6: Remaining Roadmap Hardening

Problem:

The roadmap can pass structural validation while still planning indefinite
hybrids, missing cutovers, adapter/backend ownership drift, or dual-source
truth.

Required outcome:

- Planned Phases 5-15 converge on the clean end state.
- Replacement rows include cutover/removal semantics.
- Transitional mechanisms include graduation/removal triggers.
- Dependency declarations reflect actual sequencing needs.
- Phase grouping reflects shared-file collision risk, not only the
  parallel-batch invariant.

Likely tasks:

- Follow `docs/handoffs/codex-roadmap-correction-hardening.md`.
- Create `docs/integration/roadmap-truth-hardening-audit.md`.
- Correct `roadmap.yaml` where the plan itself is unsound.
- Add explicit rows only when the work cannot be safely folded into existing
  rows.

## Brain-Dump Notes To Consider During Audit

- Look for ceremony/sequencing bugs surfaced by Phase 1-4.
- Confirm archive flow includes PR prep or mark it as hardening follow-up if
  Session 1 did not implement it.
- Reconcile project vs global learnings: which should become harness behavior,
  which should be dropped.
- Audit surface spread / optionality pain where it caused real review or
  implementation cost, e.g. `work_units` vs `rows`, `branch_name` vs `branch`.
- Check modularization and duplicate implementations during review.
- Flush out roadmapping reasoning where done/planned language hid prerequisites.
- Verify specialists are skills, not registered agent types.
- Use scout/dive research where multiple correction strategies exist.

## Suggested Verification

- `go test ./...`
- `bun test` and `bun run typecheck` in `adapters/pi`
- Loaded Pi entrypoint test through `.pi/extensions/furrow.ts`
- Claude hook shim test through `.claude/settings.json` command list where
  practical
- `tests/integration/test-blocker-parity.sh` with no claimed-behavior skips
- `tests/integration/test-layer-policy-parity.sh`
- `tests/integration/test-context-routing.sh`
- `tests/integration/test-presentation-protocol.sh`
- `furrow almanac validate`
- `frw doctor` with known unrelated failures explicitly categorized

## Exit Criteria

Session 2 is complete when:

- Phase 1-4 truth audit exists.
- Pi parity claims either pass through loaded runtime path or are downgraded.
- Backend/adapter boundary violations are fixed or listed as blockers.
- Missing presentation protocol is fixed or claims downgraded.
- Tests cannot pass parity by skipping claimed behavior.
- Roadmap is honest and convergent before original Phase 5+ work resumes.
