# Spec: specialist-model-hints

## Interface Contract

Each specialist template in `specialists/*.md` gains a `model_hint` field in YAML frontmatter.

**Before:**
```yaml
---
name: systems-architect
description: "..."
type: specialist
---
```

**After:**
```yaml
---
name: systems-architect
description: "..."
type: specialist
model_hint: opus  # valid: sonnet | opus | haiku
---
```

Consumers: lead agent reads frontmatter when dispatching sub-agents via Agent tool.
No CLI tools parse this field — it's advisory metadata for the lead agent.

## Acceptance Criteria (Refined)

- All 16 files in `specialists/*.md` contain `model_hint:` in YAML frontmatter
- `model_hint: opus` appears in exactly 3 files: systems-architect.md, complexity-skeptic.md, security-engineer.md
- `model_hint: sonnet` appears in exactly 13 files (all others)
- Each frontmatter contains comment `# valid: sonnet | opus | haiku` on the `model_hint` line
- Field position: after `type: specialist`, before closing `---`
- No other content in the specialist files is modified

## Implementation Notes

- Uniform edit: same insertion point in all 16 files (after `type: specialist` line)
- Only the frontmatter value and comment differ between opus/sonnet specialists
- Grep verification: `grep -c 'model_hint: opus' specialists/*.md` should return 3 matches
- Grep verification: `grep -c 'model_hint: sonnet' specialists/*.md` should return 13 matches

## Dependencies

- None — this deliverable is independent
