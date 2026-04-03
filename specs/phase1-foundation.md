# Phase 1: Foundation — Implementation Spec

Creates new files only. No existing behavior changes.

Deliverables: gate-yaml-schema, ideation-gate-migration, evaluator-prompt-template.

---

## Deliverable 1: gate-yaml-schema

Create `evals/gates/` directory with 7 YAML files. Each gate defines pre-step
and/or post-step evaluation dimensions for one Furrow step.

**Schema rules:**
- `pre_step` section: only research, plan, spec, decompose (4 of 7 steps)
- `post_step` section: all 7 steps
- `post_step.dimensions_from` references existing `evals/dimensions/{step}.yaml`
- `post_step.additional_dimensions` is optional (for gate-specific criteria beyond standard dimensions)
- `pre_step.dimensions` are always inline (gate-specific, no reference file)
- Steps with post_step only (no pre_step): ideation, implement, review
- Ideation has inline post_step dimensions (no dimensions_from, since no `evals/dimensions/ideation.yaml` exists)
- Implement and review reference their dimension files via dimensions_from

**Pre-step dimensions:**

| Step | Dimension | Purpose |
|------|-----------|---------|
| research | path-relevance | Whether AC file references are genuine work targets, not inserted to satisfy pre-step checks |
| plan | complexity-assessment | Whether the work is genuinely simple enough that no architecture decisions beyond the definition are needed |
| spec | testability | Whether acceptance criteria can be mechanically verified — moved from shell regex to evaluator judgment |
| decompose | wave-triviality | Whether single-wave no-ordering decomposition is genuinely correct with no hidden dependencies |

---

### File: evals/gates/ideation.yaml
```yaml
# Gate evaluation for the ideation step.
# Ideation has post_step only — no pre_step gate.
# Dimensions are inline because no evals/dimensions/ideation.yaml exists.

post_step:
  dimensions:
    - name: "completeness"
      definition: "Whether definition.yaml has all required fields with valid values"
      pass_criteria: "All required fields present: objective, deliverables (min 1, each with name and acceptance_criteria), context_pointers (min 1), gate_policy. Deliverable names unique. depends_on references resolve. Enum values valid."
      fail_criteria: "Any required field missing, invalid enum, duplicate deliverable names, or dangling depends_on reference"
      evidence_format: "Cite which fields are present/missing and any invalid values"

    - name: "alignment"
      definition: "Whether the definition maps to the original user intent"
      pass_criteria: "Objective clearly maps to original user intent. Each deliverable contributes to the objective. No deliverable is unrelated to the stated goal."
      fail_criteria: "Objective diverges from user intent, or a deliverable has no connection to the stated goal"
      evidence_format: "Cite objective text and user intent phrase"

    - name: "feasibility"
      definition: "Whether deliverables have testable acceptance criteria and bounded scope"
      pass_criteria: "Each deliverable has testable acceptance criteria (contains a verb like 'returns', 'enforces', 'validates', or a numeric threshold, or a file path). Scope is actionable — no unbounded deliverables."
      fail_criteria: "Acceptance criteria are vague ('improve UX', 'make faster') or deliverable scope is unbounded"
      evidence_format: "Cite criteria text and assessment"

    - name: "cross-model"
      definition: "Whether cross-model or fresh-context review evidence exists"
      pass_criteria: "Evidence of cross-model or fresh-context review exists. Review findings were incorporated or explicitly rejected with rationale."
      fail_criteria: "No cross-model review evidence. Findings ignored without rationale."
      evidence_format: "Cite review source and disposition of findings"
```

### File: evals/gates/research.yaml
```yaml
# Gate evaluation for the research step.
# Pre-step checks whether the research target is genuine.
# Post-step references evals/dimensions/research.yaml for quality evaluation.

pre_step:
  dimensions:
    - name: "path-relevance"
      definition: "Whether AC file references are genuine work targets, not inserted to satisfy pre-step checks"
      pass_criteria: "Every file path in acceptance_criteria exists in the codebase or is a plausible creation target consistent with the deliverable's purpose"
      fail_criteria: "Any AC file path does not exist and is not a plausible creation target, or paths appear copied from an unrelated deliverable"
      evidence_format: "List each AC file path with existence check result and relevance assessment"

post_step:
  dimensions_from: "evals/dimensions/research.yaml"
```

