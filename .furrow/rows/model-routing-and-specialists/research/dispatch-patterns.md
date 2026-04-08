# Implement.md Dispatch Patterns — Deep Dive

## Sources Consulted
- skills/implement.md (primary) — full read
- skills/shared/context-isolation.md (primary) — full read
- skills/decompose.md (primary) — full read
- schemas/plan.schema.json (primary) — schema definition
- references/specialist-template.md (primary) — template structure

## The Dispatch Protocol

### plan.json-Driven Orchestration
Source of truth: `plan.json` produced by decompose step.
```json
{
  "waves": [{
    "wave": 1,
    "deliverables": ["d1", "d2"],
    "assignments": {
      "d1": { "specialist": "type", "file_ownership": ["glob"], "skills": [] }
    }
  }]
}
```

### Agent Tool Parameters
- `model`: Resolved from 3-tier hierarchy (specialist hint → step default → sonnet)
- `prompt`: Specialist template content + curated context + file ownership + acceptance criteria

### Blocking Validation
Before ANY agent dispatch, validate every specialist referenced in plan.json exists in `specialists/`. STOP if missing. Non-negotiable.

## Context Flow: What Agents Receive

### Included
1. Full task text (complete deliverable spec, not pointers)
2. Curated context (files/symbols selected per specialist's Context Requirements)
3. Specialist template content (full text)
4. Definition.yaml acceptance criteria
5. File ownership globs (from plan.json)

### Excluded
- Full session history from lead agent
- Other sub-agents' WIP (until wave completes)
- Raw research (summary.md instead)
- Other deliverables' review results
- state.json

### Curation Protocol
Lead reads specialist's Context Requirements section:
- Includes Required items always
- Selectively includes Helpful items
- NEVER includes Exclude items
- Anti-pattern: "Never pass the lead agent's full conversation to a sub-agent"

## Wave Execution Model

1. Wave N launches: all deliverables dispatch concurrently (file_ownership non-overlapping)
2. Wave N completes: lead inspects all outputs
3. Between-wave gate: lead decides proceed or escalate
4. Wave N+1 launches: with wave N outputs available as curated context

## Error Handling

- No automatic re-dispatch from plan.json
- Review Phase A/B catches failures → return to implement with feedback
- In-session corrections (not new dispatch)
- Correction counter increments in state.json
- Correction limit (hook-enforced) prevents spiral — pauses for human input

## Model Routing: 3-Tier Resolution

```
1. Specialist model_hint (from specialists/{name}.md frontmatter)
2. Step model_default (from step skill)
3. Project default (sonnet)
```

Lead reads model_hint, explicitly passes resolved model to Agent tool's `model` parameter.
Hints are guidance — lead may override if task complexity warrants.

## Architectural Principles

1. **Curation > Copying**: curate context per specialist, never dump conversation
2. **Specialist as Identity**: template becomes agent's reasoning framework
3. **Wave as Concurrency Unit**: parallelism explicit in plan.json
4. **Inspection Gates**: sequential wave boundaries with output review
5. **Schema-Driven Handoff**: decompose→implement via plan.json contract
6. **Correction Limits**: preventive spiral prevention, not reactive monitoring
7. **File Ownership as Boundary**: specialists write only within their globs

## Generalizing for the Orchestrator Skill

The implement.md pattern is the template. The orchestrator skill generalizes it:
- Replace plan.json-driven dispatch with step-appropriate dispatch triggers
- Keep curation protocol (specialist Context Requirements)
- Keep model routing (3-tier resolution)
- Keep wave semantics for multi-deliverable work
- Add multi-round collaborate/execute within non-implement steps
- Add the collaboration protocol between dispatch rounds
