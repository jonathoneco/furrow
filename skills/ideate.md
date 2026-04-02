# Step: Ideate

## What This Step Does
Explore the problem space. Produce a validated `definition.yaml` as the work contract.

## What This Step Produces
- `.work/{name}/definition.yaml` (validated against schema)

## Step-Specific Rules
Run the 6-part ceremony in order:

1. **Brainstorm** — explore dimensions of the problem. Surface at least 3 angles.
2. **Premise challenge** — apply three-layer analysis: conventional wisdom, search
   for prior art in the codebase, first-principles reasoning.
3. **Questions before research** — surface design decisions as named options
   (Option A/B/C) with a stated lean. Wait for user response in supervised mode.
   Emit `<!-- ideation:section:{name} -->` before each decision block.
4. **Cross-model outside voice** — request a cross-model review of problem framing
   and deliverables. Read `cross_model.provider` from `harness.yaml`; if absent,
   use a fresh same-model subagent. Record findings in gate evidence.
5. **Section-by-section approval** — build `definition.yaml` incrementally. Present
   each section individually: objective, each deliverable, context pointers,
   constraints, gate policy. Emit section markers before each.
6. **Hard gate** — validate definition with `scripts/validate-definition.sh`.
   Gate record required in `state.json` before advancing.

Mode adaptations:
- **Supervised**: user responds to each decision and approves each section.
- **Delegated**: agent self-answers decisions; user approves final definition.
- **Autonomous**: evaluator validates instead of human; escalates on failure.

## Shared References
Read these when relevant to your current action:
- `skills/shared/red-flags.md` — before finalizing definition
- `skills/shared/learnings-protocol.md` — when capturing learnings
- `skills/shared/git-conventions.md` — before any commit

## Step Mechanics
Transition out: gate record `ideate->research` with outcome `pass` required.
No pre-step evaluation — ideation always runs. Post-step gate evaluates
completeness, alignment, feasibility, and cross-model evidence.
Reference: `evals/gates/ideate.yaml` post_step, per `skills/shared/gate-evaluator.md`.
Next step expects: validated `definition.yaml` and initialized `state.json`.

## Learnings
When you discover a reusable insight (pattern, pitfall, preference, convention,
or dependency quirk), append it to `.work/{name}/learnings.jsonl` using the
learning schema. Read `skills/shared/learnings-protocol.md` for format.
