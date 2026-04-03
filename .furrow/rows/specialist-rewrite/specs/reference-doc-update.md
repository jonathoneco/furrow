# Spec: reference-doc-update

## What Changes

Update `references/specialist-template.md` to document the new reasoning-focused format.

## Sections to Update

**Template Format code block**: Replace old structure with:
```markdown
---
name: "{specialist-name}"
description: "{one-line domain description}"
type: specialist
---

# {Specialist Name} Specialist

## Domain Expertise
{How this specialist thinks about their domain}

## How This Specialist Reasons
{5-8 reasoning patterns as bold-name bullets}

## Quality Criteria
{Domain-specific quality expectations}

## Anti-Patterns
{Table: Pattern | Why It's Wrong | Do This Instead}

## Context Requirements
{Required + Helpful bullet lists}
```

**Frontmatter fields**: Change from `type` + `domain` to `name` + `description` + `type`.

**Remove**: "Skills" and "File Ownership" sections from the template format (these are now in plan.json assignments, not in the specialist template).

## Sections to Preserve

- **How Specialists Are Used**: Keep the two-path consumption model (solo skill invocation + multi-agent prompt seeding). Update step references if needed.
- **Naming Convention**: Keep as-is.
- **Context Budget**: Keep the "reference layer" classification and conciseness guidance.

## Acceptance Criteria (from definition.yaml)

1. Format example matches harness-engineer.md structure exactly
2. Two-path consumption model preserved and accurate
3. Context budget guidance preserved
4. Naming convention preserved
