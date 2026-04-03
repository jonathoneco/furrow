# Prompt Format Decision

## Decision: Three formats, matched to authoring pattern

Furrow has three distinct artifact types. Each gets the format that fits its authoring and consumption pattern.

### 1. YAML — human-authored data

**Extension**: `.yaml`
**Used for**: work definitions, eval specs, gate configs

```yaml
objective: "Add token rotation to auth middleware"
deliverables:
  - name: auth-token-rotation
    eval_criteria: |
      Token rotation occurs transparently on expiry.
      Existing sessions are not invalidated during rotation.
    specialist: security-specialist
    depends_on: []
```

**Why YAML**:
- Comments — component rationale annotations live in `.furrow/almanac/rationale.yaml`, not inline
- Multi-line strings — eval criteria are 2-5 lines of prose; `|` blocks handle this cleanly
- Indentation-based nesting — deeply nested structures (deliverables → criteria → calibration) are scannable
- Git diffs are clean — no trailing commas, no brace lines
- Schema validation — JSON Schema validates YAML (same data model)
- Settled decision — the research resolved on YAML for work definitions

**Risk**: indentation errors are silent. Mitigated by schema validation at load time (Level A enforcement).

### 2. JSON — machine-authored data

**Extension**: `.json`
**Used for**: progress state, eval results, calibration data, trace events

```json
{
  "deliverable": "auth-token-rotation",
  "status": "completed",
  "eval_result": "pass",
  "completed_at": "2026-03-29T14:30:00Z"
}
```

**Why JSON**:
- No indentation ambiguity — write/read round-trips are safe
- Native in both runtimes without a parsing library
- Machine-written, machine-read — human readability is secondary
- The research docs already assume this (`progress.json`, `deliverable-a.json`)

### 3. YAML frontmatter + markdown body — instruction-primary content

**Extension**: `.md`
**Used for**: agent seeding prompts, specialist definitions, handoff prompts, skills

```markdown
---
name: security-specialist
type: specialist
domain: application-security
---

You are a security specialist reviewing authentication and authorization code.

Focus on: token leakage, CSRF, session fixation, privilege escalation.
When reviewing code changes, check for...
```

**Why frontmatter+markdown**:
- Matches Anthropic's Skills format — Claude Code loads these natively via progressive skill loading
- Prose is the primary value — instructions to shape agent behavior
- Metadata in frontmatter handles routing/classification
- Agent SDK parses by splitting on `---` — trivial adapter

## Format selection rule

| Artifact is... | Format | Extension |
|----------------|--------|-----------|
| Structured data, human-authored | YAML | `.yaml` |
| Structured data, machine-authored | JSON | `.json` |
| Instructions with metadata | YAML frontmatter + markdown | `.md` |

The rule: **follow the authoring pattern**. If a human writes and iterates on the structure, YAML. If a machine writes it, JSON. If the value is in the prose, frontmatter+markdown.

## Dual-runtime consumption

| Format | Claude Code | Agent SDK |
|--------|-------------|-----------|
| YAML | Parsed via skill/hook (standard YAML library) | Parsed at program startup (standard YAML library) |
| JSON | Parsed via hook (native) | Parsed at callback boundary (native) |
| Frontmatter+MD | Loaded as skill (native progressive loading) | Split on `---`, parse frontmatter as YAML, body as string |

No custom parsing infrastructure required. Both runtimes handle all three formats with standard libraries.

## What this means for subsequent specs

- **Work Definition Schema** (Deliverable 1): YAML format, validated by JSON Schema
- **Progress tracking**: JSON format, written by hooks/callbacks
- **Eval specs**: YAML format (LLM-judge criteria are human-authored data)
- **Eval results**: JSON format (machine-written)
- **Agent/specialist definitions**: Frontmatter+markdown
- **Handoff prompts**: Frontmatter+markdown
- **Work summaries**: Frontmatter+markdown (auto-generated but human-readable)
