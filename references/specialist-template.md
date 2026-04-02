# Specialist Template

## Overview

Specialists are reasoning-focused domain experts assigned to deliverables. Each
specialist template defines how the agent thinks about its domain — reasoning
patterns, quality criteria, and anti-patterns — rather than listing skills or
file ownership (which are now managed in `plan.json` assignments).

## Template Format

Specialist definitions live in `specialists/{name}.md`:

```markdown
---
name: "{specialist-name}"
description: "{one-line domain description}"
type: specialist
---

# {Specialist Name} Specialist

## Domain Expertise
{How this specialist thinks about their domain — 1-2 paragraphs}

## How This Specialist Reasons
{5-8 reasoning patterns as bold-name bullets with 2-4 sentences each}

## Quality Criteria
{Domain-specific quality expectations — prose paragraph}

## Anti-Patterns
{Table: Pattern | Why It's Wrong | Do This Instead}

## Context Requirements
{Required + Helpful bullet lists}
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
