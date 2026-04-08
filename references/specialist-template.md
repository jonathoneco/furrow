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
model_hint: sonnet  # valid: sonnet | opus | haiku
---

# {Specialist Name} Specialist

## Domain Expertise
{How this specialist thinks about their domain — 1-2 paragraphs}

## How This Specialist Reasons
{5-8 reasoning patterns as bold-name bullets with 2-4 sentences each}

## When NOT to Use
{At least one scenario where this specialist is the wrong choice, naming
the better alternative (another specialist or no specialist).}

## Overlap Boundaries
{When this specialist shares domain surface with another, declare the boundary.
Name the sibling specialist and state what belongs where. Omit if no overlap.}

## Quality Criteria
{Domain-specific quality expectations — prose paragraph}

## Anti-Patterns
{Table: Pattern | Why It's Wrong | Do This Instead}

## Context Requirements
{Required + Helpful bullet lists}
```

## Normative Requirements

### Project Grounding

Every specialist MUST contain at least one reasoning pattern or anti-pattern
that references a concrete project convention, file path, tool, or workflow.
Generic domain knowledge alone is insufficient — the specialist must encode
decisions specific to this project's context so the agent behaves differently
than it would with no specialist loaded.

Exception: language specialists (e.g., python-specialist, typescript-specialist)
that exist for general reuse across projects are exempt from the project-grounding
requirement. They must still pass the encoded reasoning test below.

### Encoded Reasoning vs. Restated Best Practice

A reasoning pattern is **encoded reasoning** if it meets ALL of:
- It encodes a decision the model would not make by default
- It references a specific tradeoff, threshold, or heuristic ("prefer X over Y
  when Z", not "consider X")
- Removing it from the specialist would change the agent's output on a task

A reasoning pattern is **restated best practice** if ANY of:
- It restates general domain knowledge the model already has (e.g., "quote
  shell variables", "use parameterized queries", "prefer composition over
  inheritance")
- It uses vague language without actionable specifics
- The model would follow the same advice without the specialist loaded

**Litmus test**: Ask "would Claude follow this advice anyway without the
specialist?" If yes, it is restated best practice — rewrite or remove it.

### Anti-Pattern Minimum

Every specialist must have at least 3 rows in the anti-pattern table. At least
1 row must be project-specific (referencing a Furrow convention, tool, or file
path) unless the specialist is a general-purpose language specialist.

### When NOT to Use

Every specialist must declare at least one scenario where it is the wrong
choice, naming the better alternative (another specialist or no specialist).

### Overlap Boundaries

When two specialists share domain surface, each must declare its boundary in
an "Overlap Boundaries" section. The section names the sibling and states what
belongs where. This prevents duplicate or contradictory guidance.

### model_hint Rationale

- `opus`: Multi-step reasoning across large contexts, novel problem-solving,
  cross-component architectural decisions
- `sonnet`: Well-scoped execution within established patterns, single-domain work
- `haiku`: Reserved for trivial boilerplate tasks (currently no specialists qualify)

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

## Size Budget

Specialist templates must not exceed 80 lines (including frontmatter).
They are read on demand (reference layer) and NOT counted against the
300-line injected budget.
