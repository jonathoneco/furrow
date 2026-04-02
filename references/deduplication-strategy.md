# Deduplication Strategy

## Problem

V1's context hierarchy had 879 lines with approximately 24% duplication. The same
instructions appeared in CLAUDE.md, rules files, skill files, and command files.
This wasted context budget and created maintenance burden when instructions changed.

## Rule

Each instruction appears in exactly ONE layer. No exceptions.

## Priority Order

When deciding where an instruction belongs:

1. **Ambient** (CLAUDE.md + rules/) — if the instruction is always needed regardless
   of work state. Examples: commit conventions, file naming, active task detection.

2. **Work** (skills/work-context.md) — if the instruction is needed during active work
   but not otherwise. Examples: step sequence, state conventions, command entry points.

3. **Step** (skills/{step}.md) — if the instruction is needed only during one step.
   Examples: ideation ceremony, review Phase A/B procedures.

4. **Reference** (references/*.md) — if the instruction is needed on demand only.
   Examples: gate protocol details, eval dimensions, specialist templates.

## Checklist for Adding New Instructions

Before adding any instruction to any layer:

1. Search all layers for existing coverage of this topic.
2. If covered elsewhere, do NOT add — reference the existing location.
3. If the instruction exists but in the wrong layer, MOVE it (do not duplicate).
4. Choose the layer using the priority order above.
5. Run `scripts/measure-context.sh` to verify budgets after the change.

## Common Duplication Sources (from V1)

| Duplicated Content | Was In | Should Be In |
|-------------------|--------|-------------|
| Step sequence list | CLAUDE.md, rules, skills | Work layer only |
| File path conventions | CLAUDE.md, skills, commands | Work layer only |
| Gate protocol details | Rules, skills, commands | Reference layer only |
| Review methodology | Skills, commands | Reference layer only |
| State ownership rules | CLAUDE.md, rules, skills | Ambient (one line) + Work (details) |
| Component annotations | CLAUDE.md, every file | Ambient (one line) |

## Verification

`scripts/measure-context.sh` reports per-layer line counts. If a layer exceeds its
budget, the likely cause is duplicated content that should be in a lower-priority layer.

Cross-layer grep for identical instruction text:
```sh
# Find potential duplicates
grep -rh "^-\|^[0-9]\." .claude/ skills/ | sort | uniq -d
```
