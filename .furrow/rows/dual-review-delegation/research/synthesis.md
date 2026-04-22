# Research Synthesis: dual-review-delegation

## Key Findings by Deliverable

### dual-review-and-specialist-delegation

**Dual-review at plan/spec is a clean extension of existing patterns.** The review step's `claude -p --bare` + `frw cross-model-review` protocol translates directly. Key implementation details:

1. **Protocol**: Use review step pattern (not ideate). `claude -p --bare` for fresh reviewer, `frw cross-model-review --plan|--spec` for cross-model. Both run in parallel at end-of-step, before gate evaluation.

2. **cross-model-review.sh**: Needs two new functions (`_cross_model_plan()`, `_cross_model_spec()`) following `_cross_model_ideation()` pattern. Each reads step-specific artifacts (plan.json or spec.md), loads step dimensions via `frw select-dimensions`, constructs domain-specific prompt.

3. **Gate integration**: Add `dual-review` dimension to `evals/gates/plan.yaml` and `evals/gates/spec.yaml` post-step `additional_dimensions`. Follows ideate's `cross-model` dimension pattern. Evidence recorded in extended gate file `gates/{boundary}.json`.

4. **Specialist delegation**: Add ~15-20 line "Specialist Delegation" section to each step skill (ideate, research, plan, spec, decompose) after existing "Step-Level Specialist Modifier". Instructions: read _meta.yaml scenarios, select relevant specialists, delegate as sub-agents, record in summary.md.

5. **Specialist frontmatter**: Add `scenarios` field (3-5 When/Use pairs). No new matching infrastructure needed — the step agent reads scenarios and makes explicit selection.

6. **Context budget**: Step skill additions (~20 lines each) fit within budget. Specialist templates load into sub-agents only, not injected into orchestration.

### new-specialist-templates

Independent of infrastructure changes. Follow `references/specialist-template.md` normative requirements. Both need:
- ≤80 lines including frontmatter
- `scenarios` field in frontmatter (3-5 entries)
- ≥3 anti-patterns, ≥1 project-specific
- "When NOT to Use" section
- Overlap boundaries with related specialists
- Registration in `specialists/_meta.yaml`

## Open Questions Resolved

| Question from Ideation | Resolution |
|------------------------|------------|
| How does dual-review integrate with gates? | New `dual-review` dimension in post-step additional_dimensions |
| What artifacts does plan/spec reviewer see? | Plan: plan.json + definition.yaml. Spec: spec.md + definition.yaml |
| Does reviewer see specialist context? | Yes — specialist-informed review (specialist template provided) |
| Where does specialist delegation section go? | After Step-Level Specialist Modifier, before Agent Dispatch Metadata |
| What does scenarios field look like? | When/Use pairs referencing specialist reasoning patterns |

## Remaining Open Questions

- Exact prompt templates for `_cross_model_plan()` and `_cross_model_spec()` functions (resolve at spec step)
- Whether `_meta.yaml` scenarios should be duplicated in specialist frontmatter or single-sourced (lean: both, for self-contained specialist files)

## Implementation Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Context budget exceeded by delegation sections | Low | Medium | Measure with `frw measure-context` after changes |
| Cross-model review prompt quality for plan/spec | Medium | Low | Follow ideation prompt pattern, iterate |
| Scenarios field too vague for abstract specialists | Low | Low | Use When/Use structure with concrete actions |
| Step skill changes break existing flow | Low | High | Add sections only, don't restructure |
