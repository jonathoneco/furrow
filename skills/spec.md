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
- For each deliverable, produce test scenarios (WHEN/THEN + verification command)
  that supplement the ACs. Trivially testable ACs may omit scenarios.
  See `templates/spec.md` for the scenario format.
- Ensure `skills/work-context.md` is loaded.
- Read `summary.md` for plan context.

### Step-Level Specialist Modifier
When working with a specialist during spec, emphasize contract completeness,
boundary definition, and constraint enumeration over implementation pragmatism.
The specialist's reasoning patterns apply to specification decisions: what
interfaces to define, what invariants to enforce, what edge cases to address.

## Collaboration Protocol

Record decisions using `skills/shared/decision-format.md`. Don't assume — ask.

**Decision categories** for spec:
- **Acceptance criteria precision** — how specific is "enough" to implement and test
- **Edge case coverage** — which edge cases matter vs which are out of scope
- **Testability approach** — how to verify each criterion (unit, integration, manual)

**High-value question examples** (ask these, not "does this look right?"):
- "Is '{criterion}' specific enough to test, or should I tighten it to {more specific version}?"
- "Should we cover {edge case}, or is it out of scope for this work?"
- "How should we verify this — unit test, integration test, or manual check?"

Mid-step iteration is expected; `step_status` remains `in_progress` throughout.

## Agent Dispatch Metadata
- **Dispatch pattern**: Parallel agents per component (multi-deliverable)
- **Agent model**: sonnet (structured spec writing from plan decisions)
- **Context to agent**: Plan decisions for this component, definition.yaml ACs, relevant research findings, specialist template (if assigned)
- **Context excluded**: Other components' specs, plan trade-off discussions
- **Returns**: Component spec with refined ACs and test scenarios

## Shared References
Read these when relevant to your current action:
- `skills/shared/red-flags.md` — before finalizing specs
- `skills/shared/learnings-protocol.md` — when capturing learnings
- `skills/shared/context-isolation.md` — when dispatching spec sub-agents
- `skills/shared/summary-protocol.md` — before completing step
- `skills/shared/specialist-delegation.md` — specialist selection and delegation protocol

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

## Dual-Reviewer Protocol
Before requesting transition, run both reviewers in parallel:
1. **Fresh Claude reviewer** — `claude -p --bare` with spec artifacts,
   definition.yaml ACs, and `evals/dimensions/spec.yaml` dimensions.
   Specialist template included if specialist was delegated during this step.
   Receives: spec.md or specs/ directory, definition.yaml.
   Excludes: summary.md, conversation history, state.json.
2. **Cross-model reviewer** — `frw cross-model-review {name} --spec`
   if `cross_model.provider` configured in `furrow.yaml`. Skip if absent.
Synthesize findings: flag disagreements, note unique findings, record
both sources in gate evidence. Address or explicitly reject all findings
before requesting transition.

## Supervised Transition Protocol
Before requesting a step transition:
1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
2. Present work to user per `skills/shared/summary-protocol.md`.
3. Ask explicitly: "**Ready to advance to decompose?** Yes / No"
4. Wait for user response. Do NOT proceed without explicit approval.
5. On "yes": call `rws transition <name> pass manual "<evidence summary>"`.
6. On "no": ask what needs to change, address feedback, return to step 2.

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
