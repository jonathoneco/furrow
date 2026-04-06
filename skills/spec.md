# Step: Spec

## What This Step Does
Define exactly what should be built in enough detail to implement.

## What This Step Produces
- `spec.md` (single deliverable) or `specs/` directory (multiple components).
  Use `templates/spec.md` as the schema reference for spec structure.
- Refined acceptance criteria per deliverable
- Code mode: component specifications; Research mode: knowledge artifact structure

## Model Default
model_default: sonnet

## Step-Specific Rules
- Every acceptance criterion from `definition.yaml` must be addressed.
- Specs must be implementation-ready — no ambiguous requirements.
- Ensure `skills/work-context.md` is loaded.
- Read `summary.md` for plan context.

## Shared References
Read these when relevant to your current action:
- `skills/shared/red-flags.md` — before finalizing specs
- `skills/shared/learnings-protocol.md` — when capturing learnings
- `skills/shared/context-isolation.md` — when dispatching spec sub-agents
- `skills/shared/summary-protocol.md` — before completing step

## Team Planning
For multi-deliverable work, dispatch spec sub-agents per component. Read `skills/shared/context-isolation.md`.

## Step Mechanics
Transition out: gate record `spec->decompose` with outcome `pass` required.
Pre-step shell check (`rws gate-check`): 1 deliverable, >=2 ACs, not supervised,
not force-stopped.
Pre-step evaluator (`evals/gates/spec.yaml`): testability — are ACs specific enough
to implement without refinement? Per `skills/shared/gate-evaluator.md`.
Next step expects: implementation-ready specs in `spec.md` or `specs/` with
refined acceptance criteria per deliverable.

## Supervised Transition Protocol
Before requesting a step transition:
1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
2. Present work to user per `skills/shared/summary-protocol.md`.
3. Ask explicitly: "**Ready to advance to decompose?** Yes / No"
4. Wait for user response. Do NOT proceed without explicit approval.
5. On "yes": call `rws transition --request` with `decided_by=manual`.
6. After --request succeeds: call `rws transition --confirm`.
7. On "no": ask what needs to change, address feedback, return to step 2.

## Learnings
When you discover a reusable insight (pattern, pitfall, preference, convention,
or dependency quirk), append it to `.furrow/rows/{name}/learnings.jsonl` using the
learning schema. Read `skills/shared/learnings-protocol.md` for format.

## Research Mode
When `state.json.mode` is `"research"`:
- Produce a knowledge artifact outline (not component specifications).
- Per-section outline includes: guiding question, required sub-topics,
  required evidence types (primary/secondary/quantitative/qualitative),
  minimum source count, and format (report/synthesis/recommendation/comparison).
- Define cross-section consistency requirements.
- Refine acceptance criteria into testable conditions with measurable
  thresholds (counts, presence checks, citation requirements).
- Avoid subjective language ("thorough", "comprehensive") without thresholds.
- Review with `evals/dimensions/research-spec.yaml` dimensions.
- Read `references/research-mode.md` for deliverable formats.
