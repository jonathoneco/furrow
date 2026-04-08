# Spec: specialist-step-modes

## Deliverable Overview
Add step-specific mode overlays to step skills, ground harness-engineer in
rationale.yaml, update specialist template documentation, and audit _meta.yaml.

Depends on: orchestrator-architecture (wave 1 must complete first — mode overlays
reference the Agent Dispatch Metadata structure added by wave 1).

## Artifact 1: Mode Overlays in Step Skills (MODIFY 3 files, VERIFY 2)

### New Mode Overlays

These steps currently lack a Step-Level Specialist Modifier section. Add one to each.

#### plan.md — insert after Collaboration Protocol (after line 38), as `### Step-Level Specialist Modifier`

```markdown
### Step-Level Specialist Modifier
When working with a specialist during planning, emphasize architectural framing
over implementation detail. The specialist should reason about component boundaries,
dependency direction, and trade-off analysis. Prefer options analysis (A vs B
with trade-offs stated) over prescriptive solutions. The specialist's domain
expertise applies to architecture decisions: what interfaces exist, what coupling
to accept, what patterns to follow.
```

#### decompose.md — insert after Step-Specific Rules (after line 18), as `### Step-Level Specialist Modifier`

```markdown
### Step-Level Specialist Modifier
When working with a specialist during decomposition, emphasize wave strategy,
dependency ordering, and file ownership scoping. The specialist should reason
about parallelism opportunities and minimize cross-deliverable coupling. The
specialist's domain expertise applies to scope decisions: what belongs together,
what can run concurrently, what order minimizes rework.
```

#### research.md — insert after Step-Specific Rules (after line 23), as `### Step-Level Specialist Modifier`

Note: Research rarely dispatches domain specialists (it dispatches generic research
agents), but when a deliverable has a specialist assigned and research is step-specific
to that domain, this overlay applies.

```markdown
### Step-Level Specialist Modifier
When working with a specialist during research, emphasize investigation breadth
and source triangulation over depth in any single approach. The specialist should
identify what is unknown and what claims require primary source verification.
The specialist's domain expertise applies to knowing where to look and what to
distrust in secondary sources.
```

### Existing Mode Overlays to Verify

Confirm these existing modifiers are consistent with the new pattern:

#### spec.md (lines 24-28) — EXISTING, verify wording alignment
```markdown
### Step-Level Specialist Modifier
When working with a specialist during spec, emphasize contract completeness,
boundary definition, and constraint enumeration over implementation pragmatism.
The specialist's reasoning patterns apply to specification decisions: what
interfaces to define, what invariants to enforce, what edge cases to address.
```
**Verdict**: Aligned. No changes needed.

#### implement.md (lines 45-50) — EXISTING, verify wording alignment
```markdown
### Step-Level Specialist Modifier
When working with a specialist during implementation, emphasize incremental
correctness, testability, and adherence to the spec over exploratory design.
The specialist's reasoning patterns apply to implementation decisions: which
pattern to use, how to structure the code, what anti-patterns to avoid.
```
**Verdict**: Aligned. No changes needed.

#### review.md (lines 22-26) — EXISTING, verify wording alignment
```markdown
### Step-Level Specialist Modifier
When working with a specialist during review, emphasize acceptance criteria
verification, anti-pattern detection per the specialist's table, and quality
dimension coverage. The specialist's reasoning patterns apply to review
judgments: what to check, what constitutes a violation, what quality bar to hold.
```
**Verdict**: Aligned. No changes needed.

