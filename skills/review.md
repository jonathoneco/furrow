# Step: Review

## What This Step Does
Evaluate implementation against spec and audit plan completion.

## What This Step Produces
- `reviews/{deliverable}.json` per deliverable (Phase A + Phase B results)
- Gate record in `state.json` with overall verdict

## Step-Specific Rules
- Phase A: verify artifacts exist, acceptance criteria met, planned files touched.
- Phase B: evaluate quality dimensions per artifact type.
- `overall` is `pass` only when both phases pass.
- Read `references/review-methodology.md` and `references/eval-dimensions.md`.

## Shared References
- `skills/shared/red-flags.md` — before any verdict
- `skills/shared/eval-protocol.md` — evaluator guidelines
- `skills/shared/git-conventions.md` — when reviewing commit quality
- `skills/shared/learnings-protocol.md` — when capturing learnings
- `skills/shared/context-isolation.md` — when dispatching review sub-agents

## Team Planning
For multi-deliverable work, assign review sub-agents per deliverable. Read `skills/shared/context-isolation.md`.

## Step Mechanics
Review is the final step. NEVER auto-advances — always requires gate evaluation.
On pass: work unit ready for archive. On fail: returns to implement step.

## Learnings
Append reusable insights to `.work/{name}/learnings.jsonl`.
Read `skills/shared/learnings-protocol.md` for schema and categories.
After review, scan artifacts for promotion candidates (architecture decisions,
patterns, specialist defs, eval dimensions). Present each with rationale.

## Research Mode
When `state.json.mode` is `"research"`:
- Implement step: load `evals/dimensions/research-implement.yaml`.
- Spec step: load `evals/dimensions/research-spec.yaml`.
- Phase A: verify `.work/{name}/deliverables/` files exist, match
  `plan.json` ownership, meet acceptance criteria from definition.yaml.
- Phase B: evaluate coverage, evidence-basis, synthesis-quality,
  internal-consistency, actionability. Verify citations.
- Scan deliverables for promotion candidates to flag at archive.
- Read `references/research-mode.md` for dimension selection logic.