### File: evals/gates/plan.yaml
```yaml
# Gate evaluation for the plan step.
# Pre-step checks whether the work genuinely needs a multi-wave plan.
# Post-step references evals/dimensions/plan.yaml for quality evaluation.

pre_step:
  dimensions:
    - name: "complexity-assessment"
      definition: "Whether the work is genuinely simple enough that no architecture decisions beyond the definition are needed"
      pass_criteria: "Work involves 3+ deliverables with cross-deliverable dependencies, OR requires architecture decisions not captured in definition.yaml, OR touches 3+ distinct subsystems"
      fail_criteria: "Work is a single deliverable with no dependencies and no architecture decisions beyond what definition.yaml already specifies"
      evidence_format: "List deliverable count, dependency graph, and architecture decisions required beyond the definition"

post_step:
  dimensions_from: "evals/dimensions/plan.yaml"
```

### File: evals/gates/spec.yaml
```yaml
# Gate evaluation for the spec step.
# Pre-step checks whether acceptance criteria are mechanically verifiable.
# Post-step references evals/dimensions/spec.yaml for quality evaluation.

pre_step:
  dimensions:
    - name: "testability"
      definition: "Whether acceptance criteria can be mechanically verified — moved from shell regex to evaluator judgment"
      pass_criteria: "Every acceptance criterion in definition.yaml contains a concrete verification method: a command to run, a file to inspect, a value to compare, or a behavior to observe with expected output"
      fail_criteria: "Any acceptance criterion relies on subjective judgment ('clean code', 'well-designed', 'appropriate') without a measurable threshold or observable behavior"
      evidence_format: "Quote each untestable AC and explain what concrete condition is missing"

post_step:
  dimensions_from: "evals/dimensions/spec.yaml"
```

### File: evals/gates/decompose.yaml
```yaml
# Gate evaluation for the decompose step.
# Pre-step checks whether decomposition beyond a single wave is warranted.
# Post-step references evals/dimensions/decompose.yaml for quality evaluation.

pre_step:
  dimensions:
    - name: "wave-triviality"
      definition: "Whether single-wave no-ordering decomposition is genuinely correct with no hidden dependencies"
      pass_criteria: "All deliverables are truly independent (no shared files, no output-input chains, no ordering constraints) and a single wave with no depends_on is the correct decomposition"
      fail_criteria: "Deliverables share file ownership, one deliverable's output is another's input, or ordering constraints exist that a single wave would violate"
      evidence_format: "List each deliverable pair and their dependency relationship (shared files, data flow, or ordering constraint)"

post_step:
  dimensions_from: "evals/dimensions/decompose.yaml"
```

### File: evals/gates/implement.yaml
```yaml
# Gate evaluation for the implement step.
# Implement has post_step only — no pre_step gate.
# Post-step references evals/dimensions/implement.yaml for quality evaluation.

post_step:
  dimensions_from: "evals/dimensions/implement.yaml"
```

### File: evals/gates/review.yaml
```yaml
# Gate evaluation for the review step.
# Review has post_step only — no pre_step gate.
# Post-step evaluates whether the review was thorough and findings were addressed.

post_step:
  # No dimensions_from — evals/dimensions/review.yaml does not exist.
  # Review gate has unique criteria (inline), like ideation.
  dimensions:
    - name: "finding-resolution"
      definition: "Whether all review findings have been addressed or explicitly deferred"
      pass_criteria: "Every finding from the review has a resolution: fixed (with commit reference), deferred (with justification), or rejected (with rationale)"
      fail_criteria: "Any review finding has no resolution recorded"
      evidence_format: "List each unresolved finding"

    - name: "coverage-completeness"
      definition: "Whether the review covered all deliverables in the current wave"
      pass_criteria: "Every deliverable in the current wave has a review record with per-dimension verdicts"
      fail_criteria: "Any deliverable in the current wave has no review record"
      evidence_format: "Name the unreviewed deliverable"
```

---

## Deliverable 2: ideation-gate-migration

Migrate `evals/ideation-gate.md` content into `evals/gates/ideation.yaml`.

