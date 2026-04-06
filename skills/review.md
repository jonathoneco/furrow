# Step: Review

## What This Step Does
Evaluate implementation against spec and audit plan completion.

## What This Step Produces
- `reviews/{deliverable}.json` per deliverable (Phase A + Phase B results)
- Gate record in `state.json` with overall verdict

## Model Default
model_default: opus

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
- `skills/shared/summary-protocol.md` — before completing step

## Team Planning
For multi-deliverable work, assign review sub-agents per deliverable. Read `skills/shared/context-isolation.md`.
When spawning reviewer agents, read the specialist's `model_hint` from frontmatter
and pass as the Agent tool's `model` parameter. Resolution: specialist `model_hint` > step `model_default` > sonnet.

## Step Mechanics
Review is the final step. No pre-step evaluation — review always runs.
Post-step gate evaluates Phase A and Phase B results across all deliverables.
Reference: `evals/gates/review.yaml` post_step, per `skills/shared/gate-evaluator.md`.
On pass: row ready for archive. On fail: returns to implement step.

## Supervised Transition Protocol
Before completing review:
1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
2. Present review findings to user per `skills/shared/summary-protocol.md`.
3. Ask explicitly: "**Ready to archive?** Yes / No"
4. Wait for user response. Do NOT proceed without explicit approval.
5. On "yes": proceed with archive per `/furrow:archive` command.
6. On "no": ask what needs to change, address feedback, return to step 2.

## Learnings
Append reusable insights to `.furrow/rows/{name}/learnings.jsonl`.
Read `skills/shared/learnings-protocol.md` for schema and categories.
After review, scan artifacts for promotion candidates (architecture decisions,
patterns, specialist defs, eval dimensions). Present each with rationale.

## Research Mode
When `state.json.mode` is `"research"`:
- Implement step: load `evals/dimensions/research-implement.yaml`.
- Spec step: load `evals/dimensions/research-spec.yaml`.
- Phase A: verify `.furrow/rows/{name}/deliverables/` files exist, match
  `plan.json` ownership, meet acceptance criteria from definition.yaml.
- Phase B: evaluate coverage, evidence-basis, synthesis-quality,
  internal-consistency, actionability. Verify citations.
- Scan deliverables for promotion candidates to flag at archive.
- Read `references/research-mode.md` for dimension selection logic.
