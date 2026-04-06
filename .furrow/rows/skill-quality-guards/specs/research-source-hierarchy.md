# Spec: research-source-hierarchy

## Interface Contract

Three additive edits to two existing files. No new files, no schema changes.

**research.md — output spec** (after line 8): New bullet requiring `## Sources Consulted` section in every research deliverable.

**research.md — rules** (after line 14): New rules defining the 3-tier source hierarchy and when training data is/isn't acceptable.

**research-sources.md** (after line 3, before Source Types): New `## Source Hierarchy` section with tier table and decision rules.

## Acceptance Criteria (Refined)

1. `skills/research.md` "What This Step Produces" section contains a bullet requiring a `## Sources Consulted` section in every research deliverable, listing sources with tier and contribution.
2. `skills/research.md` "Step-Specific Rules" section contains rules defining source hierarchy: primary (official docs, source code, changelogs, CLI help) > secondary (blogs, tutorials, StackOverflow) > tertiary (training data).
3. The rules specify that training data is acceptable for well-established facts (language syntax, stdlib APIs) but not for version-specific, behavior-specific, or configuration-specific claims.
4. The rules specify that claims about external software that cannot be verified against a primary source must be flagged as unverified.
5. `templates/research-sources.md` contains a `## Source Hierarchy` section with a 3-row tier table (Primary/Secondary/Tertiary) before the existing Source Types section.
6. No existing content is modified — all changes are additive insertions.

## Implementation Notes

- The Sources Consulted requirement is inline in the research output format, not a separate file. This ensures it can't be skipped on small research steps.
- The hierarchy is guidance, not a binary eval dimension. It augments the existing "multi-source triangulation for claims" rule with precedence.
- The template's hierarchy section sets priority context before listing citation formats.

## Dependencies

- No deliverable dependencies.
- Reads existing structure of: `skills/research.md`, `templates/research-sources.md`.