The ideation.yaml file specified above in Deliverable 1 IS the migration target.
The 4 dimensions from ideation-gate.md (completeness, alignment, feasibility,
cross-model) are preserved as inline `post_step.dimensions`.

**Migration mapping:**

| ideation-gate.md section | ideation.yaml field |
|--------------------------|---------------------|
| `### 1. Completeness` PASS/FAIL/Evidence | `post_step.dimensions[0]` pass_criteria/fail_criteria/evidence_format |
| `### 2. Alignment` PASS/FAIL/Evidence | `post_step.dimensions[1]` pass_criteria/fail_criteria/evidence_format |
| `### 3. Feasibility` PASS/FAIL/Evidence | `post_step.dimensions[2]` pass_criteria/fail_criteria/evidence_format |
| `### 4. Cross-Model` PASS/FAIL/Evidence | `post_step.dimensions[3]` pass_criteria/fail_criteria/evidence_format |

**Implementation steps:**
1. The `evals/gates/ideation.yaml` file from Deliverable 1 already contains the migrated content.
2. Delete `evals/ideation-gate.md`.
3. Verify the YAML structure matches the gate schema (post_step with inline dimensions, no pre_step).

**File to create:** `evals/gates/ideation.yaml` (already specified in Deliverable 1).
**File to delete:** `evals/ideation-gate.md`.

---

## Deliverable 3: evaluator-prompt-template

Create `skills/shared/gate-evaluator.md` — the template used by the in-context
agent to construct the isolated subagent evaluator prompt.

