# Spec: vertical-slice-guardrails

## Interface Contract

Three additive edits to existing files. No new files, no schema changes.

**red-flags.md**: New row in the Decompose section table (after line 35).
Format: `| Signal | Risk | Action |` — matches existing rows.

**decompose.yaml**: New 5th dimension appended after `ownership-clarity`.
Schema: `name`, `definition`, `pass_criteria`, `fail_criteria`, `evidence_format` — matches existing dimensions.

**decompose.md**: New 5th rule in Step-Specific Rules section (after line 14).
Format: single-line rule with cross-references — matches existing rules.

## Acceptance Criteria (Refined)

1. `skills/shared/red-flags.md` contains a Decompose row where Signal mentions "architectural layer" naming pattern and Action says to reframe as vertical slices or justify horizontal decomposition.
2. `evals/dimensions/decompose.yaml` contains a dimension named `vertical-slicing` with pass_criteria that requires each deliverable to produce at least one testable behavior change OR have explicit justification for horizontal decomposition.
3. The `vertical-slicing` dimension's fail_criteria references deliverables that modify only one architectural layer with no consumer and no justification.
4. `skills/decompose.md` Step-Specific Rules section contains a rule referencing vertical slices with pointers to both the red flag and the eval dimension.
5. No existing content is modified — all changes are additive insertions.

## Implementation Notes

- The eval dimension uses justification-as-pass: the evaluator checks for EITHER vertical slicing OR explicit plan-level justification. This avoids needing a schema change for N/A support.
- The red flag serves as a pre-write warning (read before composing the plan). The eval dimension is gate enforcement (checked at transition). These are complementary roles, not redundant enforcement.
- The decompose.md rule is a pointer, not a duplication of the red flag or eval content.

## Dependencies

- No deliverable dependencies.
- Reads existing structure of: `skills/shared/red-flags.md`, `evals/dimensions/decompose.yaml`, `skills/decompose.md`.
