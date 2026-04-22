# Spec: dual-review-and-specialist-delegation

## Interface Contract

### A. Specialist System (scenarios field)

**File**: `specialists/_meta.yaml`
Each specialist entry gains a `scenarios` array field with 3-5 When/Use pairs:
```yaml
{specialist}:
  file: {name}.md
  description: "{existing}"
  scenarios:
    - When: "{concrete task context triggering this specialist}"
      Use: "{reasoning pattern from specialist that applies}"
```

**File**: Specialist frontmatter (each `specialists/*.md`)
Same `scenarios` field added to YAML frontmatter, matching _meta.yaml entries.

**File**: `references/specialist-template.md`
New normative requirement section "Scenarios" after "When NOT to Use":
- Every specialist must declare 3-5 scenarios in frontmatter
- Each scenario has a `When` (task trigger) and `Use` (reasoning pattern reference)
- Scenarios must reference actual content from "How This Specialist Reasons" section

### B. Shared Delegation Protocol

**New file**: `skills/shared/specialist-delegation.md` (~15 lines)
Procedure for step agents to select and delegate to specialists:
1. Read `specialists/_meta.yaml` scenarios index
2. Select specialists whose scenarios match current task context
3. Delegate to selected specialists as sub-agents (never load into orchestration session)
4. Record selections in summary.md with rationale

**Step skill modifications** (one-liner each):
- `skills/ideate.md` — add reference in Shared References section
- `skills/research.md` — add reference in Shared References section
- `skills/plan.md` — add reference in Shared References section
- `skills/spec.md` — add reference in Shared References section
- `skills/decompose.md` — add reference in Shared References section

Format: `- skills/shared/specialist-delegation.md — specialist selection and delegation protocol`

### C. Dual-Reviewer Protocol (plan.md and spec.md)

**File**: `skills/plan.md` — new section after Step Mechanics, before Supervised Transition Protocol:
```markdown
## Dual-Reviewer Protocol
Before requesting transition, run both reviewers in parallel:
1. **Fresh Claude reviewer** — `claude -p --bare` with plan artifacts,
   definition.yaml ACs, and `evals/dimensions/plan.yaml` dimensions.
   Specialist template included if specialist was delegated during this step.
   Receives: plan.json, team-plan.md (if exists), definition.yaml.
   Excludes: summary.md, conversation history, state.json.
2. **Cross-model reviewer** — `frw cross-model-review {name} --plan`
   if `cross_model.provider` configured in `furrow.yaml`. Skip if absent.
Synthesize findings: flag disagreements, note unique findings, record
both sources in gate evidence. Address or explicitly reject all findings
before requesting transition.
```

**File**: `skills/spec.md` — identical pattern, referencing `--spec` flag and spec dimensions:
```markdown
## Dual-Reviewer Protocol
Before requesting transition, run both reviewers in parallel:
1. **Fresh Claude reviewer** — `claude -p --bare` with spec artifacts,
   definition.yaml ACs, and `evals/dimensions/spec.yaml` dimensions.
   Specialist template included if specialist was delegated during this step.
   Receives: spec.md or specs/ directory, definition.yaml.
   Excludes: summary.md, conversation history, state.json.
2. **Cross-model reviewer** — `frw cross-model-review {name} --spec`
   if `cross_model.provider` configured in `furrow.yaml`. Skip if absent.
Synthesize findings: flag disagreements, note unique findings, record
both sources in gate evidence. Address or explicitly reject all findings
before requesting transition.
```

### D. Cross-Model Review Script

**File**: `bin/frw.d/scripts/cross-model-review.sh`

**Argument parsing extension** (after existing `--ideation` case):
```bash
--plan) _plan=true; shift ;;
--spec) _spec=true; shift ;;
```

**Routing** (after ideation dispatch):
```bash
if [ "$_plan" = true ]; then
  _cross_model_plan "$@"
  return $?
elif [ "$_spec" = true ]; then
  _cross_model_spec "$@"
  return $?
fi
```

**New function `_cross_model_plan()`** (follows `_cross_model_ideation()` pattern):
- Arguments: `<name>`
- Reads: plan.json (wave structure, specialist assignments, file ownership), definition.yaml (objective, deliverables, ACs), summary.md (architecture decisions)
- Loads dimensions: `evals/dimensions/plan.yaml` via `frw select-dimensions`
- Prompt focus: coverage (all deliverables in waves), feasibility (valid dependency ordering), specificity (ownership globs defined), research-grounding (decisions cite research)
- Output: `${work_dir}/reviews/plan-cross.json`
- Schema:
  ```json
  {
    "type": "plan",
    "dimensions": [{"name": "...", "verdict": "pass|fail", "evidence": "..."}],
    "overall": "pass|fail",
    "reviewer": "{provider}",
    "cross_model": true,
    "timestamp": "ISO8601"
  }
  ```

**New function `_cross_model_spec()`** (same pattern):
- Arguments: `<name>`
- Reads: spec.md or specs/ directory, definition.yaml (ACs for comparison), plan.json (for consistency check)
- Loads dimensions: `evals/dimensions/spec.yaml` via `frw select-dimensions`
- Prompt focus: testability (ACs mechanically verifiable), completeness (all deliverables refined), consistency (no contradictions), implementability (enough detail)
- Output: `${work_dir}/reviews/spec-cross.json`
- Schema: same as plan with `"type": "spec"`

