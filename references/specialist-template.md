# Specialist Template

## Overview

Specialists are domain-expert agents assigned to deliverables. Each specialist
type has a template that defines its context, skills, and constraints.

## Template Format

Specialist definitions live in `specialists/{type}.md`:

```markdown
---
type: "{specialist-type}"
domain: "{domain description}"
---

# {Specialist Type}

## Domain Expertise
{What this specialist knows and can do}

## Skills
{Skills to inject via Read instructions}
- `skills/work-context.md` (always)
- `skills/{current-step}.md` (always)
- Additional domain-specific skills

## File Ownership
{Default file ownership patterns, overridable per deliverable}

## Quality Standards
{Domain-specific quality expectations}

## Anti-Patterns
{Common mistakes this specialist should avoid}
```

## How Specialists Are Used

1. `definition.yaml` assigns a specialist type per deliverable (required field).
2. `decompose` step maps specialists to waves in `plan.json`.
3. `implement` step loads the specialist via one of two paths:
   - **Solo work**: invoke the specialist as a skill (Skill tool) to load
     domain framing into the current agent's context.
   - **Multi-agent**: include the specialist template content in the Agent
     tool's `prompt` parameter when dispatching a subagent. The specialist
     framing becomes the subagent's identity from creation.
4. In both paths, the agent also receives:
   - The deliverable's acceptance criteria from `definition.yaml`
   - The component spec from `specs/{deliverable}.md`
   - File ownership constraints from `plan.json`
5. Specialist works within its file ownership boundaries.
6. `review` step evaluates the specialist's output.

## Naming Convention

Specialist types use kebab-case: `api-designer`, `auth-specialist`,
`database-architect`, `test-engineer`, `docs-writer`.

The name primes the agent's behavior. Choose names that match the domain
expertise needed, not generic process roles.

## Context Budget

Specialist templates are read on demand (reference layer). They are NOT counted
against the 300-line injected budget. Keep templates concise but complete
enough for the agent to operate independently.
