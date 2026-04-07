# Step: Review

## What This Step Does
Evaluate implementation against spec and audit plan completion.

## What This Step Produces
- `reviews/{deliverable}.json` per deliverable (Phase A + Phase B results)
- Gate record in `state.json` with overall verdict

## Model Default
model_default: opus

## Step-Specific Rules
- **Phase A** (in-session): verify artifacts exist, acceptance criteria met, planned files touched.
  Deterministic shell checks — runs in the current session.
- **Phase B** (fresh-session): evaluate quality dimensions per artifact type.
  Runs via `claude -p --bare` as an isolated process with no conversation context.
  See `commands/review.md` for the invocation protocol.
- `overall` is `pass` only when both phases pass.
- Read `references/review-methodology.md` and `references/eval-dimensions.md`.

### Step-Level Specialist Modifier
When working with a specialist during review, emphasize acceptance criteria
verification, anti-pattern detection per the specialist's table, and quality
dimension coverage. The specialist's reasoning patterns apply to review
judgments: what to check, what constitutes a violation, what quality bar to hold.

## Shared References
- `skills/shared/red-flags.md` — before any verdict
- `skills/shared/eval-protocol.md` — evaluator guidelines
- `skills/shared/git-conventions.md` — when reviewing commit quality
- `skills/shared/learnings-protocol.md` — when capturing learnings
- `skills/shared/context-isolation.md` — when dispatching review sub-agents
- `skills/shared/summary-protocol.md` — before completing step

## Dual-Reviewer Protocol
Every review runs **two independent reviewers in parallel**:
1. **Fresh Claude reviewer** — `claude -p --bare` for generator-evaluator separation.
   Receives ONLY the review prompt template + artifact paths + eval dimensions.
   Does NOT receive: `summary.md`, `state.json`, conversation history, or CLAUDE.md.
2. **Cross-model reviewer** — run `frw cross-model-review {name} {deliverable}`.
   Reads `cross_model.provider` from `furrow.yaml`. If no provider configured, skip.

Both reviewers evaluate the same deliverable against the same dimensions.
After both complete, **synthesize** — flag any dimension where reviewers disagree,
note unique findings from each, and produce the final `reviews/{deliverable}.json`
with a `reviewers` field recording both sources.

Agent tool subagents (used for gate evaluations) are isolated from conversation
history but inherit system context — adequate for gates, not for final review.
See `skills/shared/gate-evaluator.md` Isolation Verification section.

## Team Planning
For multi-deliverable work, Phase B runs one `claude -p` invocation per deliverable.
Each invocation is fully independent — no shared state between deliverable reviews.

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

### Consent Isolation
Each question requiring user input is an independent decision — a "yes" to
one question does NOT carry over to subsequent questions. Archive approval,
TODO extraction, learning promotion, and any other user-facing decisions are
separate consent gates. Do not interpret prior user responses as approval for
unrelated subsequent decisions (e.g., "yes to archive" does not mean "yes to
skip TODOs" or "yes to promote learnings").

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
