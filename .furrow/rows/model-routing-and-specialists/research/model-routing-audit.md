# Model Routing Audit

## Sources Consulted
- specialists/_meta.yaml (primary) — full read
- specialists/*.md (primary) — frontmatter of all 20 specialists
- skills/*.md (primary) — model_default from all 7 step skills
- references/specialist-template.md (primary) — model_hint guidance
- specialists/harness-engineer.md (primary) — full read
- .furrow/almanac/rationale.yaml (primary) — full read

## Complete Routing Table

### Step Skills

| Step | model_default | Rationale |
|------|---------------|-----------|
| ideate | sonnet | Brainstorm, definition authoring |
| research | **opus** | Investigation, multi-source synthesis |
| plan | sonnet | Synthesize research into decisions |
| spec | sonnet | Structured writing from plan |
| decompose | sonnet | Formulaic given plan |
| implement | sonnet | Execution against specs |
| review | **opus** | Quality evaluation, judgment |

### Specialists

| Specialist | model_hint | Domain |
|------------|-----------|--------|
| api-designer | sonnet | HTTP API design |
| cli-designer | sonnet | CLI UX |
| complexity-skeptic | **opus** | Dependency evaluation, simplicity |
| document-db-architect | sonnet | Document data modeling |
| go-specialist | sonnet | Go idioms |
| harness-engineer | sonnet | Shell scripts, hooks, schemas |
| merge-specialist | sonnet | Git merge strategy |
| migration-strategist | sonnet | System evolution |
| python-specialist | sonnet | Pythonic patterns |
| relational-db-architect | sonnet | SQL schema design |
| security-engineer | **opus** | Threat modeling |
| shell-specialist | sonnet | Non-harness shell scripts |
| systems-architect | **opus** | Component boundaries, architecture |
| test-engineer | sonnet | Test design |
| typescript-specialist | sonnet | TypeScript type system |
| frontend-designer | sonnet | Rendering strategy |
| css-specialist | sonnet | CSS algorithms |
| accessibility-auditor | **opus** | Semantic HTML, ARIA |
| prompt-engineer | **opus** | Instruction design |
| technical-writer | sonnet | Documentation |

**5 opus** (25%): complexity-skeptic, security-engineer, systems-architect, accessibility-auditor, prompt-engineer
**15 sonnet** (75%): all others

### Model Routing Guidance (from specialist-template.md)
- `opus`: Multi-step reasoning, novel problem-solving, cross-component architectural decisions
- `sonnet`: Well-scoped execution within established patterns, single-domain work
- `haiku`: Reserved for trivial boilerplate (no specialists currently qualify)

## Consistency Assessment

No routing conflicts detected. All assignments align with guidance:
- Opus specialists handle adversarial reasoning, cross-domain synthesis, or novel problem-solving
- Sonnet specialists handle well-scoped execution within established patterns
- harness-engineer uses sonnet (shell scripting is pattern execution, not architectural reasoning)

## Harness-Engineer Analysis

### Current Structure (67 lines)
- 8 reasoning patterns (enforcement spectrum, platform boundary, contract thinking, etc.)
- 5 anti-patterns (all Furrow-specific)
- Context Requirements already list rationale.yaml as **Required**

### Rationale Grounding Opportunity
harness-engineer's Context Requirements already include:
```
Required: .furrow/almanac/rationale.yaml — consult before adding, modifying, or deleting components
```

What's missing: explicit reasoning patterns that use rationale.yaml:
- Before proposing new components: check if rationale.yaml documents similar enforcement
- Before modifying components: verify exists_because still holds
- Before deleting: check whether delete_when conditions are satisfied
- Use rationale entries to justify architectural decisions

### Rationale.yaml Structure
464 lines, 100+ components documented. Each entry:
```yaml
- path: {component path}
  exists_because: "{justification}"
  delete_when: "{condition for removal}"
```

Coverage: ambient layer, work layer, step layer, hooks, scripts, schemas, references, evals, adapters, specialists, CLIs.

## Implications for Deliverable: specialist-step-modes

1. **No model_hint changes needed** — current assignments are consistent
2. **Mode overlays are the real work** — step skills need per-step directives
3. **Harness-engineer grounding** — add reasoning patterns that explicitly use rationale.yaml
4. **specialist-template.md** — document mode overlay convention
5. **_meta.yaml** — verify but likely no changes needed
