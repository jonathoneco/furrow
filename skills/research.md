# Step: Research

## What This Step Does
Investigate prior art, architecture options, and constraints identified during ideation.

## What This Step Produces
- `research.md` (single-agent) or `research/` directory with per-topic files + `synthesis.md`
- Updated `summary.md` with key findings

## Step-Specific Rules
- All questions from ideation must be addressed or explicitly deferred.
- Research must reference `definition.yaml` deliverables by name.
- Ensure `skills/work-context.md` is loaded.
- Read `summary.md` for ideation context (do not re-read raw definition discussions).

## Shared References
Read these when relevant to your current action:
- `skills/shared/red-flags.md` — before concluding research
- `skills/shared/learnings-protocol.md` — when capturing learnings
- `skills/shared/context-isolation.md` — when dispatching research sub-agents

## Team Planning
When definition has multiple deliverables or >3 research questions, dispatch
parallel sub-agents per topic. Read `skills/shared/context-isolation.md`.

## Step Mechanics
Transition out: gate record `research->plan` with outcome `pass` required.
Pre-step shell check (`gate-precheck.sh`): 1 deliverable, code mode, path-referencing
ACs, no directory context pointers, not supervised, not force-stopped.
Pre-step evaluator (`evals/gates/research.yaml`): path-relevance — are referenced
paths sufficient without broader investigation? Per `skills/shared/gate-evaluator.md`.
Next step expects: research findings addressing all ideation questions, recorded
in `research.md` or `research/` directory with `synthesis.md`.

## Learnings
When you discover a reusable insight (pattern, pitfall, preference, convention,
or dependency quirk), append it to `.work/{name}/learnings.jsonl` using the
learning schema. Read `skills/shared/learnings-protocol.md` for format.

## Research Mode
When `state.json.mode` is `"research"`: produce knowledge artifacts, not code
analysis. Every finding requires source citation. Multi-source triangulation
for claims. Read `references/research-mode.md` for deliverable formats.
