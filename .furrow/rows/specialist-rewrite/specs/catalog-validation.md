# Spec: catalog-validation

## Validation Process

After all 13 specialist files and the reference doc are complete, run these checks:

### 1. Structural Conformance

For each file in `specialists/*.md` (excluding harness-engineer.md which is the exemplar):

- [ ] Frontmatter has `name`, `description`, `type: specialist`
- [ ] H1 heading: `# {Name} Specialist`
- [ ] Section: `## Domain Expertise` (1-2 paragraphs)
- [ ] Section: `## How This Specialist Reasons` (5-8 bold-name bullet points)
- [ ] Section: `## Quality Criteria` (prose paragraph)
- [ ] Section: `## Anti-Patterns` (table with 3 columns)
- [ ] Section: `## Context Requirements` (Required + Helpful bullets, no Exclude)
- [ ] Pattern count within 5-8 range
- [ ] No other sections present

### 2. Pattern Uniqueness

- [ ] No two specialists share an identically-named reasoning pattern
- [ ] Extract all pattern names (bold text before colon in reasoning section)
- [ ] Report any duplicates

### 3. Distinguishing Test

For each reasoning pattern, ask: "Could this pattern move to a different specialist without changes?"

Flag patterns that are too generic:
- Applies to any engineering domain without modification
- Uses only general terms ("consider trade-offs", "think about edge cases")
- Doesn't reference domain-specific concepts

### 4. Overlap Boundary Documentation

Document where adjacent specialists share concerns and how they're distinguished:

| Pair | Shared Concern | Boundary |
|------|---------------|----------|
| security-engineer / api-designer | Auth, input validation | security-engineer: systemic posture; api-designer: endpoint-level contract |
| migration-strategist / relational-db-architect | Schema migrations | migration-strategist: phasing strategy; relational-db-architect: schema safety |
| migration-strategist / document-db-architect | Schema evolution | migration-strategist: cutover strategy; document-db-architect: document shape |
| shell-specialist / cli-designer | CLI tools | shell-specialist: script correctness; cli-designer: UX and interface design |
| go-specialist / systems-architect | Interface design | go-specialist: Go-level interfaces; systems-architect: module boundaries |
| complexity-skeptic / systems-architect | Abstraction decisions | complexity-skeptic: argues for removal; systems-architect: argues for right-sizing |

### 5. Reference Doc Alignment

- [ ] `references/specialist-template.md` format example matches actual specialist files
- [ ] All specialist names in naming convention section are valid
