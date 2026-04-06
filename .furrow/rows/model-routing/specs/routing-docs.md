# Spec: routing-docs

## Interface Contract

`skills/shared/context-isolation.md` gains a new `## Model Resolution` section documenting
the two-tier model routing system.

**Placement:** After `## Context Curation Using Specialist Templates`, before `## Wave Isolation`.

**Content covers:**
1. Resolution order: specialist `model_hint` > step `model_default` > project default (sonnet)
2. Hints-not-enforcement posture: lead agent reads hints but makes final dispatch decision
3. Allowlist: sonnet | opus | haiku
4. How to pass: use Agent tool `model` parameter

## Acceptance Criteria (Refined)

- context-isolation.md contains `## Model Resolution` section
- Section documents resolution order: specialist > step > project default
- Section states hints-not-enforcement posture
- Section lists allowlist values: sonnet, opus, haiku
- Section references Agent tool `model` parameter as the dispatch mechanism
- Section is placed after Context Curation and before Wave Isolation
- No existing content in context-isolation.md is removed

## Implementation Notes

- Section should be 8-12 lines — concise, matching existing section voice
- Use the same list/paragraph style as adjacent sections
- Reference specialist frontmatter `model_hint` field and step skill `model_default` section by name

## Dependencies

- consumer-wiring (D3) — routing instructions must exist before documenting them
