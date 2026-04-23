# Cleanup from install-and-merge post-ship review -- Summary

## Task
Close the 8 review-findings from the install-and-merge post-ship audit: harden test isolation so integration tests cannot mutate the live worktree, scope cross-model review diffs per deliverable, wire XDG config fields to their runtime consumers, consolidate schema validation for reintegration, fix the rescue.sh exec contract, repair the learnings promotion script, unify specialist symlink handling as install-time artifacts, and add the missing single-fixture AC-10 e2e coverage.

## Current State
Step: review | Status: completed
Deliverables: 8/8
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/post-install-hygiene/definition.yaml
- state.json: .furrow/rows/post-install-hygiene/state.json
- plan.json: .furrow/rows/post-install-hygiene/plan.json
- research/: .furrow/rows/post-install-hygiene/research/
- specs/: .furrow/rows/post-install-hygiene/specs/
- team-plan.md: .furrow/rows/post-install-hygiene/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Definition validated (frw validate-definition ok). 8 deliverables bundled per roadmap Phase 1. 5 design decisions agreed (D1-D5 in ideation-decisions.md). Dual outside-voice review completed: fresh subagent + codex cross-model via frw cross-model-review --ideation. Both reviewers converged on depends_on gaps, bin/frw file-ownership collision, and archived-row back-compat for test_results.evidence_path — all three addressed in the revised definition. Wave structure: wave-1 test-isolation-guard; wave-2 six parallel deliverables; wave-3 cross-model-per-deliverable-diff (depends on xdg-config resolver). Supervised gate policy. User explicitly approved advancing to research.
- **research->plan**: pass — Four parallel explorer agents surveyed 8 deliverables across test-infra, schema-validators, cross-model-XDG, and install-artifacts. Findings consolidated in research/synthesis.md with per-topic docs. User decisions taken (R1-R4 in research-decisions.md): R1 all 19 non-executable scripts, R2 migrate 4 old-format learnings rows to canonical new schema, R3 in-row preferred_specialists consumer in specialist-delegation.md, R4 extend self-hosting.md rather than create new install-architecture.md. Three mechanical AC revisions (M1-M3) queued for plan step: fix wrong git-log command, align to existing resolve_config_value helper, downgrade archived-row migration AC given empty on-disk set. Dependency graph unchanged; no new or removed deliverables.
- **plan->spec**: pass — Plan artifacts complete: revised definition.yaml (R1-R4 + M1-M3 applied, schema valid), plan.json with 3-wave structure (wave-1 test-isolation-guard; wave-2 six parallel deliverables; wave-3 cross-model-per-deliverable-diff after xdg), team-plan.md with AD-1..AD-7 each citing specific research sections. Dual-reviewer pass: fresh subagent needs-minor-revision with 4 issues all addressed (get_config_field->resolve_config_value retraction, 3 missing risks, file_ownership drift); codex review 3/4 dimensions pass with research-grounding addressed by adding citations. Risk register expanded 6->11 rows including learnings migration commit semantics, in-flight evidence_path validation, scope-expansion blessing, wave-3 coordination. File_ownership disjoint in wave-2 verified. User explicitly approved advancing to spec.
- **spec->decompose**: pass — 8 spec files in specs/ directory (1824 lines total). Dispatched 3 parallel spec-writing subagents. Dual-reviewer: fresh subagent ready-with-minor-fixes, codex overall=fail due to input-size truncation false positive (all 8 specs verified full-length via wc -l). Applied 5 targeted fixes: inverted !-grep corrected in specialist-symlink-unification, 19->20 script count reconciled via spec-time git ls-files -s verification, no-dispatcher-special-case promoted to AC-7 in script-modes-fix, promote-learnings validator coupling hardened to hard dep (no inline fallback), reintegration-schema-consolidation AC-3 quotes existing schema shape. Cross-spec consistency verified for resolve_config_value, setup_sandbox, validate-json.sh across all specs. Definition.yaml re-validated. One decompose constraint surfaced: within wave-2, reintegration-schema-consolidation implements validate-json.sh helper before promote-learnings-schema-fix's hook calls it. User explicitly approved advancing to decompose.
- **decompose->implement**: pass — Decompose step refined team-plan.md with 5 required sections (Scope Analysis, Team Composition, Task Assignment, Coordination, Skills, Validation). Model routing resolved: both specialists have model_hint: sonnet; all 8 deliverables implement on sonnet. Wave assignments: 1+6+1 deliverables; 8 agent invocations total (1 test-engineer + 6 harness-engineer + 1 test-engineer across the 3 waves). Intra-wave-2 ordering constraint resolved via Strategy B (parallel authoring, merge-sequenced so validate-json.sh lands before append-learning.sh). Validation checklist complete: every deliverable in exactly one wave, depends_on respected, file_ownership disjoint within waves, all specialists exist with valid frontmatter. Post-implement 4-point cross-check specified. User approved.
- **implement->review**: pass — All 8 deliverables implemented across 3 waves (wave-1: 1 deliverable; wave-2: 6 parallel deliverables; wave-3: 1 deliverable) plus 1 cleanup commit. 9 commits on work/post-install-hygiene since base 5110add: 78f3a7e, 247a384, 76d532c, 5232e94, 4e5ba77, 9463108, 7c81e7b, 919448d, d924002. 4-point post-implement cross-check all pass: append-learning.sh sources validate-json.sh, resolve_config_value single resolver, all bin/frw.d/scripts/*.sh at 100755, 0 tracked + 22 install-time specialist symlinks. 0 correction-limit triggers across all 8 deliverables. Test results: all new and pre-existing integration tests pass (60/60 reintegration, 75/75 merge-e2e, 16/16 config-resolution, 13/13 cross-model-scope, 10/10 migrate-learnings, 16/16 promote-learnings, 8/8 specialist-symlinks, 10/10 script-modes, 11/11 sandbox-guard). Known parallel-dispatch race condition flagged in learnings (3 entries captured). Pre-review cleanup applied: append-learning hook registered in .claude/settings.json. Pre-commit-script-modes.sh left unregistered consistent with sibling latent git-pre-commit hooks. User explicitly approved advancing to review.

## Context Budget
Measurement unavailable

## Key Findings
Review step complete — overall verdict PASS (8/8 deliverables).
- Phase A: all 8 deliverables pass deterministic checks (all 4 post-implement cross-checks hold + per-deliverable AC verifications).
- Phase B: 2 fresh Claude reviewers (batched 4+4) + 1 dog-food cross-model review. Combined verdicts: 7/8 unanimous PASS; 1 divergence on test-isolation-guard (fresh PASS all 5 dimensions; codex FAIL on 3 dimensions due to literalist AC reading). Divergence recorded and flagged as follow-up TODO (either tighten AC-1 wording or add a mocked-harness test variant).
- Cross-model dog-food confirms wave-3 per-deliverable diff scoping works: codex received exactly 1 commit (78f3a7e) and 11 files for test-isolation-guard, not the full 9-commit base..HEAD range. This closes the install-and-merge "unplanned-changes cross-deliverable leakage" bug.
- 3 non-blocking WARN notes: (a) test-isolation-guard fresh/cross divergence on AC interpretation, (b) one shellcheck SC2221/SC2222 in append-learning.sh:105, (c) script-modes-fix AC-3 hook registration deferred during implement and closed post-review in commit d924002.
- Full synthesis in .furrow/rows/post-install-hygiene/reviews/synthesis.md.

## Open Questions
7 follow-up TODOs identified during review (all scope-external; add via alm observe add after archive):
1. test-isolation-guard AC-1 literal read vs implementation intent — tighten AC or add mocked-frw test variant.
2. Shellcheck SC2221/SC2222 in append-learning.sh:105 (redundant case pattern alternative).
3. Shellcheck SC2154/SC2034 in test-sandbox-guard.sh / test-install-source-mode.sh.
4. Commit 5232e94 message misattribution (cosmetic; rebase-reword or leave with review note).
5. pre-commit-script-modes.sh unwired — decision needed on whether to wire any/all of the three latent git-pre-commit hooks (bakfiles, typechange, script-modes).
6. test-hook-cascade.sh invariant — stop-ideation.sh now sources common.sh; existing invariant needs whitelist/split.
7. Parallel-dispatch race conditions — harness-level fix candidates: worktree-per-deliverable, index-mutex, sequential-merge-orchestration.

## Recommendations
- Archive. All 8 deliverables PASS review. Branch work/post-install-hygiene has 9 commits ready for merge via /furrow:merge. No blocking issues; 7 follow-up TODOs are scope-external and should be captured via alm observe add as part of archive.
- When the merge runs, /furrow:merge can dog-food the new per-deliverable diff scoping further — this row is a richer stress test than the test-isolation-guard single-commit smoke check.
- Open a Phase-2+ TODO for harness-level parallel-dispatch fixes; the 3 race-condition learnings captured here are the motivation. Decision on worktree-per-deliverable vs index-mutex vs sequential-merge is an architectural question warranting its own row.
