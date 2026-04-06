# Spec: consumer-wiring

## Interface Contract

Three step skills gain instructions for reading and applying model hints when spawning sub-agents.

### implement.md
Add model routing instruction after the existing multi-agent dispatch path (lines 21-26).
Text explains: read `model_hint` from specialist frontmatter, pass as `model` parameter
to Agent tool. Fall back to step `model_default`, then project default (sonnet).

### decompose.md
Add model routing instruction at specialist resolution point (line 28).
Text explains: when resolving specialist templates, read `model_hint` and include it
in team-plan.md task assignment so implement step doesn't need to re-resolve.

### review.md
Add model routing instruction at reviewer dispatch point (line 25).
Text explains: when spawning reviewer agents, read specialist `model_hint` and pass
as `model` parameter. Note that review step defaults to opus.

## Acceptance Criteria (Refined)

- implement.md contains instruction to read `model_hint` and pass as Agent tool `model` parameter
- implement.md documents fallback chain: specialist > step > project default (sonnet)
- decompose.md contains instruction to propagate `model_hint` into team-plan.md task assignments
- review.md contains instruction to read `model_hint` when spawning reviewer agents
- All three files document the resolution order: specialist > step > project default
- No existing instructions are removed — additions only
- Each step skill file remains within the 50-line context budget

## Implementation Notes

- Additions are small (2-4 lines per file) — minimal budget impact
- Wording should be imperative and concise, matching existing step skill voice
- Resolution order must be stated consistently across all three files

## Dependencies

- specialist-model-hints (D1) — frontmatter field must exist to reference
- step-model-defaults (D2) — model_default section must exist to reference