### Acceptance Criteria (Refined)
- AC1: plan.md, decompose.md, research.md each have a Step-Level Specialist Modifier section
- AC2: All 6 mode overlays (3 new + 3 existing) follow the same sentence pattern: "When working with a specialist during {step}, emphasize {priorities} over {de-priorities}. The specialist's {reasoning/domain/expertise} applies to {step-specific decisions}: {examples}."
- AC3: Each overlay is ≤7 lines (matching existing implement.md and review.md length)
- AC4: ideate.md has NO mode overlay (ideate doesn't dispatch specialists for execution)

### Test Scenarios

**WHEN** all step skills with specialist dispatch are checked
**THEN** each has a Step-Level Specialist Modifier section
**VERIFY** `for f in plan spec decompose implement review; do grep -l 'Step-Level Specialist Modifier' skills/$f.md; done` returns 5 files

**WHEN** mode overlay text is measured
**THEN** each is ≤7 lines
**VERIFY** Check line count between section header and next section

---

## Artifact 2: specialists/harness-engineer.md (MODIFY)

### Changes Required

Add 2 reasoning patterns to the "How This Specialist Reasons" section. Insert after
the existing 8 patterns (before the Quality Criteria section).

```markdown
- **Rationale-first component decisions** — Before proposing, modifying, or removing
  any harness component, consult `.furrow/almanac/rationale.yaml`. Read the component's
  `exists_because` to understand its justification. Check `delete_when` to see if
  removal conditions are met. If the component isn't in rationale.yaml, that's a
  signal: either add it or question why it exists without justification.
- **Existence justification** — Every new component must have a rationale entry
  (`exists_because` + `delete_when`) before implementation. If you can't articulate
  both fields, the component isn't justified. This prevents accretion of unjustified
  infrastructure.
```

### Acceptance Criteria (Refined)
- AC1: harness-engineer.md has 10 reasoning patterns (8 existing + 2 new)
- AC2: Both new patterns explicitly reference rationale.yaml by path
- AC3: New patterns are actionable (they tell the specialist what to DO, not just what to know)
- AC4: No changes to existing reasoning patterns, anti-patterns, or other sections

### Test Scenarios

**WHEN** harness-engineer specialist is loaded for a task involving component creation
**THEN** it consults rationale.yaml before proposing new components
**VERIFY** `grep -c 'rationale.yaml' specialists/harness-engineer.md` ≥ 3 (Context Requirements + 2 new patterns)

---

## Artifact 3: references/specialist-template.md (MODIFY)

### Changes Required

Add new section **## Step-Level Mode Overlays** after "How Specialists Are Used"
(after line 119, before "Naming Convention" at line 121).

```markdown
## Step-Level Mode Overlays

Step skills include a `### Step-Level Specialist Modifier` section that adjusts how
specialists reason during that step. The overlay does not change the specialist's
domain — it shifts emphasis:

| Step | Emphasis | De-emphasis |
|------|----------|-------------|
| research | Investigation breadth, source triangulation | Single-approach depth |
| plan | Architectural framing, trade-off analysis | Implementation detail |
| spec | Contract completeness, boundary definition | Implementation pragmatism |
| decompose | Wave strategy, dependency ordering | Implementation detail |
| implement | Incremental correctness, testability | Exploratory design |
| review | AC verification, anti-pattern detection | Implementation alternatives |

Mode overlays interact with model_hint: an opus specialist retains its opus model
regardless of step. The overlay changes reasoning emphasis, not model selection.

When authoring a new specialist, you do NOT need to write step-specific content.
The step skills own the mode overlays. The specialist owns domain reasoning.
```

### Acceptance Criteria (Refined)
- AC1: specialist-template.md documents the mode overlay convention
- AC2: Table covers all 6 steps that dispatch specialists (not ideate)
- AC3: Explicitly states: overlays change emphasis, not model selection
- AC4: Explicitly states: specialist authors don't write step-specific content

### Test Scenarios

**WHEN** a new specialist is being authored
**THEN** specialist-template.md clarifies that mode overlays are step-owned, not specialist-owned
**VERIFY** `grep 'step skills own' references/specialist-template.md` returns a match

---

## Artifact 4: specialists/_meta.yaml (AUDIT, minimal changes)

### Audit Protocol

Read `specialists/_meta.yaml` and cross-reference each specialist's `model_hint` against
`references/model-routing.md` guidance:
- opus: multi-step reasoning, novel problems, cross-component decisions
- sonnet: well-scoped execution, established patterns

### Expected Findings (from research)
All 20 specialists are correctly assigned. No changes expected.
If any inconsistency is found during implementation, document it and fix.

### Acceptance Criteria (Refined)
- AC1: Every specialist in _meta.yaml has a model_hint value
- AC2: All model_hint values are consistent with model-routing.md guidance
- AC3: If changes are made, they're documented in the commit message

### Test Scenarios

**WHEN** _meta.yaml is audited against model-routing.md
**THEN** all entries pass consistency check
**VERIFY** `grep 'model_hint' specialists/_meta.yaml | sort | uniq -c` shows expected distribution (5 opus, 15 sonnet)
