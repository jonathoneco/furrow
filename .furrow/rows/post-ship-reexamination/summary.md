# Almanac watch-list primitive + decision-review TODO schema type — structured post-evidence re-examination -- Summary

## Task
Ship a first-class `observations` primitive to the almanac that captures post-ship re-examination signals. A stratified schema (`kind: watch | decision-review`) lives at `.furrow/almanac/observations.yaml`, validated, with a pull-model trigger system (MVP types: `row_archived`, `rows_since`, `manual`). Lifecycle state is persisted (`open | resolved | dismissed`); activation state (`active | pending`) is COMPUTED from archive history, never stored. `alm observe` CLI supports the full lifecycle; `alm validate` covers observations.yaml; `/archive` and `alm triage` surface active observations; the review step prompts for new observations; the existing `re-evaluate-dispatch-enforcement` TODO migrates to an observation and the `decision-review` workaround is removed from `todos.schema.yaml`.

## Current State
Step: implement | Status: not_started
Deliverables: 1/1
Mode: code

## Artifact Paths
- definition.yaml: .furrow/rows/post-ship-reexamination/definition.yaml
- state.json: .furrow/rows/post-ship-reexamination/state.json
- plan.json: .furrow/rows/post-ship-reexamination/plan.json
- research/: .furrow/rows/post-ship-reexamination/research/
- specs/: .furrow/rows/post-ship-reexamination/specs/
- team-plan.md: .furrow/rows/post-ship-reexamination/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Ideation ceremony complete: 4 decisions settled (stratified schema with kind discriminator, MVP triggers row_archived+rows_since+manual, full integration scope, observations.yaml). Definition validated against schema. Dual outside voice complete — fresh-agent + codex cross-model review at reviews/ideation-cross.json produced 8 findings, all applied: split lifecycle/activation status model, row_merged renamed to row_archived, rows_since activation predicate specified, dismiss verb added, alm validate extended, D4 migration ordering explicit, archive.md shared-surface risk acknowledged. Summary sections populated and validated. User approved advance.
- **research->plan**: pass — Research step complete: 3 parallel research agents produced per-topic findings (discriminator-idiom, alm-extension-blueprint, integration-points) plus synthesis.md. All 3 ideation open questions resolved (JSON Schema idiom = allOf+if/then+const with required on discriminator; alm triage gets additive active_observations key; schema evolution deferred). 1 new open question from research (validate-todos.sh does not exist) resolved via user-approved D1 AC8 amendment — validation stays inline in bin/alm:cmd_validate. Definition revalidated. Summary updated. User approved advance.
- **plan->spec**: pass — Plan step complete: plan.json (3 waves: D1 → D2 → D3 ∥ D4) and team-plan.md (7 architecture decisions AD-1..AD-7 with explicit research citations, specialist assignments, risk register, acceptance cadence). Dual-review: fresh Claude agent = pass with minor notes; codex = passed 3/4 dimensions (coverage/feasibility/specificity) and research-grounding fail was addressed by adding explicit Source: lines to each AD pointing at research artifacts. Wave 3 file ownership disjoint. Specialists: harness-engineer for D1/D2/D3, migration-strategist for D4. User approved.
- **spec->decompose**: pass — Spec step complete: 4 per-deliverable specs in specs/ directory covering all 32 definition.yaml ACs. Dual-review: fresh-agent pass on all 4 with 5 polish items (all applied inline); codex flagged consistency (D3 non-requirements phrasing — fixed) and test-scenario-coverage (missing show/resolve happy paths — added). Cross-spec interface contracts consistent. No open questions. User approved.
- **decompose->implement**: pass — Decompose step complete: validated plan-step plan.json + team-plan.md against decompose-step invariants (single-wave-per-deliverable, depends_on ordering, wave-local file ownership non-overlap, vertical-slice testability, team sizing). No corrections needed. Added Decompose validation section to team-plan.md for audit trail. Ready to implement 3 waves: W1=D1, W2=D2, W3=D3||D4. User approved.

## Context Budget
Measurement unavailable

## Key Findings
- Decompose validation passed against plan.json + team-plan.md authored during the plan step. All 5 decompose-specific invariants satisfied: single-wave-per-deliverable, depends_on ordering, wave-local file-ownership non-overlap, vertical-slice testability per deliverable, team-size sanity.
- No corrections required; implement-step can consume plan.json + team-plan.md as-is.
- Branch `work/post-ship-reexamination` is already active (set by `rws init` during ideate); implement step does NOT re-branch.
- Wave breakdown confirmed: W1=D1 (observations-schema), W2=D2 (alm-observe-cli), W3=D3 ∥ D4 (archive-and-triage-integration, migration-and-review-prompt).
- Specialists assigned: harness-engineer for D1/D2/D3 (schema + CLI + harness integration); migration-strategist for D4 (ordered atomic-commit migration).
- Added a "Decompose validation" section to team-plan.md with the invariant cross-checks for auditability.

## Open Questions
None. Decompose only validates; no new open questions surfaced.

## Recommendations
- Advance to implement step. Implement-step agent (orchestrator) dispatches per-wave. W1 → W2 → W3. W3 dispatches D3 and D4 in parallel to harness-engineer and migration-strategist respectively.
- Implement step should read specs/*.md per deliverable and apply changes, then run `alm validate` + targeted manual smoke tests per scenario from the specs.
- D4 is the most fragile — enforce single-commit atomicity. The implementer should stage all 5 files, run `alm validate` 3 times (between each sub-step), and commit only on all-green.
- `commands/archive.md` shared edit surface with `work/install-and-merge`: no coordination needed now because that worktree has no commits. Revisit at merge-time.
