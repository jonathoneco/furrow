# Almanac watch-list primitive + decision-review TODO schema type — structured post-evidence re-examination -- Summary

## Task
Ship a first-class `observations` primitive to the almanac that captures post-ship re-examination signals. A stratified schema (`kind: watch | decision-review`) lives at `.furrow/almanac/observations.yaml`, validated, with a pull-model trigger system (MVP types: `row_archived`, `rows_since`, `manual`). Lifecycle state is persisted (`open | resolved | dismissed`); activation state (`active | pending`) is COMPUTED from archive history, never stored. `alm observe` CLI supports the full lifecycle; `alm validate` covers observations.yaml; `/archive` and `alm triage` surface active observations; the review step prompts for new observations; the existing `re-evaluate-dispatch-enforcement` TODO migrates to an observation and the `decision-review` workaround is removed from `todos.schema.yaml`.

## Current State
Step: implement | Status: not_started
Deliverables: 4/4
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
- **implement->review**: pass — All 4 deliverables shipped 0 corrections; alm validate green; commits 677da44 c0f196f 93e4f4b 994f905; summary validated

## Context Budget
Measurement unavailable

## Key Findings
- All 4 deliverables landed across 3 waves with 0 corrections each. `alm validate` green on both todos.yaml and observations.yaml post-migration.
- D1 schema uses `allOf` + `if/then` + `const` with `required: [<discriminator>]` inside every `if` — the primary-source-verified idiom that prevents vacuous match. Discriminators on both `kind` (watch | decision-review) and `triggered_by.type` (row_archived | rows_since | manual). `additionalProperties: false` at item and `triggered_by` levels.
- D1 structural deviation forced by JSON Schema semantics: union of kind-specific optional+required properties had to be declared at the outer `items.properties` level, because `additionalProperties: false` doesn't see fields inside `allOf`/`then`. Branches still enforce kind-specific `required` and kind-specific `resolution` shape intersection. Net behavior matches spec.
- D2 split `cmd_validate` into `cmd_validate_todos` + `cmd_validate_observations` behind a thin dispatcher. Public `cmd_validate "<path>"` signature preserved via basename inference — existing callers (`cmd_add`, `cmd_triage`) route correctly without change. `exit 3` → `return 3` in per-file validators so the aggregate mode tallies both.
- D2 on-archive stateless with-row / without-row diff is implemented via an optional exclude-row parameter on `_observe_compute_activation`. Handles row_archived matching, rows_since where since_row is excluded, and rows_since where exclude is a counted row past baseline — no state mutation.
- D3 placement deviations (semantic-equivalent, documented in commit): `active_observations` key in roadmap.yaml placed between `deferred` and `handoff` since the current shape has no top-level `waves` key; triage.md template block placed before the repeating phase blocks since the template has no separate phase table.
- D4 migration executed atomically with `alm validate` green between each of the three ordered sub-steps (add to observations → remove from todos → tighten enum). The prose `work_needed` transformed into structured `question`/`options`/`acceptance_criteria`/`evidence_needed`. `created_at` preserved verbatim (2026-04-09Z) for audit trail.
- `ALM_OBSERVATIONS` made env-overridable for test isolation (backward-compatible: unspecified env falls back to spec path).
- D3's test runs produced a race on `observations.yaml` that was self-healing (D3 backup-restored, D4 ultimately wrote the migrated entry as the sole resident). Current on-disk state is correct; future parallel dispatch should consider temp-file isolation instead of backup/restore.

## Open Questions
- **rationale.yaml entry for observations.schema.yaml** — Wave 1's agent flagged that a rationale entry (`exists_because` + `delete_when`) should be added but could not write it under file-ownership rules. Recommended body is captured in D1's agent report. Review step should either add it now or accept it as follow-up.
- **Residual `decision-review` string in todos.yaml:1965** — inside the `context` prose of TODO `decision-review-todo-type` (which narrates the workaround this row eliminates). Validates clean (prose, not enum). Should this TODO itself now be resolved/removed, or left as a post-migration historical artifact?
- **Pre-existing `alm next` bug** — D3 discovered `cmd_next` iterates `.rows[]` while `cmd_triage` emits `work_units`. Not in scope for this row. File a TODO at review time.
- **D3's test observations persisted briefly in the live file** — the parallel-dispatch backup-restore pattern is fragile. Worth capturing as a learning: test-time mutations of almanac files should use `ALM_OBSERVATIONS` env override (introduced in D2) rather than backup/restore.

## Recommendations
- Advance to `review` step. All 4 deliverables shipped with 0 corrections; `alm validate` green; the full observation lifecycle smokes clean (add → list → show → activate → resolve/dismiss → on-archive). D3 and D4 committed as separate commits (D4 atomic per AD-7).
- Review step should sign off on the two D3 placement deviations (roadmap.yaml key position, triage.md template block position) — both semantic-equivalent to spec intent but visibly different from the literal wording.
- Review step should decide the rationale.yaml entry question — add it now or file as TODO. Recommended `exists_because`: "Enforces structural contract for observations.yaml — required fields per kind, per trigger type, and additionalProperties rejection. Every consumer (alm validate, alm observe writes, alm triage reads) relies on these guarantees." Recommended `delete_when`: "Observations subsystem is removed or replaced by an alternative persistence layer; do not delete while observations.yaml exists or alm observe/validate reference it."
- Review step should capture the `alm next` bug as a TODO (category: quality, component: alm).
- Review step should capture the backup-restore vs env-override lesson as a learning on this row (category: process, applies to: parallel dispatch testing).
- On merge to main: `commands/archive.md` edit surface overlaps with the `work/install-and-merge` worktree. That row currently has 0 commits, so no conflict exists at head, but a textual merge will be needed whenever the second row lands. Mitigation already in the risk register — rebase whichever row lands second.
