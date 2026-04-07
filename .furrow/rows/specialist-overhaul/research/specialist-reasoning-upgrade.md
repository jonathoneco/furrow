# Research: specialist-reasoning-upgrade

## Audit Results

| Specialist | Lines | Grade | Key Issue |
|---|---|---|---|
| harness-engineer | 64 | STRONG | Gold standard — deeply project-specific |
| merge-specialist | 55 | STRONG | Deeply project-specific, Furrow-aware |
| cli-designer | 49 | STRONG | Good frameworks + deliverable-driven structure |
| complexity-skeptic | 47 | STRONG | Genuine decision frameworks, opinionated |
| api-designer | 46 | ADEQUATE | Solid generic frameworks, no project grounding |
| document-db-architect | 52 | ADEQUATE | Good reasoning, fully generic |
| go-specialist | 49 | ADEQUATE | Some project alignment via CLAUDE.md, mixed |
| migration-strategist | 49 | ADEQUATE | Excellent frameworks (expand-contract), generic |
| relational-db-architect | 50 | ADEQUATE | Solid (constraint-first), generic |
| systems-architect | 51 | ADEQUATE | Good frameworks, some Furrow alignment |
| test-engineer | 48 | ADEQUATE | "Gate-aligned testing" is good, rest generic |
| security-engineer | 47 | WEAK | Entirely OWASP-101, zero project content |
| shell-specialist | 49 | WEAK | Shell-101 overlapping with harness-engineer |
| python-specialist | 49 | WEAK | Python-201 the model already knows |
| typescript-specialist | 49 | WEAK | Standard TS advice, may not be relevant |

## Key Finding

The outside voice reviewer was partially right: the 4 STRONG specialists
already meet the bar. But 4 are genuinely WEAK (security, shell, python, TS)
and 7 need project-specific grounding injected. The upgrade work is real
but varies significantly per specialist.

## Weakness Patterns

1. **Language-reference bloat**: python, shell, typescript restate what the
   model already knows (quote variables, use generators, avoid `as any`).
2. **No project-specific conventions**: security, python, typescript have
   zero project-specific content. The model's default behavior is identical.
3. **Overlap**: shell-specialist duplicates harness-engineer for project shell
   work. Either differentiate (non-harness shell) or merge.
4. **Relevance uncertainty**: Are Python and TypeScript used in this project?
   If not, these are speculative inventory.

## Template Standard Gaps Found

1. No guidance requiring project-specific grounding
2. No distinction between "restated best practice" and "genuine reasoning pattern"
3. No model_hint rationale guidance (opus vs sonnet)
4. No anti-pattern minimum count
5. No overlap/differentiation guidance between specialists
6. No "when NOT to use this specialist" section

## Upgrade Strategy

- **WEAK (4)**: Full rework — either ground in project conventions or merge/remove
- **ADEQUATE (7)**: Add project-specific conventions pass
- **STRONG (4)**: Minor polish only
- **Exemplars**: harness-engineer and merge-specialist demonstrate the target quality
- **Template standard**: Update with gap items before upgrading specialists

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| All 15 specialist files (source code) | Primary | Content analysis per specialist |
| references/specialist-template.md (source code) | Primary | Template standard requirements |
| CLAUDE.md (source code) | Primary | Project conventions to check alignment |
| harness-engineer.md, merge-specialist.md (source code) | Primary | Exemplars of target quality |
