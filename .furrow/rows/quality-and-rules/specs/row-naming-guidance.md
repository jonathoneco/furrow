# Spec: row-naming-guidance

## Interface Contract

**`skills/ideate.md`** — Add naming guidance in the brainstorm section (step 1 of the 6-part ceremony).

## Acceptance Criteria (Refined)

1. `skills/ideate.md` has a row naming guidance subsection in or near the brainstorm step
2. Guidance covers: outcome over area, verb-noun for single-focus, noun-and-noun for bundles
3. Guidance includes at least 3 good examples and 3 bad examples from actual row history
4. Good examples: `isolated-gate-evaluation`, `namespace-rename`, `default-supervised-gating`
5. Bad examples: `research-e2e`, `todos-workflow`, `roadmap-process`
6. Guidance is 8-12 lines max (doesn't bloat the skill)

## Test Scenarios

### Scenario: naming guidance is present
- **Verifies**: AC 1
- **WHEN**: Agent reads skills/ideate.md for ideation instructions
- **THEN**: Row naming guidance is visible in or near step 1
- **Verification**: `grep -c "naming" skills/ideate.md` >= 1

### Scenario: examples are concrete
- **Verifies**: AC 3, 4, 5
- **WHEN**: Reading the naming guidance section
- **THEN**: At least 3 good and 3 bad examples are listed with actual row names
- **Verification**: Section contains `isolated-gate-evaluation` and `todos-workflow`

## Implementation Notes

- Insert after step 1 (Brainstorm) or as a sub-bullet of step 1
- Format: brief principle statement, then good/bad example table or list
- Don't repeat the kebab-case format rule (already in validate-naming.sh)
- Focus on *quality* (descriptiveness) not *format* (kebab-case)

## Dependencies

- None.
