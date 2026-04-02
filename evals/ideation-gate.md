# Ideation Gate — Dimension Rubric

Evaluates the `ideate->research` gate. All 4 dimensions must PASS for the gate
to pass. The evaluator reads `definition.yaml` and gate evidence.

## Dimensions

### 1. Completeness

**PASS**: All required fields present per spec 00 SS1.1 — `objective`,
`deliverables` (min 1, each with `name` and `acceptance_criteria`),
`context_pointers` (min 1), `gate_policy`. Deliverable names unique.
`depends_on` references resolve. Enum values valid.

**FAIL**: Any required field missing, invalid enum, duplicate names,
or dangling `depends_on` reference.

**Evidence**: cite which fields are present/missing.

### 2. Alignment

**PASS**: `objective` clearly maps to original user intent. Each deliverable
contributes to the objective. No deliverable is unrelated to stated goal.

**FAIL**: Objective diverges from user intent, or a deliverable has no
connection to the stated goal.

**Evidence**: cite objective text and user intent phrase.

### 3. Feasibility

**PASS**: Each deliverable has testable acceptance criteria (contains a verb
like "returns", "enforces", "validates", or a numeric threshold, or a file
path). Scope is actionable — no unbounded deliverables.

**FAIL**: Acceptance criteria are vague ("improve UX", "make faster") or
deliverable scope is unbounded.

**Evidence**: cite criteria text and assessment.

### 4. Cross-Model

**PASS**: Evidence of cross-model or fresh-context review exists. Review
findings were incorporated or explicitly rejected with rationale.

**FAIL**: No cross-model review evidence. Findings ignored without rationale.

**Evidence**: cite review source and disposition of findings.

## Overall

Gate passes only when all 4 dimensions pass. Any FAIL blocks advancement.
Record the gate with `decided_by` matching the approval mode:
`human` (supervised), `evaluator` (autonomous), or `human` (delegated).
