# Completion Evidence and Claim Surfaces

Furrow archive readiness is a project-agnostic completion check. It exists to
prevent a row from closing because local artifacts satisfy a narrow checklist
while the user's real ask remains untrue.

This applies to any project type: application features, library changes, docs
work, migrations, infra changes, research rows, and Furrow's own dogfood rows.

## Core Concepts

**Literal ask** is what the user said.

**Real ask** is the useful outcome the user expects once implications are made
explicit.

**Completion evidence** is the row-local proof that the real ask is now true.
For new rows this evidence is captured in:

- `ask-analysis.md`
- `test-plan.md`
- `completion-check.md`
- optional classified `follow-ups.yaml`

**Deferral classification** separates harmless follow-up work from remaining
work that contradicts the completion claim:

- `outside_scope`
- `discovered_adjacent`
- `required_for_truth`

If `deferral_class` is `required_for_truth` and `truth_impact` is
`blocks_claim`, archive must fail. Capturing the item as a TODO is not enough;
the row must expand the work, downgrade the claim, or mark the row incomplete.

**Claim surfaces** are the places where the row claims behavior exists. Examples:

- CLI behavior and library API behavior.
- Runtime adapter behavior and backend behavior.
- Generated help/docs and actual command behavior.
- Unit-tested path and runtime-loaded entrypoint path.
- Two adapters claiming equivalent behavior.

When surfaces claim equivalent behavior, skipped, missing, mocked-only, or
structurally-present evidence does not count as pass unless the completion claim
is explicitly downgraded.

## Harness Boundary

Artifact handling is owned by the harness:

- Materialize row artifacts.
- Render scaffold templates.
- Parse stable artifact sections.
- Report artifact validation findings.

Readiness is also owned by the harness:

- Decide whether row state, artifacts, reviews, and deferrals are enough to
  transition or archive.
- Emit blockers through the canonical blocker taxonomy.
- Surface PR prep data for manual or automated publication.

Step skills and drivers author the evidence. They do not get to convert
truth-critical remaining work into harmless TODOs by wording alone.

## Compatibility

Historical rows are grandfathered. Strict completion-evidence gates apply to
new rows and to rows explicitly opted in for audit.
