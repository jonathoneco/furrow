# Spec: specialist-expansion

## Interface Contract

Files created:
- `specialists/frontend-designer.md` — rendering strategy, hydration cost, state colocation
- `specialists/css-specialist.md` — algorithm-first layout, specificity budgeting, compositing
- `specialists/accessibility-auditor.md` — ARIA-as-repair, focus management, announcement strategy
- `specialists/prompt-engineer.md` — structural constraint over behavioral, failure mode prediction
- `specialists/technical-writer.md` — Diataxis mode discipline, progressive disclosure, maintenance-cost

Files modified:
- `specialists/_meta.yaml` — registry entries for all 5 new specialists
- `.furrow/almanac/rationale.yaml` — component entries for all 5 new specialist files
- `specialists/harness-engineer.md` — explicit rationale.yaml grounding in Context Requirements

Consumers: implement step (specialist loading), review step (specialist-framed evaluation),
plan.json assignments (specialist field validation)

## Acceptance Criteria (Refined)

1. Each of the 5 specialist files exists in `specialists/` and passes template
   validation: YAML frontmatter with `name`, `description`, `type: specialist`,
   and `model_hint` fields; sections for Domain Expertise, How This Specialist
   Reasons, Quality Criteria, Anti-Patterns (table), and Context Requirements.

2. Line count per specialist file is at most 80 lines (measured by `wc -l`).

3. Reasoning patterns per specialist: 5-8 bold-name bullets, each with 2-4
   sentences that encode decision frameworks, not generic advice. Specifically:
   - frontend-designer: rendering strategy selection, hydration cost reasoning,
     state colocation — framework-agnostic (no React/Vue specifics)
   - css-specialist: algorithm-first layout selection, specificity budget management
   - accessibility-auditor: semantic-HTML-first/ARIA-as-repair, focus management
   - prompt-engineer: structural constraint over behavioral instruction, failure
     mode prediction
   - technical-writer: Diataxis mode discipline, maintenance-cost awareness

4. Model hints match research recommendations:
   - frontend-designer: sonnet
   - css-specialist: sonnet
   - accessibility-auditor: opus
   - prompt-engineer: opus
   - technical-writer: sonnet

5. `specialists/_meta.yaml` contains an entry per new specialist matching the
   existing format:
   ```yaml
   {name}:
     file: {name}.md
     description: "{one-line description}"
   ```

6. `.furrow/almanac/rationale.yaml` contains a component entry per new specialist
   matching the existing format:
   ```yaml
   - path: specialists/{name}.md
     exists_because: "Claude Code does not natively provide domain-specific agent priming for {domain}"
     delete_when: "Claude Code supports built-in specialist roles with domain expertise injection"
   ```

7. `specialists/harness-engineer.md` Context Requirements section promotes the
   rationale.yaml reference from "Helpful" to "Required" with explicit grounding
   language: the harness engineer must consult rationale.yaml before adding,
   modifying, or deleting components to verify justification and deletion conditions.

8. Anti-Patterns tables in each specialist contain at least 3 rows of
   domain-specific anti-patterns with "Do This Instead" alternatives.

## Implementation Notes

### Fitting research designs into 80 lines

The research file documents 6-8 patterns per specialist. To fit the 80-line budget:
- Frontmatter + heading: ~6 lines
- Domain Expertise: 2-3 lines (single dense paragraph)
- Reasoning patterns: ~30-35 lines (5-6 patterns at 5-6 lines each; trim the
  weakest 1-2 patterns from research if needed to fit)
- Quality Criteria: 3-4 lines (single paragraph)
- Anti-Patterns table: ~8-10 lines (header + 3-4 rows)
- Context Requirements: 4-6 lines (Required + Helpful bullets)

Prioritize patterns that encode decision frameworks and expert heuristics the
model does not default to. Drop patterns that overlap with general model
capabilities or duplicate another specialist's domain.

### Framework agnosticism (frontend-designer)

Research concern: references React-specific patterns (useEffect, React.memo).
The spec must use framework-agnostic language. Instead of "avoid useEffect for
data fetching," write "prefer server-side data resolution over client-side
fetch-on-mount patterns." The reasoning pattern should be portable across
React, Vue, Svelte, HTMX, etc.

### _meta.yaml registry format

Append entries below the existing `merge-specialist` entry. Each entry is a
top-level key (kebab-case specialist name) with `file` and `description` fields.
Alphabetical ordering is not required — append at end.

### rationale.yaml entry format

Append entries in the `# --- Specialists` section, after the existing specialist
entries (merge-specialist.md is currently last). Use the exact `exists_because` /
`delete_when` pattern from existing specialist entries.

### harness-engineer.md change

In the Context Requirements section, change the line:
```
- Helpful: `.furrow/almanac/rationale.yaml` for understanding component justifications
```
to:
```
- Required: `.furrow/almanac/rationale.yaml` — consult before adding, modifying, or deleting components; verify exists_because justification and delete_when conditions
```

## Dependencies

- No deliverable dependencies (depends_on is empty in definition.yaml)
- Template standard at `references/specialist-template.md` must be stable
- Existing specialist exemplars (harness-engineer.md, api-designer.md,
  complexity-skeptic.md) serve as quality reference for reasoning pattern depth
