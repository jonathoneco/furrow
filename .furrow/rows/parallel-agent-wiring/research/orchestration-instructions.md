# Research: orchestration-instructions

## Current State

The implement step has two-path dispatch: solo (specialist loaded as skill) vs multi-agent
(specialist template injected into Agent prompt). The decision between them is **discretionary**
— no threshold or decision tree exists.

**What exists:**
- plan.json structure: `waves[].assignments.{deliverable}.{specialist, file_ownership, skills}`
- Wave ordering via BFS topological sort in generate-plan.sh
- Specialist templates with YAML frontmatter (name, description, type, model_hint) and
  Context Requirements sections (Required/Helpful/Exclude)
- Context isolation rules: sub-agents get task text, curated context, file_ownership scope;
  excluded from session history, other agents' WIP, state.json
- Wave validation: contiguity, dependency ordering, no file_ownership overlap within waves

**What's missing (5 gaps):**
1. No explicit dispatch threshold — when must orchestrator dispatch vs. work solo?
2. No Agent tool call example — "include in prompt" is abstract
3. No wave inspection protocol — what to check between waves?
4. Skills array in plan.json is never populated — purpose unclear
5. Between-wave curation protocol is vague — "lead curates" with no criteria

## Implementation Implications

The instruction rewrite needs:
- Decision tree: if plan.json has >1 wave OR >1 deliverable in a wave with different specialists → dispatch
- Concrete Agent() call with specialist template content, file_ownership scope, context pointers
- Wave inspection checklist: verify deliverable files exist, run tests, check for conflicts
- Curation protocol: read changed files from wave N, summarize for wave N+1 agents

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| skills/implement.md (lines 1-91) | Primary | Current dispatch instructions |
| skills/decompose.md (lines 1-77) | Primary | plan.json structure, team sizing |
| skills/shared/context-isolation.md (lines 1-75) | Primary | Sub-agent context rules |
| bin/frw.d/scripts/generate-plan.sh (lines 1-220) | Primary | Wave ordering algorithm |
| bin/frw.d/lib/validate.sh (lines 141-222) | Primary | Wave conflict validation |
| templates/plan.json | Primary | plan.json schema |
| specialists/python-specialist.md, test-engineer.md, api-designer.md | Primary | Template format |
