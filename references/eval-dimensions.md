# Eval Dimensions

Dimensions are the quality axes evaluated during Phase B review. Each artifact type
has its own dimension set. Reviewers assess pass/fail per dimension with evidence.

## Code Artifacts

| Dimension | What It Checks | Fail Signal |
|-----------|---------------|-------------|
| Correctness | Does the code do what the spec says? | Logic errors, wrong behavior |
| Error handling | Are all error paths handled? | Swallowed errors, missing checks |
| Security | No secrets leaked, auth enforced, inputs validated? | Hardcoded secrets, missing auth |
| Performance | No obvious N+1, unbounded loops, memory leaks? | Algorithmic issues |
| API contract | Does the interface match what consumers expect? | Breaking changes, wrong types |
| Test coverage | Are critical paths tested? | Missing tests for core logic |
| Maintainability | Is the code readable, well-structured? | God functions, deep nesting |
| Concurrency | Are shared resources properly synchronized? | Race conditions, deadlocks |

## Research Artifacts

| Dimension | What It Checks | Fail Signal |
|-----------|---------------|-------------|
| Coverage | Are all questions from ideation addressed? | Unanswered questions |
| Depth | Is analysis substantive, not surface-level? | One-line answers, no evidence |
| Sources | Are claims backed by references? | Unsourced assertions |
| Synthesis | Are findings synthesized, not just listed? | Raw notes without conclusions |
| Actionability | Can the plan step use these findings directly? | Vague recommendations |

## Specification Artifacts

| Dimension | What It Checks | Fail Signal |
|-----------|---------------|-------------|
| Completeness | All deliverables specified? | Missing deliverable specs |
| Implementability | Can a developer implement from this spec alone? | Ambiguous requirements |
| Consistency | Do specs agree with each other? | Contradictory interface definitions |
| Testability | Can acceptance criteria be verified mechanically? | Subjective criteria |
| Scope | Does the spec match the definition, no more/less? | Scope creep or omission |

## Plan Artifacts

| Dimension | What It Checks | Fail Signal |
|-----------|---------------|-------------|
| Feasibility | Is the plan achievable with available resources? | Impossible constraints |
| Dependency order | Are wave assignments consistent with depends_on? | Dependency violations |
| Ownership clarity | Is file ownership unambiguous per wave? | Overlapping globs |
| Decision quality | Are architecture decisions well-reasoned? | Unjustified choices |

## Gate Evidence

| Dimension | What It Checks | Fail Signal |
|-----------|---------------|-------------|
| Completeness | Does evidence cover all required dimensions? | Missing dimensions |
| Specificity | Is evidence concrete, not vague? | "Looks good" without proof |
| Traceability | Can evidence be verified against artifacts? | Unverifiable claims |

## Usage

Reviewers read this document to know which dimensions apply to the artifact type
they are evaluating. Each dimension produces a pass/fail verdict with one-line
evidence in the review result.
