# Research: enforcement-wiring

## Problem

`skills/implement.md` describes two specialist consumption paths (solo skill
loading and multi-agent prompt injection) but doesn't require them. The
instruction is guidance, not enforcement. An agent can dispatch without loading
the assigned specialist template.

## Current State (skills/implement.md)

Lines 25-33 describe specialist loading:
- Solo work: invoke the specialist as a skill
- Multi-agent: include specialist template content in Agent tool's prompt
- Read specialist's model_hint from frontmatter for the model parameter

This is advisory — no "MUST" language, no validation step, no hard stop.

## plan.json Specialist Assignment

During the decompose step, `plan.json` assigns a specialist type to each
deliverable. Example from prior rows:

```json
{
  "deliverables": [{
    "name": "vertical-slice-guardrails",
    "specialist": "harness-engineer",
    "files": ["skills/shared/red-flags.md", ...]
  }]
}
```

The specialist field references a file in `specialists/`. No validation
that the file exists.

## Fix: Three Changes

### 1. Hard requirement in skills/implement.md

Add mandatory language before the dispatch section:
- "Before dispatching any agent for a deliverable, you MUST load the
  specialist template from specialists/{specialist}.md as assigned in
  plan.json. If the file does not exist, STOP and surface the error.
  This is a blocking requirement, not guidance."

### 2. plan.json validation

During decompose (or pre-implement), validate that each deliverable's
specialist field references an existing file in specialists/.

### 3. Step-level specialist modifiers

Add to skills/spec.md, skills/implement.md, and skills/review.md:
- Spec: "When working with a specialist, emphasize contract completeness,
  boundary definition, and constraint enumeration over implementation
  pragmatism."
- Implement: "When working with a specialist, emphasize incremental
  correctness, testability, and adherence to the spec over exploratory
  design."
- Review: "When working with a specialist, emphasize acceptance criteria
  verification, anti-pattern detection per the specialist's table, and
  quality dimension coverage."

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `skills/implement.md` lines 25-33 (source code) | Primary | Current advisory specialist loading instructions |
| `references/specialist-template.md` (source code) | Primary | Template standard documenting consumption paths |
| Prior `plan.json` files in archived rows (source code) | Primary | Specialist assignment structure in practice |
| Cross-model review (conversation) | Primary | Identified enforcement as highest-leverage fix |
