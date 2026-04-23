# Evaluate migrating Furrow harness to a pluggable agent host -- Summary

## Task
Migrate Furrow to run on Pi (Mario Zechner's pi-mono/coding-agent) as a second supported host, keeping Claude Code fully functional as a hedge. Produce the host adapter interface, a Pi adapter implementation, and composable integration with the Pi plugin ecosystem. Any harness improvement discovered during migration that is host-independent must apply to BOTH Pi and CC — dual-host parity; Pi-only capabilities must document a CC shim or upstream-ask path. Decision outcome of ideation research: migrate to Pi; preserve CC as dual-host end state.

## Current State
Step: research | Status: not_started
Deliverables: 0/5 (defined)
Mode: research

## Artifact Paths
- definition.yaml: .furrow/rows/agent-host-portability-research/definition.yaml
- state.json: .furrow/rows/agent-host-portability-research/state.json
- research/: .furrow/rows/agent-host-portability-research/research/

## Settled Decisions
- **ideate->research**: pass — 4-deliverable research row; dual outside-voice review (fresh sonnet + codex gpt-5.4) returned revise-and-proceed; 9 revisions applied (Agent SDK added to matrix as 6th row; Pi-bias neutralized to 'leading candidate'; interface scope tightened to inventory+sketch; spike retargeted from /work-ideate to rws-status+one-gated-Write+one-subagent; source tiering T1-T5 added; matrix axes locked before scoring; memo AC quantified with blocker+tradeoff; session-4 abort constraint added); schema valid; summary valid across all three sections; 7 open questions logged for research step.
- **research->plan**: pass — 5-deliverable research row reshaped to research+implementation. 9 parallel research agents complete (R1-R6, R8-R10). Pi as primary target, upstream-only, compose @tintinweb/pi-subagents. pi-permission-system rejected per R9 — Pi's native tool_call is superset of CC PreToolUse. session_before_compact stronger than CC post-compact. Dual-host parity principle added: every host-independent improvement applies to both bindings. R10 adopts integrated (typed schema blocks, typed produces, pattern library, stagnation safeguard, specialist packaging). Memory learn-from integrated (3 adopt, 5 defer, 1 skip). Install hardening per R9. RPC-mode T4 experiment gates cross-model review. 9 open questions for plan step. Almanac TODO logged for rws change-mode CLI gap.

## Context Budget
Measurement unavailable

## Key Findings
- Plan step complete. 4 phases of architectural decisions locked: P-1/P-2/P-3/P-4/P-5 (top-level), P2-1..P2-7 (Pi adapter architecture), P3-1..P3-8 (schema improvements), P4-1..P4-7 (plan artifacts). Phase files retain the reasoning trail.
- Row now has 6 deliverables, 6 waves, linear dependency DAG. Added `harness-schema-upgrades` as 6th deliverable (per P4-1(b)) between interface and adapter.
- Dual-host parity meta-principle: host-independent improvements apply to BOTH Pi and CC; Pi-only capabilities require CC shim or upstream-ask. No silent Pi-only improvements.
- CC binding extraction STAGED to follow-up row (per P-2). CC continues to work unchanged during Pi migration. 9 almanac TODOs track deferred behavior-level improvements + CC extraction.
- Migration target: upstream Pi (@mariozechner/pi-coding-agent) only; global install (per P2-4 user divergence from project-local lean — different projects shouldn't want different versions).
- Pi binding: one extension with internal TS module tree (per P2-2(c)); event handling in TS, state mutation via shell CLIs (per P2-7(c)); jiti handles TS compilation no build step.
- State-guard / correction-limit / ownership-warn implemented via Pi's native `pi.on("tool_call")` — supersedes pi-permission-system (wrong primitive per R9).
- Subagent dispatch via `@tintinweb/pi-subagents` with specialist-as-data config (per P2-3(c)) — each specialist markdown gets `dispatch:` frontmatter consumed at dispatch time.
- Compaction uses Pi's `session_before_compact` (strictly stronger than CC's post-compact); core-preferred with host-override pattern (per P2-6(a)) — sets precedent for other override points.
- 3 schema-level improvements kept in this row (host-independent, apply to CC + Pi automatically): typed JSON-Schema blocks for almanac with defense-in-depth validation, typed `produces:` outputs per deliverable complementing `file_ownership:`, specialist YAML-contract frontmatter.
- `harness-schema-upgrades` is a two-phase deliverable (per P4-3(c)): Phase A schema design by systems-architect, Phase B implementation + migration by harness-engineer. Handoff document required.
- Version pin Pi exactly in install script; no pi.dev dependency; preflight `pi --version`; graceful extension-install failure (per R9).
- Specialist migration: script-generated defaults + human review pass for all 22 existing specialists (per P3-7(c)).
- Existing almanac drift will be normalized as part of Wave 3 (9 entries with `open_questions`, entry 67 fixed separately). Post-normalization, `alm` enforces strict.
## Open Questions
- T4 (must pass before pi-adapter Wave 4 is committed): does `pi --mode rpc --no-session` fire extension hooks? One-line experiment required.
- WXP pre-LLM preprocessor mechanism — evaluate in a follow-up row; almanac TODO tracks.
- **Harness gap discovered this step**: `frw cross-model-review --plan` is documented in skills/plan.md but not implemented in the CLI (only `--ideation` works). Plan-step cross-model review was skipped; fresh-Claude reviewer only. Follow-up row should either implement `--plan` mode or update the skill doc to match actual CLI.
- Harness gaps surfaced during plan step (all logged in almanac):
  - `rws change-mode` + `rws rename-row` CLIs (row scope-change support)
  - Almanac schema drift — 9 pre-existing entries have unsupported `open_questions` field blocking new `alm add`; normalization in Wave 3 addresses
  - `plan.json` schema doesn't allow free-form `note:` field — moved two-phase context to team-plan.md
  - TS-migration for frw/rws/alm/sds CLIs (P2-7 side note) — couldn't log via alm due to drift; noted here until drift is fixed
- 3 `.furrow/almanac/rationale.yaml` entries unmapped to any surface — delete or re-map during Wave 2 interface draft.
- `frw hook gate-check` registered no-op — delete during Wave 4 adapter work.
- CC hook stdin shape drift (`.tool_input.file_path` / `.filePath` / `.path`) — normalize during Wave 4.
- Agent SDK's in-tree adapter scaffolding (26 TODO stubs, stale paths) — delete as part of Wave 4 adapter cleanup.
- Review-step verification of `produces:` (per P3-5(c) bidirectional structural diff) — needs implementation design during Wave 3 Phase A.
## Recommendations
- Advance plan → spec. Fresh-Claude plan reviewer returned revise-and-proceed (4 pass / 5 concerns); all 5 concerns addressed by targeted edits to definition.yaml and team-plan.md. No blocker-level findings.
- Reviewer-driven revisions applied: (1) `schemas/host-adapter-interface.schema.json` added to pi-adapter-interface file_ownership, (2) AC language tightened — gap-analysis now enumerates "documented tolerances," interface AC replaces subjective "fresh" with verifiable "no verbatim copy," pi-adapter AC2 references the tolerances checklist, (3) harness-schema-upgrades gained explicit rollback procedure + intermediate CC-smoke-test ACs, (4) new constraint requires `frw doctor --host cc` pass at every wave-boundary commit (mechanical parity enforcement, not just Wave 6), (5) team-plan.md Wave 4 adds typescript-specialist consultation note; Wave 3 adds scope-watch note.
- Cross-model plan review skipped (CLI `--plan` mode not implemented — harness gap logged).
- Spec step sequences per deliverable: produce acceptance-criteria-to-test mapping, define verifiable assertions, identify cross-deliverable spec concerns.
- `harness-schema-upgrades` Wave 3 remains highest-risk; spec must produce the rollback-procedure detail and the migrated-but-not-strict smoke-test script.
- `pi-adapter` Wave 4 gates on T4 RPC-mode hook-firing experiment — spec must include the one-line experiment and pass criteria.
- Dual-host parity now enforced mechanically via wave-boundary `frw doctor` — spec should describe what "passes" means per host at each boundary.
- After plan → spec transition, the 9 almanac-logged follow-up TODOs become candidates for post-migration rows. Surface via `/furrow:triage`.
