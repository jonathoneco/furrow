# Diagnose dual-migration friction and recommend next move -- Summary

## Task
Diagnose dual-migration friction (shell→Go CLI substrate, and Claude Code→Pi harness substrate) and produce a single recommended next move. Read-only diagnostic — no code changes, no new architecture proposals.

## Current State
Step: research | Status: not_started
Deliverables: 1/1
Mode: research

## Artifact Paths
- definition.yaml: .furrow/rows/migration-state-of-the-union/definition.yaml
- state.json: .furrow/rows/migration-state-of-the-union/state.json
- research.md: .furrow/rows/migration-state-of-the-union/research.md

## Settled Decisions
- **ideate->research**: pass — definition.yaml validated; research-mode row with single deliverable research.md and 7 acceptance criteria; supervised gate policy; user-approved scope

## Context Budget
Measurement unavailable

## Key Findings
- Empirical audit (§8 of research.md, 11 Pi sessions ~12MB JSONL) confirms the §7 framing but reshuffles priorities. Three findings dominate.
- (1) State-guard is confirmed working in production: 8+ "Blocked direct mutation" notifications across sessions; no workaround attempts. The `tool_call` interceptor at `adapters/pi/furrow.ts:883-899` is operationally sound. **My initial framing "Pi has no enforcement" was wrong.**
- (2) Empirical top-3 highest-friction gaps: **validate-definition (~670 mentions, 10 backend error codes)** — agents ship invalid definition.yaml, learn at transition; **ownership-warn (136 mentions)** — silent until transition; **post-compact recovery (no Pi equivalent at all)** — multi-session rows must rediscover context manually. The §7 audit's "n/a by design" classification of post-compact was empirically wrong.
- (3) Predicted-but-empirically-low: `validate-summary` had zero stop-with-broken-summary incidents in transcripts. Drops from priority list. `correction-limit` real friction (104-289 mentions) but cleaner as Pi-visibility (footer widget) than Pi-side hard block.
- The empirical record dominantly shows: agents producing wrong work locally, then being blocked only at transition. State correctness preserved (backend blocks); operator-experience burned. This validates the §7 thesis about state-correctness vs operator-experience parity.
- Migration A outer ring (`cli-architecture-overhaul`) and Pi phase-level lifecycle (triage, work-todos, multi-row) remain real gaps but **not what's causing the day-to-day headache**; punt to separate decisions.
## Open Questions
- Commit shape: bundle all almanac mutations into a single conventional commit (chore(almanac): inline triage from migration-state-of-the-union research) or split per category (status flips / drops / adds / renames)? Lean: single bundled commit referencing this research.md.
- After execution path completes (rows 2 + 3), schedule a re-triage pass to evaluate progress on cli-introspection-suite Tier 2/3 items.
- mine-claude-code todo: kept active per user direction, but the Claude session sweeps that ran in §8 + cli-gap discovery are partial fulfillment. Future row scoped to mine-claude-code can build on those audit outputs rather than re-mining.
## Recommendations
- Inline triage executed (research.md §11). 14 todos added via alm add; 6 status flipped active→done; 6 dropped (folded into post-install-hygiene-followup); 3 IDs renamed; cli-architecture-overhaul split with slice-2 as new active todo. alm validate + rws sort-invariant + alm triage all pass.
- New parent meta-todos: cli-introspection-suite (16 commands prioritized by Tier 1/2/3) and post-install-hygiene-followup (6 review-finding sub-items).
- Final 3-step execution path: (1) /furrow:archive migration-state-of-the-union; (2) /furrow:work pi-row-audit-cleanup (5 deliverables, includes furrow row repair-deliverables Go CLI); (3) /furrow:work pre-write-validation-go-first (4 deliverables — furrow validate definition/ownership Go CLIs + Pi tool_call handlers).
- Each row contributes ≥1 first-class Go command toward cli-architecture-overhaul-slice-2 (Migration A outer ring). After row 3 archives, re-evaluate pi-correction-limit-visibility, pi-session-resume-reground, state-guard-rm-coverage for conscious-pain promotion.
- Mutations staged but not committed; user to commit the almanac changes.
