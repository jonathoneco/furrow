# Skill Injection Order

> **Note**: `skills/code-quality.md` is a globally-installed skill provided by the
> harness installer. It is NOT part of the V2 harness package itself.

Reference for the order in which skills are loaded into sub-agent prompts.

## Loading Order

When constructing a sub-agent prompt, skill Read instructions must appear in this order:

1. **Universal skills** — `code-quality` is always first for implementation and review agents.
2. **Specialist-declared skills** — listed in the specialist template's `skills` frontmatter field, in the order declared.
3. **Step-specific skill** — the current step's skill file (e.g., `skills/implement.md`).
4. **Task-specific skills** — any additional skills listed in `plan.json` assignments for this deliverable.

## Why Order Matters

Skills listed first take precedence on conflicting instructions. By loading `code-quality` first, its universal rules (fail closed, never swallow errors, etc.) cannot be overridden by downstream specialist or step instructions.

## Injection Pattern

Skills are propagated via explicit Read instructions in prompts:

```
Read and follow the instructions in `skills/code-quality.md` before proceeding.
Read and follow the instructions in `skills/{specialist-skill}.md` before proceeding.
Read and follow the instructions in `skills/{step}.md` before proceeding.
```

## Automatic Injection Rules

| Agent Type | Always Receives | Conditional |
|-----------|----------------|-------------|
| Implementation sub-agent | `code-quality` | Specialist-declared skills, step skill |
| Review sub-agent | `code-quality` | Specialist-declared skills, step skill |
| Research sub-agent | (none universal) | Specialist-declared skills, step skill |
| Coordinator | `work-context` | Step skill |

## Validation

Before dispatching a sub-agent, verify:
- Every skill path in the injection list resolves to an existing file.
- No duplicate skill entries (a skill should not be injected twice).
- The specialist template's `skills` field entries exist in `skills/` directory.
