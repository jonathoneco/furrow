# Step: Ideate

## What This Step Does
Explore the problem space. Produce a validated `definition.yaml` as the work contract.

## What This Step Produces
- `.furrow/rows/{name}/definition.yaml` (validated against schema)

## Model Default
model_default: sonnet

## Step-Specific Rules
Run the 6-part ceremony in order:

1. **Brainstorm** — explore dimensions of the problem. Surface at least 3 angles.
   When naming the row, choose an **outcome-oriented** name (max 40 chars):
   - Single focus: verb-noun (`add-rate-limiting`, `fix-timestamp-drift`)
   - Bundles: noun-and-noun (`guards-and-source-hierarchy`, `hooks-and-naming`)
   - Good: `isolated-gate-evaluation`, `default-supervised-gating`, `namespace-rename`
   - Bad: `research-e2e`, `todos-workflow`, `roadmap-process` (too vague)
2. **Premise challenge** — apply three-layer analysis: conventional wisdom, search
   for prior art in the codebase, first-principles reasoning.
3. **Questions before research** — surface design decisions as named options
   (Option A/B/C) with a stated lean. Wait for user response in supervised mode.
   Emit `<!-- ideation:section:{name} -->` before each decision block.
4. **Dual outside voice** — run both reviewers in parallel:
   a. Fresh same-model subagent (isolated context) for problem framing review.
   b. Cross-model review via `frw cross-model-review <name> --ideation` if `cross_model.provider`
      is configured in `furrow.yaml`. If absent, skip cross-model.
   Synthesize findings from both. Record in gate evidence.
5. **Section-by-section approval** — build `definition.yaml` incrementally. Present
   each section individually: objective, each deliverable, context pointers,
   constraints, gate policy. Emit section markers before each.
   If `state.json` has a non-null `source_todo`, include it in `definition.yaml`.
   If `state.json` has a non-null `gate_policy_init`, use it as the default for
   `gate_policy` in `definition.yaml` (user can override during approval).
6. **Hard gate** — validate definition with `frw validate-definition`.
   Gate record required in `state.json` before advancing.

Mode adaptations:
- **Supervised**: user responds to each decision and approves each section.
- **Delegated**: agent self-answers decisions; user approves final definition.
- **Autonomous**: evaluator validates instead of human; escalates on failure.

## Collaboration Protocol

Record decisions using `skills/shared/decision-format.md`. Don't assume — ask.

**Decision categories** for ideation:
- **Scope boundaries** — what's in vs out of this work
- **Success criteria** — what "done" looks like concretely
- **Constraint priorities** — which constraints are hard vs soft/negotiable

**High-value question examples** (ask these, not "does this look right?"):
- "I see two framings — {X} (scope-limited) and {Y} (scope-expanded). Which aligns with your intent?"
- "Is {constraint} a hard requirement or negotiable if it conflicts with {goal}?"
- "What does 'done' look like — {concrete outcome A} or {concrete outcome B}?"

Mid-step iteration is expected; `step_status` remains `in_progress` throughout.

## Agent Dispatch Metadata
- **Dispatch pattern**: Optional — fresh reviewer subagent for dual outside voice
- **Agent model**: sonnet (reviewer is structured evaluation, not novel reasoning)
- **Context to agent**: Problem framing summary, definition.yaml draft, review dimensions
- **Context excluded**: Full 6-part ceremony conversation, user decision history
- **Returns**: Structured review findings for orchestrator synthesis

## Shared References
Read these when relevant to your current action:
- `skills/shared/red-flags.md` — before finalizing definition
- `skills/shared/learnings-protocol.md` — when capturing learnings
- `skills/shared/git-conventions.md` — before any commit
- `skills/shared/summary-protocol.md` — Open Questions only at this step
- `skills/shared/specialist-delegation.md` — specialist selection and delegation protocol

## Step Mechanics
Transition out: gate record `ideate->research` with outcome `pass` required.
No pre-step evaluation — ideation always runs. Post-step gate evaluates
completeness, alignment, feasibility, and cross-model evidence.
Reference: `evals/gates/ideate.yaml` post_step, per `skills/shared/gate-evaluator.md`.
Next step expects: validated `definition.yaml` and initialized `state.json`.

## Supervised Transition Protocol
Before requesting a step transition:
1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
2. Present work to user per `skills/shared/summary-protocol.md`.
3. Ask explicitly: "**Ready to advance to research?** Yes / No"
4. Wait for user response. Do NOT proceed without explicit approval.
5. On "yes": call `rws transition <name> pass manual "<evidence summary>"`.
6. On "no": ask what needs to change, address feedback, return to step 2.

## Learnings
When you discover a reusable insight (pattern, pitfall, preference, convention,
or dependency quirk), append it to `.furrow/rows/{name}/learnings.jsonl` using the
learning schema. Read `skills/shared/learnings-protocol.md` for format.
