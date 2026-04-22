# Install architecture + ~/.config/furrow/ tier + /furrow:merge skill + worktree reintegration summary -- Summary

## Task
Establish install-artifact trust boundaries (self-hosting detection, XDG state/config split, merge-conflict-resistant data files), produce the /furrow:merge skill with a human-in-the-loop resolution plan, and formalize worktree reintegration summaries so main sessions get a structured handoff.

## Current State
Step: implement | Status: not_started
Deliverables: 0/4 (defined)
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/install-and-merge/definition.yaml
- state.json: .furrow/rows/install-and-merge/state.json
- plan.json: .furrow/rows/install-and-merge/plan.json
- research/: .furrow/rows/install-and-merge/research/
- specs/: .furrow/rows/install-and-merge/specs/
- team-plan.md: .furrow/rows/install-and-merge/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Definition: 4 deliverables / 33 ACs / 8 constraints; schema-validated. Dual outside-voice: same-model (revise) + codex cross-model (questionable, 5 revisions). All revisions applied: frw rescue moved to deliverable 1, test ACs added to all four, migration safety with install-state.json, promotion-targets scaffolding-only, protected-file policy formalized, reintegration schema-backed, sharded-todos rejection recorded, source_todos back-compat. Schema extended: source_todos array supported.
- **ideate->research**: pass — Post-revision validation: schema-valid after source-repo schema mirror. Dual outside-voice synthesized; three convergent revisions applied (frw rescue ordering to deliverable 1, test ACs on all four, migration-safety explicit). Boundary-crossing to mirror schema into source repo logged as learning — exact phenomenon this row fixes.
- **research->plan**: pass — 5 research files + synthesis.md produced. All 4 ideation open questions resolved (common.sh split=line 168, legacy-install heuristic validated, frw upgrade top-level, shard-deferred). 4 new plan-step open questions surfaced. Live evidence in R3 confirms the problem (24 escaped symlinks, bin CLIs are symlinks, 5 untracked .bak). R4 external prior art (brew/nix/git templates) feeds rescue design. R5 designs merge-policy.yaml and reintegration.schema.json shapes.
- **plan->spec**: pass — plan.json (3 waves, 14 sub-steps in wave-1), team-plan.md (specialists + 3 consultants + handoff contracts), architecture-decisions.md (AD-1..AD-9 with research-file citations). All 4 open questions resolved. Dual review: fresh same-model pass (3 concerns applied as AD-8/AD-9 + sub-steps 1m/1n); codex cross-model pass on re-run after citation fixes (4/4 dimensions green).
- **spec->decompose**: pass — 4 component specs written (~2100 lines), refined ACs + scenarios per template. Dual review 2 rounds: fresh revise (5 concerns) + codex fail (4 dimensions) consolidated to 13 concrete issues; all 13 resolved. Final fixes: AC-G function count 7->8, AC-R5 placeholder wording, gate_policy naming, migration_version string-typed, rescue exit codes unified (2/3/4), --keep-legacy + migration_chain removed, rws validate-sort-invariant added to wave-1 interface, /furrow:merge --resume documented, jq-only template engine, repo-slug normalization. Definition.yaml AC-1 reworded to match spec; re-validated.
- **spec->decompose**: pass — 4 component specs renamed to match deliverable names; dual-review 2 rounds closed 13 concrete issues (unified migration_version string, rescue exit codes, removed scope-creep fields, added validate-sort-invariant/--resume/AC-2/3/4 scenarios/AC-1 scenario, jq-only template, repo-slug normalization). Definition.yaml AC-1 reworded to match spec; re-validated.
- **decompose->implement**: pass — Decompose produced 26-task enumeration across 3 waves; plan.json extended with internal_sequencing for waves 2 (2a-2m) and 3 (3a-3j) to match wave-1's pre-existing 1a-1n. team-plan.md extended with dispatch plan + sizing rubric + vertical-slicing verification. File ownership disjoint within parallel wave 2 re-confirmed.

## Context Budget
Measurement unavailable

## Key Findings
- **26 tasks enumerated across 3 waves** (plan.json `internal_sequencing` for each wave's deliverables).
- Wave 1: 14 tasks (1a–1n) in install-architecture-overhaul, split Foundation (1a–1e, additive) / Enforcement (1f–1n, behavior-changing).
- Wave 2: 13 tasks in parallel (config-cleanup 2a–2g + worktree-reintegration-summary 2h–2m).
- Wave 3: 10 tasks (3a–3j) in merge-process-skill.
- **Each task sized to a single sub-agent dispatch** (~1 PR's worth of code + tests, ~200-600 LOC, atomic commit).
- **File-ownership disjoint within parallel wave 2** (re-validated in decompose): config-cleanup owns schemas/definition+state+promotion-targets + bin/frw + commands/next.md + upgrade.sh + docs/architecture/config-resolution.md; reintegration-summary owns schemas/reintegration + bin/rws + launch-phase.sh + generate-reintegration.sh + templates/reintegration.md.tmpl + skills/implement.md + skills/shared/context-isolation.md. Empty intersection.
- **Implement-step dispatch plan**: wave 1 sequential (foundation then enforcement, same agent); wave 2 fans out to 2 parallel harness-engineer sub-agents; wave 3 single merge-specialist sub-agent. Consultant engagements at wave boundaries per team-plan.
- **Vertical slicing verified**: each deliverable is independently testable at its wave boundary — no hidden cross-deliverable dependencies beyond the declared depends_on chain.
- **All 6 prior gates recorded** (2 ideation, 2 plan, 2 spec) + this step's 2 → 8 by end of decompose.

## Open Questions
- **Implement-step**: for wave 1 Foundation pass, the 24-symlink repair commit (task 1b) will touch `.claude/commands/specialist:*.md`. The repo currently has these as committed escape-symlinks. The repair-commit must land BEFORE the pre-commit type-change hook (task 1g) — else the hook would block the repair. Sequencing within wave 1 already enforces this (1b in Foundation, 1g in Enforcement), but flag for implementer awareness.
- **Implement-step**: wave-2 parallelism depends on no shared writes to `bin/frw.d/scripts/launch-phase.sh`. Config-cleanup does not write this file; reintegration-summary is the sole wave-2 editor of it (plan.json `parallel_safety` note). Implementer must NOT add a launch-phase.sh edit to config-cleanup without reviewing the ownership chart.
- **Review-step**: sharded-`todos.d/` revisit trigger — continues deferred from ideation/plan/spec; no change.

## Recommendations
- **Advance to implement step.** Implementation proceeds wave by wave per the plan.json sequencing.
- Specialist dispatch: for each wave, dispatch one sub-agent per deliverable with the deliverable's spec + its internal_sequencing task list + file_ownership as input.
- Consultant engagements: test-engineer reviews the test ACs in EACH deliverable before implementation begins (catches un-testable ACs early); shell-specialist spot-reviews each wave's final PR; complexity-skeptic reviews wave-1 enforcement block and wave-2 boundary.
- Commit discipline: each lettered sub-step corresponds to an atomic commit with a conventional-commits subject line mentioning the sub-step id (e.g., `feat(install): 1c common-minimal.sh hook-safe library [AC-G]`).
- Correction limit: keep default 3 per deliverable (from .claude/rules/cli-mediation.md). Escalate to human if exceeded.
- Learnings recording: each sub-agent appends to `.furrow/rows/install-and-merge/learnings.jsonl` at wave boundaries.
