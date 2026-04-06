# Model Routing — Research

## D1: specialist-model-hints

**Frontmatter format** — all 16 specialists use identical structure:
```yaml
---
name: <kebab-case>
description: "..."
type: specialist
---
```

`model_hint` goes after `type`, before closing `---`:
```yaml
---
name: systems-architect
description: "..."
type: specialist
model_hint: opus
---
```

No variation across specialists — uniform edit pattern.

## D2: step-model-defaults

Step skills don't have YAML frontmatter — they use markdown headers. The `model_default`
annotation should be a metadata line near the top, consistent with how step skills
document their purpose. A comment-style annotation in a dedicated section works:

```markdown
## Model Default
model_default: sonnet
```

## D3: consumer-wiring

### implement.md (lines 21-26)
Current dispatch instruction:
> Two consumption paths for specialist templates in `specialists/`:
> - **Solo work**: invoke the specialist as a skill to load domain framing
> - **Multi-agent**: include specialist template content in the Agent tool's `prompt` parameter

**Change needed**: After the multi-agent path, add instruction to read `model_hint` from
specialist frontmatter and pass it as the Agent tool's `model` parameter. Fall back to
step `model_default`, then project default (sonnet).

### decompose.md (lines 23-28)
Current assignment instruction:
> Resolve specialist templates from `specialists/*.md` by domain value.

**Change needed**: When resolving specialists, read `model_hint` from frontmatter and
include it in the team-plan.md task assignment so implement doesn't need to re-resolve.

### review.md (line 25)
Current dispatch instruction:
> For multi-deliverable work, assign review sub-agents per deliverable. Read `skills/shared/context-isolation.md`.

**Change needed**: Add instruction to read specialist `model_hint` when spawning reviewer
agents. The review step defaults to opus anyway, but specialist-level overrides still apply.

## D4: routing-docs

**context-isolation.md** structure:
1. What Sub-Agents Receive
2. What Sub-Agents Do NOT Receive
3. Context Curation Using Specialist Templates
4. Wave Isolation
5. Anti-Pattern: Context Leakage

**Best insertion point**: New section after "Context Curation Using Specialist Templates"
and before "Wave Isolation". Natural flow: template guidance → model selection → wave execution.

## Findings

- Implementation is straightforward — uniform patterns across all target files
- No conflicts with existing content or conventions
- The `cross_model.provider` field in furrow.yaml is a separate concern (ideation-only)
- No schema changes needed — frontmatter is parsed by the lead agent, not by CLI tools
