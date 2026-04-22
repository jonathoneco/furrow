# Step: Plan

## What This Step Does
Synthesize research into architecture decisions and execution strategy.

## What This Step Produces
- Architecture decisions recorded in `summary.md`
- `plan.json` if parallel execution is needed (multiple deliverables).
  Use `templates/plan.json` as the schema reference for plan.json structure.
- `team-plan.md` if agent teams will be used

## Model Default
model_default: sonnet

## Step-Specific Rules
- Every deliverable from `definition.yaml` must have a clear implementation path.
- Architecture decisions must reference research findings, not assumptions.
- Ensure `skills/work-context.md` is loaded.
- Read `summary.md` for research context.
- CC plan mode (EnterPlanMode) may be used to explore the codebase and get
  clarity from the user for this step's decisions. It must not produce artifacts
  that span or replace the spec, decompose, or implement steps.

## Collaboration Protocol

Record decisions using `skills/shared/decision-format.md`. Don't assume — ask.

**Decision categories** for planning:
- **Architecture trade-offs** — simplicity vs extensibility, performance vs maintainability
- **Dependency ordering** — what blocks what and why
- **Risk tolerance** — acceptable failure modes and mitigation level

**High-value question examples** (ask these, not "does this look right?"):
- "This trades simplicity for extensibility. Given the project scope, which do you prefer?"
- "I see two dependency orders — {A then B} or {B then A}. Any reason to prefer one?"
- "This approach has {risk}. Is that acceptable, or should we add mitigation?"

Mid-step iteration is expected; `step_status` remains `in_progress` throughout.

### Step-Level Specialist Modifier
When working with a specialist during planning, emphasize architectural framing
over implementation detail. The specialist should reason about component boundaries,
dependency direction, and trade-off analysis. Prefer options analysis (A vs B
with trade-offs stated) over prescriptive solutions. The specialist's domain
expertise applies to architecture decisions: what interfaces exist, what coupling
to accept, what patterns to follow.

## Agent Dispatch Metadata
- **Dispatch pattern**: Optional — codebase exploration agent for architecture investigation
- **Agent model**: sonnet (structured codebase reading, not architectural reasoning)
- **Context to agent**: Exploration question, file/symbol targets, research findings summary
- **Context excluded**: Trade-off discussions, risk tolerance decisions
- **Returns**: Codebase findings (file structures, patterns, dependencies)

## Shared References
Read these when relevant to your current action:
- `skills/shared/red-flags.md` — before finalizing plan
- `skills/shared/learnings-protocol.md` — when capturing learnings
- `skills/shared/summary-protocol.md` — before completing step
- `skills/shared/specialist-delegation.md` — specialist selection and delegation protocol

## Team Planning
When `plan.json` has multiple deliverables, create `team-plan.md` with specialist
assignments per deliverable. Read `references/specialist-template.md` for format.
Assign `file_ownership` globs to prevent cross-specialist conflicts in waves.

## Research Mode
When `state.json.mode` is `"research"`:
- Define knowledge artifact structure: sections, sub-topics, evidence requirements.
- `file_ownership` targets `.furrow/rows/{name}/deliverables/` paths, not git tree globs.
- No parallel waves needed — research deliverables are authored sequentially or by section.
- Specialist assignment uses research roles (domain-researcher, synthesis-writer).
- Read `references/research-mode.md` for artifact formats.

## Step Mechanics
Transition out: gate record `plan->spec` with outcome `pass` required.
Pre-step shell check (`rws gate-check`): 1 deliverable, no depends_on, not
supervised, not force-stopped.
Pre-step evaluator (`evals/gates/plan.yaml`): complexity-assessment — does the
deliverable need architectural decisions beyond definition.yaml? Per `skills/shared/gate-evaluator.md`.
Next step expects: architecture decisions in `summary.md`, `plan.json` if
parallel execution needed, and clear implementation path per deliverable.

## Dual-Reviewer Protocol
Before requesting transition, run both reviewers in parallel:
1. **Fresh Claude reviewer** — `claude -p --bare` with plan artifacts,
   definition.yaml ACs, and `evals/dimensions/plan.yaml` dimensions.
   Specialist template included if specialist was delegated during this step.
   Receives: plan.json, team-plan.md (if exists), definition.yaml.
   Excludes: summary.md, conversation history, state.json.
2. **Cross-model reviewer** — `frw cross-model-review {name} --plan`
   if `cross_model.provider` configured in `furrow.yaml`. Skip if absent.
Synthesize findings: flag disagreements, note unique findings, record
both sources in gate evidence. Address or explicitly reject all findings
before requesting transition.

## Supervised Transition Protocol
Before requesting a step transition:
1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
2. Present work to user per `skills/shared/summary-protocol.md`.
3. Ask explicitly: "**Ready to advance to spec?** Yes / No"
4. Wait for user response. Do NOT proceed without explicit approval.
5. On "yes": call `rws transition <name> pass manual "<evidence summary>"`.
6. On "no": ask what needs to change, address feedback, return to step 2.

## Learnings
When you discover a reusable insight (pattern, pitfall, preference, convention,
or dependency quirk), append it to `.furrow/rows/{name}/learnings.jsonl` using the
learning schema. Read `skills/shared/learnings-protocol.md` for format.