### File: skills/shared/gate-evaluator.md
```markdown
# Gate Evaluator — Isolated Subagent Contract

You are a gate evaluator. You assess whether a row's output meets quality
dimensions. You operate under strict isolation — you evaluate only what is
provided, with no access to conversation history or unrelated artifacts.

## Inputs

You receive these inputs (provided inline in your prompt):

1. **definition.yaml** — the row definition (objective, deliverables, ACs)
2. **Gate YAML** — the gate dimensions to evaluate (from `evals/gates/{step}.yaml`)
3. **Step output paths** — files to read for post_step evaluation (research.md, plan.json, spec sections, etc.)
4. **Phase A results** — JSON from the artifact validation phase (artifacts_present, file_ownership, acceptance_criteria checks)

## Prohibited Context

You MUST NOT read or reference:
- `summary.md` — contains synthesized context that biases evaluation
- Conversation history or parent agent memory
- Prior step outputs not listed in your step output paths
- `.furrow/rows/*/state.json` — your verdict must not depend on current progress
- Any file not explicitly listed in your inputs

If you encounter a reference to a prohibited file, ignore it. Your evaluation
must be reproducible by any agent given only the listed inputs.

## Evaluation Protocol

1. **Read inputs**: Read definition.yaml, gate YAML, and Phase A results.
2. **Check Phase A**: If Phase A verdict is FAIL, report overall FAIL immediately — do not evaluate dimensions.
3. **Load dimensions**: Parse the gate YAML for the evaluation phase you are running (pre_step or post_step).
   - If `dimensions_from` is present, read that file for the dimension definitions.
   - If `additional_dimensions` is present, append those to the dimension list.
   - If dimensions are inline, use them directly.
4. **Evaluate each dimension independently**:
   - Gather evidence BEFORE making a judgment.
   - Read the relevant step output files to find evidence.
   - Apply pass_criteria and fail_criteria literally.
   - Record PASS or FAIL with evidence in the required format.
   - If uncertain, verdict is FAIL with explanation.
5. **Produce overall verdict**: PASS only if ALL dimensions pass.

## Response Format

Return your evaluation as structured output:

```
## Gate Evaluation: {step} ({pre_step|post_step})

### Dimension: {name}
**Verdict**: PASS | FAIL
**Evidence**: {evidence per evidence_format}

### Dimension: {name}
**Verdict**: PASS | FAIL
**Evidence**: {evidence per evidence_format}

...

### Overall Verdict: PASS | FAIL
**Summary**: {one sentence explaining the result}
```

## Rules

- **Binary only**: Each dimension is PASS or FAIL. No partial credit, no warnings-as-pass.
- **Evidence first**: Gather evidence, then judge. Do not decide then confirm.
- **Quote, don't paraphrase**: Evidence must be direct quotes, file paths, or command output.
- **One at a time**: Evaluate each dimension independently. A FAIL on one must not bias another.
- **State the gap**: For FAIL, say specifically what is missing or wrong.
- **No leniency for effort**: Difficult work still fails if it does not meet criteria.
- **Fresh reads only**: Run commands and read files now. Do not evaluate from memory.

## Generator-Evaluator Separation

This evaluator is intentionally separate from the agent that produced the work
(the generator). The generator has context, momentum, and investment in the
output — it cannot objectively assess its own work. The evaluator sees only
the artifacts and the rubric, ensuring the verdict reflects artifact quality,
not generator intent.

## Invocation Pattern

The in-context agent invokes this evaluator as follows:

1. Shell script (`run-gate.sh`) runs Phase A checks and prepares a prompt file containing:
   - definition.yaml content
   - Gate YAML content (from `evals/gates/{step}.yaml`)
   - Phase A results JSON
   - Step output file paths
2. Shell exits with a signal code indicating subagent evaluation is needed.
3. The in-context agent reads the prompt file.
4. The in-context agent spawns a subagent via the Agent tool, seeding it with:
   - This contract (gate-evaluator.md)
   - The prompt file contents
5. The subagent evaluates and returns structured output.
6. The in-context agent passes the verdict to `evaluate-gate.sh` for trust gradient processing.

The shell never invokes the LLM directly. The in-context agent is the bridge
between shell orchestration and subagent evaluation.
```

---

## Acceptance Criteria Verification

### gate-yaml-schema

| AC | Verified by |
|----|-------------|
| evals/gates/ contains YAML for all 7 steps | File list: ideation, research, plan, spec, decompose, implement, review |
| Each gate has pre_step (4 steps) and post_step (all) | research, plan, spec, decompose have pre_step; all 7 have post_step |
| post_step uses dimensions_from | research, plan, spec, decompose, implement use dimensions_from |
| pre_step contains inline dimensions | All 4 pre_step sections have inline dimensions with all 5 fields |
| Research pre_step: path-relevance | `evals/gates/research.yaml` pre_step.dimensions[0].name = "path-relevance" |
| Spec pre_step: testability | `evals/gates/spec.yaml` pre_step.dimensions[0].name = "testability" |
| Plan pre_step: complexity-assessment | `evals/gates/plan.yaml` pre_step.dimensions[0].name = "complexity-assessment" |
| Decompose pre_step: wave-triviality | `evals/gates/decompose.yaml` pre_step.dimensions[0].name = "wave-triviality" |
| Ideate, implement, review: post_step only | All 3 have no pre_step section |

### ideation-gate-migration

| AC | Verified by |
|----|-------------|
| Content migrated to ideation.yaml post_step | 4 dimensions present in post_step.dimensions |
| ideation-gate.md deleted | File removal in implementation |
| YAML follows gate schema | post_step with inline dimensions, no pre_step |
| 4 dimensions preserved | completeness, alignment, feasibility, cross-model all present |

### evaluator-prompt-template

| AC | Verified by |
|----|-------------|
| Defines isolated subagent contract | "Isolated Subagent Contract" heading, prohibited context section |
| Specifies inputs | Inputs section: definition.yaml, gate YAML, step output paths, Phase A results |
| Specifies prohibited context | Prohibited Context section: summary.md, conversation, prior steps, state.json |
| Specifies response format | Response Format section with structured template |
| Documents generator-evaluator separation | Generator-Evaluator Separation section |
| Documents invocation pattern | Invocation Pattern section: shell prepares, agent spawns |

---

## Open Questions for Implementation

1. **review.yaml dimensions_from**: `evals/dimensions/review.yaml` does not exist.
   Options: (a) create a minimal review dimensions file, (b) use inline dimensions
   like ideation.yaml, (c) keep the forward reference and document it. The spec
   above uses option (c) with a note. The implementer should decide based on
   whether review dimensions are in scope for this task.

2. **ideation-gate.md deletion timing**: The definition says ideation-gate-migration
   depends_on gate-yaml-schema. The deletion should happen in the same commit as
   the ideation.yaml creation to avoid a state where neither exists.