**Help text update** in `bin/frw` dispatcher:
```
cross-model-review <name> --plan        Run cross-model plan review
cross-model-review <name> --spec        Run cross-model spec review
```

### E. Gate Dimension Additions

**File**: `evals/gates/plan.yaml` — add to `post_step.additional_dimensions`:
```yaml
- name: "dual-review"
  definition: "Whether fresh-context and cross-model review evidence exists for the plan"
  pass_criteria: "Evidence of fresh-context or cross-model review exists. Review findings were incorporated or explicitly rejected with rationale."
  fail_criteria: "No review evidence exists. Findings ignored without rationale."
  evidence_format: "Cite review source and disposition of findings"
```

**File**: `evals/gates/spec.yaml` — identical dimension added to `additional_dimensions`.

## Acceptance Criteria (Refined)

1. `skills/plan.md` contains a "Dual-Reviewer Protocol" section between Step Mechanics and Supervised Transition Protocol, referencing `claude -p --bare` and `frw cross-model-review {name} --plan`
2. `skills/spec.md` contains a "Dual-Reviewer Protocol" section between Step Mechanics and Supervised Transition Protocol, referencing `--spec`
3. `cross-model-review.sh` accepts `--plan` and `--spec` flags, dispatching to `_cross_model_plan()` and `_cross_model_spec()` functions that read step-specific artifacts, load step dimensions, invoke provider, and write to `reviews/{plan|spec}-cross.json`
4. `specialists/_meta.yaml` includes `scenarios` array field for all existing specialists (21 entries, 3-5 When/Use pairs each)
5. Step skills (ideate, research, plan, spec, decompose) include a one-line reference to `skills/shared/specialist-delegation.md` in their Shared References section
6. `skills/shared/specialist-delegation.md` exists with the specialist selection and delegation procedure (~15 lines)
7. Dual-review evidence appears in gate records: `evals/gates/plan.yaml` and `evals/gates/spec.yaml` each have a `dual-review` dimension in `additional_dimensions`

## Test Scenarios

### Scenario: cross-model-review --plan flag acceptance
- **Verifies**: AC 3
- **WHEN**: `frw cross-model-review dual-review-delegation --plan` is invoked with a valid plan.json and configured cross_model.provider
- **THEN**: Script reads plan.json + definition.yaml, loads plan dimensions, invokes provider, writes `reviews/plan-cross.json` with type "plan"
- **Verification**: `jq '.type' reviews/plan-cross.json` outputs `"plan"` and exit code 0

### Scenario: cross-model-review --spec flag acceptance
- **Verifies**: AC 3
- **WHEN**: `frw cross-model-review dual-review-delegation --spec` is invoked with a valid spec.md
- **THEN**: Script writes `reviews/spec-cross.json` with type "spec"
- **Verification**: `jq '.type' reviews/spec-cross.json` outputs `"spec"` and exit code 0

### Scenario: cross-model-review skips gracefully without provider
- **Verifies**: AC 3
- **WHEN**: `cross_model.provider` is absent from furrow.yaml and `--plan` is invoked
- **THEN**: Script exits with code 1 (graceful skip)
- **Verification**: Exit code is 1, no review file written

### Scenario: _meta.yaml scenarios field present for all specialists
- **Verifies**: AC 4
- **WHEN**: `specialists/_meta.yaml` is read after implementation
- **THEN**: Every specialist entry has a `scenarios` array with 3-5 entries, each with `When` and `Use` keys
- **Verification**: `yq '.[].scenarios | length' specialists/_meta.yaml` outputs 3-5 for each entry

### Scenario: step skills reference shared delegation protocol
- **Verifies**: AC 5
- **WHEN**: Each step skill (ideate, research, plan, spec, decompose) is read
- **THEN**: Contains `skills/shared/specialist-delegation.md` in Shared References
- **Verification**: `grep -l 'specialist-delegation.md' skills/{ideate,research,plan,spec,decompose}.md` returns all 5 files

### Scenario: gate dimensions include dual-review
- **Verifies**: AC 7
- **WHEN**: `evals/gates/plan.yaml` and `evals/gates/spec.yaml` are read
- **THEN**: `post_step.additional_dimensions` includes entry with `name: "dual-review"`
- **Verification**: `yq '.post_step.additional_dimensions[] | select(.name == "dual-review")' evals/gates/plan.yaml` returns non-empty

## Implementation Notes

- Follow `_cross_model_ideation()` exactly for the new functions — same provider dispatch, JSON parsing, and error handling patterns
- The `select-dimensions` script already routes `plan` and `spec` steps to the correct dimension files — no changes needed there
- Specialist frontmatter `scenarios` must match `_meta.yaml` `scenarios` — dual-sourced by design
- Specialist Delegation section in step skills is a shared reference one-liner, NOT a per-step section
- Dual-Reviewer Protocol sections in plan.md/spec.md are step-specific (different artifacts, different dimensions) — not shareable

## Dependencies

- `evals/dimensions/plan.yaml` — must exist (already does)
- `evals/dimensions/spec.yaml` — must exist (already does)
- `bin/frw.d/scripts/select-dimensions.sh` — must route plan/spec steps (already does)
- `furrow.yaml` `cross_model.provider` — optional, graceful skip if absent
