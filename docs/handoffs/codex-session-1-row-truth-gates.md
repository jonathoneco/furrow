# Codex Session 1 Handoff: Row Truth Gates

Mode: out-of-harness Codex session
Recommended branch/worktree: `work/row-truth-gates`

## Mission

Harden row functionality so ad-hoc rows and normal roadmap rows cannot archive
by satisfying the letter of a narrow spec while deferring work required for the
real ask.

This is process hardening, not a retrospective. Do not spend this session fixing
Phase 1-4 claims except where needed to test the new mechanisms.

## Core Problem

The harness allowed drift because it validated row-local artifacts and accepted
follow-up TODOs too readily. The missing primitive was a mandatory truth check:

> Can the user's real ask honestly be considered complete if this work is
> deferred?

If the answer is no, the item is not a TODO. It is remaining work.

## Scope

Implement row-level lifecycle support for:

1. Ask implications / real-ask analysis.
2. Test planning as a first-class artifact.
3. Deferral classification for captured TODOs and review findings.
4. Spirit-of-the-law completion checks.
5. Archive blockers when required-for-truth work is deferred.
6. PR prep as part of archive readiness.
7. Review passes for modularization and duplication.
8. Worktree discipline for implementation work.
9. Research option quality: true option spread and scout/dive pattern.
10. Specialist dispatch correction: specialists are skills, not registered
    agent types.

## Non-Goals

- Do not complete the Phase 1-4 retrospective.
- Do not rename operator/driver/engine to the gardener metaphor yet.
- Do not produce a full DFD for Furrow yet.
- Do not solve all schema optionality pain globally; add checks that expose it
  when it affects the current row.

## Deliverables

### D1: Ask Analysis Artifact

Add a required artifact:

`.furrow/rows/{row}/ask-analysis.md`

Minimum sections:

- Literal Ask
- Real Ask
- Implied Obligations
- Non-Deferrable Work
- Deferrable Work
- Runtime Surfaces Affected
- Spirit-Of-Law Completion Statement

Acceptance:

- Row validation can detect missing `ask-analysis.md`.
- The ideate transition or archive readiness surfaces a blocker if the artifact
  is absent for rows created after the feature lands.
- Existing archived rows are grandfathered unless explicitly re-audited.

### D2: Deferral Classification

Extend TODO/follow-up capture with classification fields, either in schema or in
an accompanying row-local artifact.

Required fields:

- `deferral_class`: `outside_scope | discovered_adjacent | required_for_truth`
- `truth_impact`: `none | weakens_claim | blocks_claim`
- `claim_affected`
- `defer_reason`
- `graduation_trigger`

Acceptance:

- Archive fails if any row-local follow-up has
  `deferral_class=required_for_truth` and `truth_impact=blocks_claim`.
- The failure message forces one of three actions:
  expand work, downgrade claim, or mark row incomplete.

### D3: Test Plan Artifact

Add a required artifact:

`.furrow/rows/{row}/test-plan.md`

Minimum sections:

- Claims Under Test
- Unit Tests
- Integration Tests
- Runtime-Loaded Entrypoint Tests
- Negative Tests
- Parity Tests
- Skips And Why They Do Not Weaken The Claim
- Manual Dogfood Path

Acceptance:

- Rows that change runtime behavior must name at least one loaded-entrypoint
  test or explicitly downgrade the runtime claim.
- Tests containing "parity" cannot treat skipped claimed behavior as pass.
- Archive surfaces missing or inadequate test plans.

### D4: Completion Check Artifact

Add a required artifact:

`.furrow/rows/{row}/completion-check.md`

Minimum sections:

- Original Real Ask
- What Is Now True
- What Is Only Structurally Present
- Deferred Work
- Does Any Deferral Block The Real Ask?
- Adapter/Backend Boundary Check
- Help/Docs/Reference Truth Check
- Final Verdict: `complete | incomplete | complete-with-downgraded-claim`

Acceptance:

- Archive refuses `incomplete`.
- Archive refuses `complete` when truth-blocking deferrals exist.
- `complete-with-downgraded-claim` requires summary/roadmap/docs wording to be
  downgraded in the same changeset.

### D5: Archive PR Prep

Archive readiness should include PR prep, even when the final push/PR is manual.

Required archive fields or generated artifact:

- Branch/worktree summary.
- Changed files by category.
- Test commands run.
- Known residual risks.
- Follow-ups with deferral classification.
- Suggested conventional commit / PR title.

Acceptance:

- `furrow row archive` or its readiness output surfaces PR prep data.

### D6: Review Hardening

Add review prompts/checks for:

- Modularization drift.
- Duplicate implementation of the same algorithm.
- Optionality/surface spread that imposes more pain than value.
- Runtime-loaded entrypoint mismatch.
- Specialists incorrectly treated as registered agents instead of skills.

Acceptance:

- Review artifacts must include a "Harness Process Risks" or equivalent
  section covering these checks.

### D7: Research And Options Protocol

Update step guidance so exploration produces real variety:

- Options must represent materially different approaches.
- Do not manufacture slight variants to steer the user toward the lean.
- Use scout/dive for broad unknown spaces:
  - Scout: wide scan, candidate list, ranked tradeoffs.
  - Dive: focused research per candidate.

Acceptance:

- `skills/research.md`, `skills/ideate.md`, or shared protocol text includes
  this rule.
- The rule is referenced from ask-analysis or planning guidance.

### D8: Worktree Discipline

Encode the operating rule:

- Exploration and planning may happen on `main`.
- Any implementation, however small, should happen in a worktree.

Acceptance:

- Row guidance and archive/readiness checks mention current branch/worktree
  status.
- If implementation occurred on `main`, completion check must call it out as a
  process deviation.

## Implementation Notes

- Prefer narrow Go validation commands plus markdown artifacts over adding a
  large new workflow engine.
- Keep old rows compatible. Apply strict requirements to new rows and to rows
  explicitly under retrospective audit.
- Do not let "we captured a TODO" satisfy any truth-critical gate.
- If schema changes become large, keep the first version markdown-backed with
  parser checks before broad schema migration.

## Suggested Verification

- Unit tests for new row validation helpers.
- Integration fixture: a row with truth-blocking deferred work must fail archive.
- Integration fixture: a row with outside-scope follow-up can archive.
- Integration fixture: parity test with skipped claimed behavior fails.
- `furrow almanac validate`
- Relevant `go test ./internal/cli/...`

## Exit Criteria

Session 1 is complete when a new row cannot honestly archive without:

- ask analysis,
- test plan,
- completion check,
- classified deferrals,
- no truth-blocking TODOs,
- PR prep evidence.

Leave a short handoff for Session 2 listing any hardening pieces not completed.
